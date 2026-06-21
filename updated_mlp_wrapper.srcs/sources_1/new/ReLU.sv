`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/10/2026 01:14:19 PM
// Design Name: 
// Module Name: ReLU
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


module ReLU #(
    parameter int WIDTH=32
)(
    input logic [WIDTH-1:0] in,
    output logic [WIDTH-1:0] out
);

always_comb begin
    if (in[WIDTH-1])
        out='d0;
    else
        out=in;
end

endmodule
