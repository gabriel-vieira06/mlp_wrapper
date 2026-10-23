`timescale 1ns / 1ps

module mlp_regression_tb #(
    parameter int NUM_TESTS = 10,
    parameter int N_MULT = 1
);
    logic clk = 0;
    logic rst = 1;
    logic [31:0] data_in = 0;
    logic data_valid = 0;
    logic ready_in;
    logic [31:0] data_out;
    logic data_out_valid, data_out_last;
    logic [31:0] pixels [0:NUM_TESTS*784-1];
    logic [3:0] labels [0:NUM_TESTS-1];
    int logits_file;
    int frames_done = 0;
    int output_index = 0;
    int output_total = 0;
    int correct = 0;
    int prediction = 0;
    logic signed [31:0] max_score;
    longint cycles = 0;
    localparam longint MAX_CYCLES = 64'(NUM_TESTS) * 400000 + 1000;

    dense_wrapper #(.N_MULT(N_MULT)) dut(
        .clk(clk), .rst(rst), .data_in(data_in), .data_valid(data_valid),
        .ready_in(ready_in), .data_out(data_out),
        .data_out_valid(data_out_valid), .data_out_last(data_out_last),
        .ready_out(1'b1)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        cycles++;
        if (cycles > MAX_CYCLES)
            $fatal(1, "Timeout: completed %0d/%0d frames and %0d logits",
                   frames_done, NUM_TESTS, output_total);
    end

    // Sample settled DUT outputs halfway between rising clock edges.
    always @(negedge clk) begin
        if (!rst && data_out_valid) begin
            if (frames_done >= NUM_TESTS || output_index >= 10)
                $fatal(1, "Unexpected extra output");
            if (data_out_last !== (output_index == 9))
                $fatal(1, "Incorrect last at frame %0d, output %0d",
                       frames_done, output_index);
            if ($isunknown(data_out))
                $fatal(1, "Unknown output at frame %0d, output %0d",
                       frames_done, output_index);
            $fdisplay(logits_file, "%08x", data_out);
            if (output_index == 0 || $signed(data_out) > max_score) begin
                max_score = $signed(data_out);
                prediction = output_index;
            end
            output_total++;
            if (data_out_last) begin
                if (prediction == int'(labels[frames_done])) correct++;
                frames_done++;
                output_index = 0;
            end else output_index++;
        end
    end

    initial begin
        $readmemh("test_samples.mem", pixels);
        $readmemh("test_labels.mem", labels);
        logits_file = $fopen("logits.hex", "w");
        if (!logits_file) $fatal(1, "Cannot create logits.hex");
        repeat (4) @(negedge clk);
        rst = 0;

        for (int image = 0; image < NUM_TESTS; image++) begin
            for (int pixel = 0; pixel < 784; pixel++) begin
                @(negedge clk);
                // Exercise input valid gaps without changing data during an
                // outstanding beat. Wait for the actual input handshake.
                if ((image + pixel) % 17 == 0) begin
                    data_valid = 0;
                    @(negedge clk);
                end
                data_in = pixels[image*784 + pixel];
                data_valid = 1;
                do @(posedge clk); while (!ready_in);
            end
            @(negedge clk);
            data_valid = 0;
            wait (frames_done == image + 1);
            // Repeat complete frames in the same DUT, without resetting its
            // RAM contents or state between images.
            repeat (4) @(negedge clk);
        end

        repeat (10) @(negedge clk);
        if (frames_done != NUM_TESTS || output_total != NUM_TESTS*10 || output_index != 0)
            $fatal(1, "Incomplete output: %0d frames, %0d logits",
                   frames_done, output_total);
        $fclose(logits_file);
        $display("PASS: %0d frames, %0d logits, %0d correct predictions, %0d cycles",
                 frames_done, output_total, correct, cycles);
        $finish;
    end
endmodule
