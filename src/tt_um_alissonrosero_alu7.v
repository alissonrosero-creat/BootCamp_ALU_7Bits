`default_nettype none

module tt_um_alissonrosero_alu7 (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (1=output, 0=input)
    input  wire       ena,      // goes high when design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset activo en bajo
);

    // ------------------------------------------------------------
    // Mapeo de entradas TT -> ALU
    // ui_in[0]   = Bit_in
    // ui_in[3:1] = op[2:0]
    // ui_in[7:4] = no usados
    // ------------------------------------------------------------
    wire       bit_in;
    wire [2:0] op_sel;
    wire [6:0] data_out;
    wire       done;

    assign bit_in = ui_in[0];
    assign op_sel = ui_in[3:1];

    // ------------------------------------------------------------
    // Instancia de la ALU original
    // ------------------------------------------------------------
    alu7_serial_shared_fx u_alu (
        .CLK      (clk),
        .RST_N    (rst_n),
        .Bit_in   (bit_in),
        .op       (op_sel),
        .Data_out (data_out),
        .Done     (done)
    );

    // ------------------------------------------------------------
    // Mapeo de salidas ALU -> TT
    // uo_out[6:0] = Data_out
    // uo_out[7]   = Done
    // ------------------------------------------------------------
    assign uo_out[6:0] = data_out;
    assign uo_out[7]   = done;

    // ------------------------------------------------------------
    // IO bidireccionales no usados
    // ------------------------------------------------------------
    assign uio_out = 8'bz;
    assign uio_oe  = 8'b0;

    // ------------------------------------------------------------
    // Señales no usadas para evitar warnings
    // ------------------------------------------------------------
    wire _unused = &{ena, uio_in, ui_in[7:4], 1'b0};

endmodule