import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Timer

OP_SUM     = 0b000
OP_AND     = 0b001
OP_OR      = 0b010
OP_XOR     = 0b011
OP_SUB     = 0b100
OP_SAT_ADD = 0b101
OP_SAT_SUB = 0b110
OP_CMP_S   = 0b111

SETTLE_NS = 1


def make_ui(bit_in: int, op: int) -> int:
    return ((op & 0x7) << 1) | (bit_in & 0x1)


def tc7_to_int(x: int) -> int:
    x &= 0x7F
    if x & 0x40:
        return x - 128
    return x


def int_to_tc7(x: int) -> int:
    return x & 0x7F


def ref_model(a: int, b: int, op: int) -> int:
    sa = tc7_to_int(a)
    sb = tc7_to_int(b)

    if op == OP_SUM:
        return int_to_tc7(sa + sb)
    elif op == OP_AND:
        return (a & b) & 0x7F
    elif op == OP_OR:
        return (a | b) & 0x7F
    elif op == OP_XOR:
        return (a ^ b) & 0x7F
    elif op == OP_SUB:
        return int_to_tc7(sa - sb)
    elif op == OP_SAT_ADD:
        tmp = sa + sb
        if tmp > 63:
            tmp = 63
        elif tmp < -64:
            tmp = -64
        return int_to_tc7(tmp)
    elif op == OP_SAT_SUB:
        tmp = sa - sb
        if tmp > 63:
            tmp = 63
        elif tmp < -64:
            tmp = -64
        return int_to_tc7(tmp)
    elif op == OP_CMP_S:
        return a if sa <= sb else b
    else:
        return 0


def done_bit(dut) -> int:
    return (int(dut.uo_out.value) >> 7) & 1


def result_word(dut) -> int:
    return int(dut.uo_out.value) & 0x7F


async def reset_dut(dut):
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    await Timer(SETTLE_NS, units="ns")


async def load_pair(dut, a_word: int, b_word: int, op: int):
    for i in range(7):
        await FallingEdge(dut.clk)
        dut.ui_in.value = make_ui((a_word >> i) & 1, op)
        await RisingEdge(dut.clk)
        await Timer(SETTLE_NS, units="ns")
        assert done_bit(dut) == 0, "Done alto durante carga de A"

    for i in range(7):
        await FallingEdge(dut.clk)
        dut.ui_in.value = make_ui((b_word >> i) & 1, op)
        await RisingEdge(dut.clk)
        await Timer(SETTLE_NS, units="ns")
        assert done_bit(dut) == 0, "Done alto durante carga de B"

    await FallingEdge(dut.clk)
    dut.ui_in.value = make_ui(0, op)


async def wait_done(dut, timeout_cycles=50):
    for _ in range(timeout_cycles):
        await RisingEdge(dut.clk)
        await Timer(SETTLE_NS, units="ns")
        if done_bit(dut) == 1:
            return
    raise AssertionError("Timeout esperando Done")


async def run_fresh_transaction(dut, a_word: int, b_word: int, op: int):
    expected = ref_model(a_word, b_word, op)
    await reset_dut(dut)
    await load_pair(dut, a_word, b_word, op)
    await wait_done(dut)

    got = result_word(dut)
    assert got == expected, (
        f"Resultado incorrecto op={op:03b} A=0x{a_word:02X} B=0x{b_word:02X} "
        f"esperado=0x{expected:02X} obtenido=0x{got:02X}"
    )


async def rerun_same_operands(dut, new_op: int):
    await FallingEdge(dut.clk)
    dut.ui_in.value = make_ui(0, new_op)

    for _ in range(6):
        await RisingEdge(dut.clk)
        await Timer(SETTLE_NS, units="ns")
        if done_bit(dut) == 0:
            break

    await wait_done(dut)


@cocotb.test()
async def test_serial_fixed_point_alu(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())

    dut.ena.value = 1
    dut.uio_in.value = 0
    dut.ui_in.value = 0
    dut.rst_n.value = 1

    # 1) SUM: 5 + (-3) = 2
    await run_fresh_transaction(dut, int_to_tc7(5), int_to_tc7(-3), OP_SUM)

    # 2) SAT_ADD: 50 + 30 => saturado a 63
    await run_fresh_transaction(dut, int_to_tc7(50), int_to_tc7(30), OP_SAT_ADD)

    # 3) CMP_S: devuelve el menor signed
    await run_fresh_transaction(dut, int_to_tc7(-12), int_to_tc7(5), OP_CMP_S)

    # 4) Re-ejecución con mismos operandos sin reset, cambiando solo op
    a_word = 0b0101010  # 42
    b_word = 0b0011001  # 25

    await reset_dut(dut)
    await load_pair(dut, a_word, b_word, OP_XOR)
    await wait_done(dut)

    got1 = result_word(dut)
    exp1 = ref_model(a_word, b_word, OP_XOR)
    assert got1 == exp1, f"XOR incorrecto: esperado=0x{exp1:02X}, obtenido=0x{got1:02X}"

    await rerun_same_operands(dut, OP_AND)

    got2 = result_word(dut)
    exp2 = ref_model(a_word, b_word, OP_AND)
    assert got2 == exp2, f"AND re-ejecutado incorrecto: esperado=0x{exp2:02X}, obtenido=0x{got2:02X}"
