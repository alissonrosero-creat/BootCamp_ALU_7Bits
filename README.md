# 7-bit Serial ALU with Shared Datapath and Fixed-Point Saturation

This project implements a compact **7-bit serial ALU** in Verilog, designed with a **shared 1-bit internal datapath** to reduce hardware cost and fit within Tiny Tapeout area constraints.

## Main idea

Instead of using a conventional parallel ALU, this design stores two 7-bit operands and then executes the selected operation internally **one bit per cycle**. This allows arithmetic, logic, saturation and comparison features to be supported with a compact hardware architecture.

## Main features

- 7-bit serial operand loading
- LSB-first input protocol
- shared 1-bit execution datapath
- signed fixed-point arithmetic with 3 fractional bits
- saturating addition and subtraction
- signed comparison with coded output
- operand reuse without reloading data
- compact architecture suitable for Tiny Tapeout-style area limits

## Supported operations

- `000` = `SUM`
- `001` = `AND`
- `010` = `OR`
- `011` = `XOR`
- `100` = `SUB`
- `101` = `SAT_ADD`
- `110` = `SAT_SUB`
- `111` = `CMP_S`

## Numeric format

Arithmetic operations are interpreted as **signed fixed-point 7-bit values with 3 fractional bits**.

This means:

- range: **-8.000 to 7.875**
- resolution: **0.125 per step**

Examples:

- `0001000` = `1.000`
- `0000001` = `0.125`
- `0010100` = `2.500`
- `1111000` = `-1.000`

Bitwise operations (`AND`, `OR`, `XOR`) operate directly on the raw 7-bit words.

## Comparison output

The signed comparison operation does **not** return a numeric fixed-point value.  
Instead, it returns a coded result:

- `0000001` → `A < B`
- `0000010` → `A = B`
- `0000100` → `A > B`

## IO summary

### Inputs
- `Bit_in` = serial input bit
- `op[2:0]` = operation selector
- `CLK` = clock
- `RST_N` = active-low reset

### Outputs
- `Data_out[6:0]` = parallel result
- `Done` = operation complete flag

## How to use

1. Apply reset with `RST_N = 0`
2. Release reset with `RST_N = 1`
3. Select the desired operation on `op`
4. Send operand **A** serially, **7 bits LSB-first**
5. Send operand **B** serially, **7 bits LSB-first**
6. Wait until `Done = 1`
7. Read the result from `Data_out`

## Important usage notes

- The design only accepts a valid result when `Done = 1`
- Input order must always be: **A first, then B**
- Both operands must be transmitted **LSB-first**
- To evaluate another operation with the **same operands**, change `op` after `Done = 1`
- To load a **new operand pair**, apply reset and repeat the loading sequence

## Validation status

The design has been validated with a self-checking Verilog testbench including:

- directed demo cases
- exhaustive arithmetic and logic sweeps
- saturating arithmetic checks
- protocol checks for reset and operand reload behavior

## More details

See:

- `docs/info.md`
