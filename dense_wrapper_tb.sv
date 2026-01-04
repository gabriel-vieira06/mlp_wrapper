//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/01/2026 03:57:55 PM
// Design Name: 
// Module Name: dense_wrapper_tb
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

module dense_wrapper_tb # (
    parameter int WIDTH = 32,  
                  P_INT = 10,
                  NUM_TESTS = 10
)();

    logic             clk;
    logic             rst;
    logic             start;
    logic [WIDTH-1:0] data_in [784];
    logic [WIDTH-1:0] data_out [10];
    logic             valid;

    logic [WIDTH-1:0] all_pixels_mem [0 : (NUM_TESTS*784)-1];
    
    int predicted_class;
    logic [WIDTH-1:0] max_score_bits;
    real max_score_real;

    initial $readmemh ("test_samples.mem", all_pixels_mem);

    dense_wrapper # ()
    UUT(
        .clk(clk),
        .rst(rst),
        .start(start),
        .data_in(data_in),
        .data_out(data_out),
        .valid(valid)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        rst = 1;
        start = 0;

        $display("");
        
        #10;
        rst = 0;

        for (int i = 0; i < NUM_TESTS; i++) begin
        
            for (int p = 0; p < 784; p++) begin
                // O arquivo .mem já contém o valor inteiro escalado corretamente pelo Python
                data_in[p] = all_pixels_mem[i*784 + p];
            end
        
            #10;
            start = 1;
          
            #10;
            start = 0;
            wait(valid);
            
            /*
            $display("Imagem %0d", i+1);
            $display("Class out[0]: %.2f", $signed(data_out[0])/(2.0**(WIDTH-P_INT)));
            $display("Class out[1]: %.2f", $signed(data_out[1])/(2.0**(WIDTH-P_INT)));
            $display("Class out[2]: %.2f", $signed(data_out[2])/(2.0**(WIDTH-P_INT)));
            $display("Class out[3]: %.2f", $signed(data_out[3])/(2.0**(WIDTH-P_INT)));
            $display("Class out[4]: %.2f", $signed(data_out[4])/(2.0**(WIDTH-P_INT)));
            $display("Class out[5]: %.2f", $signed(data_out[5])/(2.0**(WIDTH-P_INT)));
            $display("Class out[6]: %.2f", $signed(data_out[6])/(2.0**(WIDTH-P_INT)));
            $display("Class out[7]: %.2f", $signed(data_out[7])/(2.0**(WIDTH-P_INT)));
            $display("Class out[8]: %.2f", $signed(data_out[8])/(2.0**(WIDTH-P_INT)));
            $display("Class out[9]: %.2f", $signed(data_out[9])/(2.0**(WIDTH-P_INT)));
            */
            
            predicted_class = 0;
            max_score_bits = data_out[0];

            for (int k = 1; k < 10; k++) begin
                if ($signed(data_out[k]) > $signed(max_score_bits)) begin
                    max_score_bits = data_out[k];
                    predicted_class = k;
                end
            end

            max_score_real = $signed(max_score_bits) / (2.0**(WIDTH-P_INT));

            $display("Imagem %0d: Classe Predita = %0d (Score: %.2f)", i+1, predicted_class, max_score_real);
            
            #100;
        end


        $display("");

        #10;
        $finish;
    end
endmodule
