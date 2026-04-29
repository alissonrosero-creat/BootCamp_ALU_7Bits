# 7-bit Serial ALU Documentation

## 1. Overview

This project implements a **7-bit serial ALU** with a compact internal architecture based on a **shared 1-bit datapath**. The design is intended for area-constrained digital implementation flows such as Tiny Tapeout.

The ALU receives its two operands serially, stores them internally, and then executes the selected operation over multiple clock cycles. The final result is presented in parallel together with a completion flag.

---

## 2. Execution model

The ALU works in four conceptual phases:

### 2.1 Reset
The design uses an **active-low reset**.

- `RST_N = 0` resets the internal state
- `RST_N = 1` enables normal operation

### 2.2 Operand loading
Two 7-bit operands are loaded serially through `Bit_in`.

- first operand: **A**
- second operand: **B**
- both are loaded **LSB-first**

That means bit 0 must be transmitted first, and bit 6 last.

### 2.3 Operation execution
Once both operands are stored, the ALU internally executes the selected operation using a **1-bit-per-cycle shared datapath**.

This reduces logic duplication compared to a conventional parallel ALU.

### 2.4 Result stage
When execution is complete:

- `Done = 1`
- `Data_out[6:0]` contains the final result

The output must only be considered valid when `Done` is asserted.

---

## 3. Supported operations

| Opcode | Operation | Description |
|-------:|-----------|-------------|
| `000` | `SUM` | Signed fixed-point addition |
| `001` | `AND` | Bitwise AND |
| `010` | `OR` | Bitwise OR |
| `011` | `XOR` | Bitwise XOR |
| `100` | `SUB` | Signed fixed-point subtraction |
| `101` | `SAT_ADD` | Saturating signed fixed-point addition |
| `110` | `SAT_SUB` | Saturating signed fixed-point subtraction |
| `111` | `CMP_S` | Signed comparison with coded output |

---

## 4. Numeric representation

Arithmetic operations use **signed fixed-point representation with 3 fractional bits**.

### 4.1 Format
- total width: **7 bits**
- signed representation: **two’s complement**
- fractional bits: **3**

### 4.2 Range
The representable range is:

- minimum: **-8.000**
- maximum: **7.875**

### 4.3 Resolution
The step between adjacent values is:

- **0.125**

### 4.4 Examples

| Binary | Value |
|--------|-------|
| `0000000` | `0.000` |
| `0000001` | `0.125` |
| `0001000` | `1.000` |
| `0010100` | `2.500` |
| `0111111` | `7.875` |
| `1000000` | `-8.000` |
| `1111000` | `-1.000` |
| `1111111` | `-0.125` |

### 4.5 Note on logic operations
`AND`, `OR`, and `XOR` do not interpret the data as numeric fixed-point values. They operate directly on the 7-bit words.

---

## 5. Saturating arithmetic

The ALU includes saturating versions of addition and subtraction.

### 5.1 Why saturation is used
Normal signed arithmetic wraps around when overflow occurs.  
Saturating arithmetic avoids this by clamping the result to the valid numeric range.

### 5.2 Saturation limits
- positive limit: `0111111` → `7.875`
- negative limit: `1000000` → `-8.000`

### 5.3 Example
- `7.875 + 0.125` with normal `SUM` wraps around
- `7.875 + 0.125` with `SAT_ADD` stays at `7.875`

---

## 6. Comparison operation

The `CMP_S` operation performs a **signed comparison** between the stored operands.

It does not return a numeric fixed-point result.  
Instead, it returns one of the following codes:

- `0000001` → `A < B`
- `0000010` → `A = B`
- `0000100` → `A > B`

These outputs must be interpreted as **comparison flags**, not as Q3 numeric values.

---

## 7. How to test the ALU correctly

To test the ALU properly, the protocol must be respected exactly.

### 7.1 Loading a new operand pair
1. Apply reset: `RST_N = 0`
2. Release reset: `RST_N = 1`
3. Select the desired operation on `op`
4. Send the 7 bits of operand **A**, LSB-first
5. Send the 7 bits of operand **B**, LSB-first
6. Wait for `Done = 1`
7. Read `Data_out`

### 7.2 Reusing the same operands
After `Done = 1`, the operands remain stored internally.

That means a different operation can be tested on the **same A and B values** by changing `op`, without reloading the serial inputs.

### 7.3 Loading different operands
If a new operand pair is required, reset must be applied again before sending the next serial sequence.

---

## 8. Practical testing considerations

To obtain correct results:

- always send **exactly 7 bits** for A and 7 bits for B
- always send data **LSB-first**
- never interpret `Data_out` as valid before `Done = 1`
- remember that `CMP_S` returns coded flags, not numeric output
- remember that `RST_N` is **active low**
- use a clock frequency consistent with the project configuration

---

## 9. Verification

The design is accompanied by a self-checking Verilog testbench that includes:

- directed demonstration cases
- exhaustive operation sweeps
- overflow and saturation checks
- comparison checks
- reset and protocol behavior checks
- operand reuse tests after `Done`

---

## 10. RTL files

Main RTL sources:

- `aluPuntoFijo.v`
- `project.v` (Tiny Tapeout wrapper)

The wrapper maps Tiny Tapeout pins to the ALU core while keeping the original internal logic unchanged.
