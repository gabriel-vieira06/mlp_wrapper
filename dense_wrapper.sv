//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/01/2026 02:24:42 PM
// Design Name: 
// Module Name: dense_wrapper
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

module dense_wrapper #(
    parameter int WIDTH = 32,  
                  P_INT = 10
)(
    clk,
    rst,
    start,
    data_in,
    data_out,
    valid
);

    localparam int h1_t2s = ((16/784) == 0) ? 1 : 16/784;
    localparam int h2_t2s = ((16/64)  == 0) ? 1 : 16/64;
    localparam int h3_t2s = ((16/32)  == 0) ? 1 : 16/32;

    input logic                                 clk;
    input logic                                 rst;
    input logic                                 start;
    input logic  [                   WIDTH-1:0] data_in [784];
    output logic [                   WIDTH-1:0] data_out [10];
    output logic                                valid;
    
    typedef enum logic [2:0] {linear, sigmoid, relu, tanh, leaky, step} acfunc;
    
    logic [WIDTH-1:0] H1_out [64];
    logic             H1_finish;
    
    logic [WIDTH-1:0] H2_out [32];
    logic             H2_finish;
    
    logic [         WIDTH-1:0] H1_W [16];
    logic [         WIDTH-1:0] H1_B [h1_t2s];
    logic [$clog2(784*64)-1:0] H1_addr_w;
    logic [    $clog2(64)-1:0] H1_addr_b;
    
    logic [         WIDTH-1:0] H2_W [16];
    logic [         WIDTH-1:0] H2_B [h2_t2s];
    logic [ $clog2(64*32)-1:0] H2_addr_w;
    logic [    $clog2(32)-1:0] H2_addr_b; 
    
    logic [         WIDTH-1:0] H3_W [16];
    logic [         WIDTH-1:0] H3_B [h3_t2s];
    logic [ $clog2(32*10)-1:0] H3_addr_w;
    logic [    $clog2(10)-1:0] H3_addr_b; 
    
    dense #(
        .n_in(784), 
        .n_mult(16), 
        .layer_size(64), 
        .WIDTH(32), 
        .p_int(10),
        .activation_function(relu)
    )
    hidden1
    (
        .clk(clk),
        .rst(rst),
        .start(start),
        .X(data_in),
        .W(H1_W),
        .bias(H1_B),
        .Y(H1_out),
        .addr_w(H1_addr_w),
        .addr_b(H1_addr_b),
        .finish(H1_finish)
    );
    
    dense #(
        .n_in(64), 
        .n_mult(16), 
        .layer_size(32), 
        .WIDTH(32), 
        .p_int(10),
        .activation_function(relu)
    )
    hidden2
    (
        .clk(clk),
        .rst(rst),
        .start(H1_finish),
        .X(H1_out),
        .W(H2_W),
        .bias(H2_B),
        .Y(H2_out),
        .addr_w(H2_addr_w),
        .addr_b(H2_addr_b),
        .finish(H2_finish)
    );
    
    dense #(
        .n_in(32), 
        .n_mult(16), 
        .layer_size(10), 
        .WIDTH(32), 
        .p_int(10),
        .activation_function(linear)
    )
    hidden3
    (
        .clk(clk),
        .rst(rst),
        .start(H2_finish),
        .X(H2_out),
        .W(H3_W),
        .bias(H3_B),
        .Y(data_out),
        .addr_w(H3_addr_w),
        .addr_b(H3_addr_b),
        .finish(valid)
    );
    
    mem_behavioral_W #(
        .ADDR_WIDTH($clog2(784*64)),
        .DEPTH(784*64),
        .FILENAME("H1W.mem")
    ) H1_W_mem (
        //.clk(clk),
        .addr(H1_addr_w),
        .dout(H1_W)
    );
    
    mem_behavioral_W #(
        .ADDR_WIDTH($clog2(64*32)),
        .DEPTH(64*32),
        .FILENAME("H2W.mem")
    ) H2_W_mem (
        //.clk(clk),
        .addr(H2_addr_w),
        .dout(H2_W)
    );
    
    mem_behavioral_W #(
        .ADDR_WIDTH($clog2(32*10)),
        .DEPTH(32*10),
        .FILENAME("H3W.mem")
    ) H3_W_mem (
        //.clk(clk),
        .addr(H3_addr_w),
        .dout(H3_W)
    );

    mem_behavioral_B #(
        .ADDR_WIDTH($clog2(64)),
        .t2s(h1_t2s),
        .DEPTH(64),
        .FILENAME("H1B.mem")
    ) H1_B_mem (
        //.clk(clk),
        .addr(H1_addr_b),
        .dout(H1_B)
    );
    
    mem_behavioral_B #(
        .ADDR_WIDTH($clog2(32)),
        .t2s(h2_t2s),
        .DEPTH(32),
        .FILENAME("H2B.mem")
    ) H2_B_mem (
        //.clk(clk),
        .addr(H2_addr_b),
        .dout(H2_B)
    );
    
    mem_behavioral_B #(
        .ADDR_WIDTH($clog2(10)),
        .t2s(h3_t2s),
        .DEPTH(10),
        .FILENAME("H3B.mem")
    ) H3_B_mem (
        //.clk(clk),
        .addr(H3_addr_b),
        .dout(H3_B)
    );

endmodule
