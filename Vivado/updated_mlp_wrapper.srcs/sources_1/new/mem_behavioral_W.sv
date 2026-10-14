module mem_behavioral_W #(
    parameter int   ADDR_WIDTH = 4,
                    DATA_WIDTH = 32,
                    DEPTH      = 16,
                    p_int      = 10,
                    n_mult     = 16,
    parameter string    FILENAME    = "mem_file.txt"
)(
    //clk,
    addr,
    dout
);
    
    //input logic                   clk;
    input logic  [ADDR_WIDTH-1:0] addr;
    output logic [DATA_WIDTH-1:0] dout [n_mult];
    
    logic [DATA_WIDTH-1:0] mem [DEPTH];
    
    initial $readmemh (FILENAME, mem);
    
    always_comb begin   
    //always_ff @(posedge clk) begin
        for (int i = 0; i < n_mult; i++) //n_mult
            dout[i] = mem[addr+i];
    end 

endmodule