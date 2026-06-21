`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/09/2026 03:25:27 PM
// Design Name: 
// Module Name: mlp
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module mlp #(
    parameter WIDTH = 32
)(
    input  wire clk,
    input  wire rst_n, // AXI costuma usar reset invertido (ativo em zero)

    // Interface AXI-Stream Slave (S_AXIS) - Recebe pixels do DMA
    input  wire [WIDTH-1:0] s_axis_tdata,
    input  wire             s_axis_tvalid,
    output wire             s_axis_tready,
    input  wire             s_axis_tlast,   // UNCONNECTED

    // Interface AXI-Stream Master (M_AXIS) - Envia classes para o DMA
    output wire [WIDTH-1:0] m_axis_tdata,
    output wire             m_axis_tvalid,
    input  wire             m_axis_tready,
    output wire             m_axis_tlast
);
    
    wire rst;
    assign rst = ~rst_n; // Converte para reset ativo em alto

    dense_wrapper #(
        .WIDTH(WIDTH)
    ) UUT (
        .clk(clk),
        .rst(rst),
        .data_in(s_axis_tdata),
        .data_valid(s_axis_tvalid),
        .ready_in(s_axis_tready),
        .data_out(m_axis_tdata),
        .data_out_valid(m_axis_tvalid),
        .data_out_last(m_axis_tlast),
        .ready_out(m_axis_tready)
    );
    
endmodule
