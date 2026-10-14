`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/10/2026 01:13:38 PM
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
                  NUM_TESTS = 1000
)();

    logic             clk;
    logic             rst;
    
    logic [WIDTH-1:0] data_in;
    logic             data_valid;
    logic             ready_in;
    
    logic [WIDTH-1:0] data_out;
    logic             data_out_valid;
    logic             data_out_last;
    logic             ready_out;
    integer fd;

    logic [WIDTH-1:0] all_pixels_mem [0 : (NUM_TESTS*784)-1];
    logic [3:0]       all_labels_mem [0 : (NUM_TESTS)-1];
    
    logic [WIDTH-1:0] output_buffer [10];
    int out_idx;
    int predicted_class;
    logic [WIDTH-1:0] max_score_bits;
    real max_score_real;
    int               correct_count = 0; // Contador de acertos
    real              accuracy;          // Variável para cálculo final

    initial $readmemh ("test_samples.mem", all_pixels_mem);
    initial $readmemh ("test_labels.mem", all_labels_mem);


    dense_wrapper UUT(
        .clk(clk),
        .rst(rst),
        .data_in(data_in),
        .data_valid(data_valid),
        .ready_in(ready_in),
        .data_out(data_out),
        .data_out_valid(data_out_valid),
        .data_out_last(data_out_last),
        .ready_out(ready_out)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        fd = $fopen("mnist_log.txt", "w");
    end
    
    initial begin
        rst = 1;
        out_idx = 0;
        data_valid = 0;
        ready_out = 0;

        $fwrite("");
        
        #10;
        rst = 0;
        ready_out = 1;

        for (int i = 0; i < NUM_TESTS; i++) begin
            // STREAMING DA IMAGEM
            for (int p = 0; p < 784; p++) begin
                data_in    = all_pixels_mem[i*784 + p];
                data_valid = 1;
                #10;
            end
            
            data_valid = 0;        
            out_idx = 0;
            
            while (1) begin
                if (data_out_valid) begin
                    output_buffer[out_idx] = data_out;
                    out_idx++;
            
                    if (data_out_last)
                        break;
                end
                #10;
            end
        
            predicted_class = 0;
            max_score_bits = output_buffer[0];
            
            for (int k = 1; k < 10; k++) begin
                if ($signed(output_buffer[k]) > $signed(max_score_bits)) begin
                    max_score_bits = output_buffer[k];
                    predicted_class = k;
                end
            end
    
            max_score_real = $signed(max_score_bits) / (2.0**(WIDTH-P_INT));
    
            if (predicted_class == all_labels_mem[i]) begin
                correct_count++;
                $fwrite(fd,"Imagem %0d: Pred=%0d | Real=%0d [OK] (Score: %.2f)\n", 
                         i+1, predicted_class, all_labels_mem[i], max_score_real);
            end else begin
                $fwrite(fd,"Imagem %0d: Pred=%0d | Real=%0d [ERRO] (Score: %.2f)\n", 
                         i+1, predicted_class, all_labels_mem[i], max_score_real);
            end
            
            //$display("Imagem %0d: Classe Predita = %0d (Score: %.2f)", i+1, predicted_class, max_score_real);
            //$display("Classe real = %0d", all_labels_mem[i]);
            
            #100;
        end

        $display("");
        
        accuracy = (correct_count * 100.0) / NUM_TESTS;
        
        $display("--------------------------------------------------");
        $display("RESULTADO FINAL DA SIMULACAO");
        $display("--------------------------------------------------");
        $display("Total de Testes: %0d", NUM_TESTS);
        $display("Acertos        : %0d", correct_count);
        $display("Erros          : %0d", NUM_TESTS - correct_count);
        $display("Acuracia       : %.2f%%", accuracy);
        $display("--------------------------------------------------");
        $display("");

        #10;
        $finish;
    end
endmodule
