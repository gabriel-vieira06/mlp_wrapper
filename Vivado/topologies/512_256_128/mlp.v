`timescale 1ns / 1ps

// 784 -> 512 -> 256 -> 128 -> 10 preset. Compile only this variant's mlp.v.
module mlp #(
    parameter WIDTH = 32,
    parameter N_MULT = 1
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [WIDTH-1:0] s_axis_tdata,
    input  wire s_axis_tvalid,
    output wire s_axis_tready,
    input  wire s_axis_tlast,
    output wire [WIDTH-1:0] m_axis_tdata,
    output wire m_axis_tvalid,
    input  wire m_axis_tready,
    output wire m_axis_tlast,
    output wire dbg_valid_in,
    output wire dbg_valid_out
);
    assign dbg_valid_in = s_axis_tvalid;
    assign dbg_valid_out = m_axis_tvalid;

    mlp_topology #(
        .WIDTH(WIDTH),
        .P_INT(10),
        .N_MULT(N_MULT),
        .INPUT_SIZE(784),
        .OUTPUT_SIZE(10),
        .HIDDEN_LAYERS(3),
        .H1_SIZE(512),
        .H2_SIZE(256),
        .H3_SIZE(128)
    ) UUT (
        .clk(clk),
        .rst(~rst_n),
        .data_in(s_axis_tdata),
        .data_out(m_axis_tdata),
        .ready_in(s_axis_tready),
        .data_valid(s_axis_tvalid),
        .data_out_valid(m_axis_tvalid),
        .data_out_last(m_axis_tlast),
        .ready_out(m_axis_tready)
    );
endmodule
