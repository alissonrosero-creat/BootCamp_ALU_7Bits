`timescale 1ns/1ps

module alu7_serial_shared_fx (
    input  wire       CLK,
    input  wire       RST_N,      // reset activo en bajo
    input  wire       Bit_in,     // entrada serial LSB-first
    input  wire [2:0] op,         // opcode externo
    output wire [6:0] Data_out,   // salida paralela
    output wire       Done        // fin de operación
);

    // ------------------------------------------------------------
    // OPCODES
    // ------------------------------------------------------------
    localparam [2:0] OP_SUM     = 3'b000;
    localparam [2:0] OP_AND     = 3'b001;
    localparam [2:0] OP_OR      = 3'b010;
    localparam [2:0] OP_XOR     = 3'b011;
    localparam [2:0] OP_SUB     = 3'b100;
    localparam [2:0] OP_SAT_ADD = 3'b101;
    localparam [2:0] OP_SAT_SUB = 3'b110;
    localparam [2:0] OP_CMP_S   = 3'b111;

    // ------------------------------------------------------------
    // ESTADOS
    // ------------------------------------------------------------
    localparam [2:0] ST_LOAD_A = 3'd0;
    localparam [2:0] ST_LOAD_B = 3'd1;
    localparam [2:0] ST_PREP   = 3'd2;
    localparam [2:0] ST_EXEC   = 3'd3;
    localparam [2:0] ST_FINAL  = 3'd4;
    localparam [2:0] ST_DONE   = 3'd5;

    // ------------------------------------------------------------
    // REGISTROS
    // ------------------------------------------------------------
    reg [2:0] state, next_state;

    reg [6:0] A_reg;
    reg [6:0] B_reg;

    reg [6:0] A_sh;
    reg [6:0] B_sh;
    reg [6:0] R_sh;

    reg [2:0] bit_cnt;
    reg [2:0] op_exec;
    reg [2:0] op_last;
    reg       carry;

    // ------------------------------------------------------------
    // DATAPATH COMBINACIONAL DE 1 BIT
    // ------------------------------------------------------------
    wire a_bit = A_sh[0];
    wire b_bit = B_sh[0];

    wire arith_like = (op_exec == OP_SUM)     ||
                      (op_exec == OP_SUB)     ||
                      (op_exec == OP_SAT_ADD) ||
                      (op_exec == OP_SAT_SUB) ||
                      (op_exec == OP_CMP_S);

    wire sub_like = (op_exec == OP_SUB)     ||
                    (op_exec == OP_SAT_SUB) ||
                    (op_exec == OP_CMP_S);

    wire b_eff = sub_like ? ~b_bit : b_bit;

    wire sum_bit = a_bit ^ b_eff ^ carry;
    wire carry_calc = (a_bit & b_eff) | (a_bit & carry) | (b_eff & carry);

    reg  res_bit;
    reg  carry_next;

    // overflow signed evaluado al final, sobre el resultado ya armado en R_sh
    wire ovf_add = (~(A_reg[6] ^ B_reg[6])) & (R_sh[6] ^ A_reg[6]);
    wire ovf_sub =  (A_reg[6] ^ B_reg[6])  & (R_sh[6] ^ A_reg[6]);

    wire cmp_eq = (R_sh == 7'b0000000);
    wire cmp_lt = R_sh[6] ^ ovf_sub;
    wire cmp_gt = (~cmp_lt) & (~cmp_eq);

    assign Data_out = R_sh;
    assign Done     = (state == ST_DONE);

    // ------------------------------------------------------------
    // PRÓXIMO ESTADO
    // ------------------------------------------------------------
    always @(*) begin
        next_state = state;

        case (state)
            ST_LOAD_A: begin
                if (bit_cnt == 3'd6)
                    next_state = ST_LOAD_B;
            end

            ST_LOAD_B: begin
                if (bit_cnt == 3'd6)
                    next_state = ST_PREP;
            end

            ST_PREP: begin
                next_state = ST_EXEC;
            end

            ST_EXEC: begin
                if (bit_cnt == 3'd6)
                    next_state = ST_FINAL;
            end

            ST_FINAL: begin
                next_state = ST_DONE;
            end

            ST_DONE: begin
                if (op != op_last)
                    next_state = ST_PREP;
                else
                    next_state = ST_DONE;
            end

            default: begin
                next_state = ST_LOAD_A;
            end
        endcase
    end

    // ------------------------------------------------------------
    // SLICE COMBINACIONAL
    // ------------------------------------------------------------
    always @(*) begin
        res_bit    = 1'b0;
        carry_next = 1'b0;

        case (op_exec)
            OP_SUM,
            OP_SUB,
            OP_SAT_ADD,
            OP_SAT_SUB,
            OP_CMP_S: begin
                res_bit    = sum_bit;
                carry_next = carry_calc;
            end

            OP_AND: begin
                res_bit    = a_bit & b_bit;
                carry_next = 1'b0;
            end

            OP_OR: begin
                res_bit    = a_bit | b_bit;
                carry_next = 1'b0;
            end

            OP_XOR: begin
                res_bit    = a_bit ^ b_bit;
                carry_next = 1'b0;
            end

            default: begin
                res_bit    = 1'b0;
                carry_next = 1'b0;
            end
        endcase
    end

    // ------------------------------------------------------------
    // LÓGICA SECUENCIAL
    // ------------------------------------------------------------
    always @(posedge CLK or negedge RST_N) begin
        if (!RST_N) begin
            state   <= ST_LOAD_A;
            A_reg   <= 7'b0;
            B_reg   <= 7'b0;
            A_sh    <= 7'b0;
            B_sh    <= 7'b0;
            R_sh    <= 7'b0;
            bit_cnt <= 3'b0;
            op_exec <= 3'b0;
            op_last <= 3'b0;
            carry   <= 1'b0;
        end
        else begin
            state <= next_state;

            case (state)
                // --------------------------------------------
                // CARGA DE A (LSB-first)
                // --------------------------------------------
                ST_LOAD_A: begin
                    A_reg <= {Bit_in, A_reg[6:1]};

                    if (bit_cnt == 3'd6)
                        bit_cnt <= 3'd0;
                    else
                        bit_cnt <= bit_cnt + 3'd1;
                end

                // --------------------------------------------
                // CARGA DE B (LSB-first)
                // --------------------------------------------
                ST_LOAD_B: begin
                    B_reg <= {Bit_in, B_reg[6:1]};

                    if (bit_cnt == 3'd6)
                        bit_cnt <= 3'd0;
                    else
                        bit_cnt <= bit_cnt + 3'd1;
                end

                // --------------------------------------------
                // PREPARACIÓN DE UNA EJECUCIÓN
                // --------------------------------------------
                ST_PREP: begin
                    A_sh    <= A_reg;
                    B_sh    <= B_reg;
                    R_sh    <= 7'b0;
                    bit_cnt <= 3'd0;
                    op_exec <= op;
                    op_last <= op;

                    case (op)
                        OP_SUB,
                        OP_SAT_SUB,
                        OP_CMP_S: carry <= 1'b1;
                        default:  carry <= 1'b0;
                    endcase
                end

                // --------------------------------------------
                // EJECUCIÓN SERIAL DE 1 BIT/CICLO
                // --------------------------------------------
                ST_EXEC: begin
                    // construir resultado: al final R_sh[0]=LSB ... R_sh[6]=MSB
                    R_sh  <= {res_bit, R_sh[6:1]};

                    // desplazar copias de trabajo; operandos originales quedan intactos
                    A_sh  <= {1'b0, A_sh[6:1]};
                    B_sh  <= {1'b0, B_sh[6:1]};

                    // carry solo importa en operaciones aritméticas
                    if (arith_like)
                        carry <= carry_next;
                    else
                        carry <= 1'b0;

                    if (bit_cnt == 3'd6)
                        bit_cnt <= 3'd0;
                    else
                        bit_cnt <= bit_cnt + 3'd1;
                end

                // --------------------------------------------
                // POSTPROCESO: saturación y comparación signed
                // --------------------------------------------
                ST_FINAL: begin
                    case (op_exec)
                        OP_SAT_ADD: begin
                            if (ovf_add) begin
                                if (A_reg[6] == 1'b0)
                                    R_sh <= 7'b0111111; // +7.875 en Q3 frac
                                else
                                    R_sh <= 7'b1000000; // -8.000
                            end
                        end

                        OP_SAT_SUB: begin
                            if (ovf_sub) begin
                                if (A_reg[6] == 1'b0)
                                    R_sh <= 7'b0111111; // +7.875
                                else
                                    R_sh <= 7'b1000000; // -8.000
                            end
                        end

                        OP_CMP_S: begin
                            // Devuelve el menor signed:
                            // si A < B -> A
                            // si A = B -> A
                            // si A > B -> B
                            if (cmp_lt || cmp_eq)
                                R_sh <= A_reg;
                            else
                                R_sh <= B_reg;
                        end

                        default: begin
                            R_sh <= R_sh;
                        end
                    endcase
                end

                // --------------------------------------------
                // DONE: mantener resultado. Si cambia op, re-ejecuta.
                // --------------------------------------------
                ST_DONE: begin
                    A_reg   <= A_reg;
                    B_reg   <= B_reg;
                    A_sh    <= A_sh;
                    B_sh    <= B_sh;
                    R_sh    <= R_sh;
                    bit_cnt <= bit_cnt;
                    op_exec <= op_exec;
                    op_last <= op_last;
                    carry   <= carry;
                end

                default: begin
                    state   <= ST_LOAD_A;
                    A_reg   <= 7'b0;
                    B_reg   <= 7'b0;
                    A_sh    <= 7'b0;
                    B_sh    <= 7'b0;
                    R_sh    <= 7'b0;
                    bit_cnt <= 3'b0;
                    op_exec <= 3'b0;
                    op_last <= 3'b0;
                    carry   <= 1'b0;
                end
            endcase
        end
    end

endmodule