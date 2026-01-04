//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/01/2026 02:54:17 PM
// Design Name: 
// Module Name: mem_behavioral_B
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

module mem_behavioral_B #(
    parameter int   ADDR_WIDTH = 4,
                    DATA_WIDTH = 32,
                    DEPTH      = 16,
                    p_int      = 10,
                    t2s        = 1,
    parameter string    FILENAME    = "mem_file.txt"
)(
    //clk,
    addr,
    dout
);
    
    //input logic                   clk;
    input logic  [ADDR_WIDTH-1:0] addr;
    output logic [DATA_WIDTH-1:0] dout [t2s];
    
    logic [DATA_WIDTH-1:0] mem [DEPTH];
    
    initial $readmemh (FILENAME, mem);
    
    always_comb begin
    //always_ff @(posedge clk) begin
        for (int i = 0; i < t2s; i++)
            dout[i] = mem[addr];
    end
    
endmodule
