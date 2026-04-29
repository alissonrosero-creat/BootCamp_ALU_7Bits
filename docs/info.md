# Serial Fixed-Point ALU with Shared Datapath

## Overview

This project implements a compact 7-bit serial fixed-point ALU for Tiny Tapeout.

The design receives operands serially, least-significant bit first, using a single input bit stream.  
Operand `A` is loaded first, operand `B` is loaded second, and then the selected operation is executed with a shared bit-serial datapath.

The output is provided in parallel.

## Main features

- 7-bit datapath
- serial operand loading
- shared datapath architecture
- fixed-point operation style
- arithmetic, logic, saturation, and signed compare behavior

## Supported operations

- `000` = SUM
- `001` = AND
- `010` = OR
- `011` = XOR
- `100` = SUB
- `101` = SAT_ADD
- `110` = SAT_SUB
- `111` = CMP_S

## Important behavior

### Operand load protocol
- first 7 serial bits load operand `A`
- next 7 serial bits load operand `B`
- loading is LSB-first

### Execution completion
The `Done` output goes high when the operation has completed.

### Re-execution rule
After completion, the design remains in `DONE`.
It only starts a new execution with the same stored operands if the opcode changes.

To load a completely new operand pair, reset is used.

### Signed compare behavior
`CMP_S` returns the smaller signed operand, not a one-bit comparison flag.

## Tiny Tapeout mapping

### Inputs
- `ui[0]` = serial input bit
- `ui[3:1]` = operation select

### Outputs
- `uo[6:0]` = ALU result
- `uo[7]` = Done

### Bidirectional IO
Unused.
