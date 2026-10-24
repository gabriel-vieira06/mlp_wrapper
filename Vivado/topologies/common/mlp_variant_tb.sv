`timescale 1ns / 1ps

// Simulate the selected variant's mlp.v using the shared MNIST test inputs.
// Trained weight/bias memories must be supplied separately for that topology.
module mlp_variant_tb #(
    parameter integer NUM_TESTS = 10
);
    logic clk = 0;
    logic rst_n = 0;
    logic [31:0] data_in = 0;
    logic data_valid = 0;
    wire ready_in;
    wire [31:0] data_out;
    wire data_out_valid, data_out_last;
    logic input_last = 0;
    logic [31:0] pixels [0:NUM_TESTS*784-1];
    logic [3:0] labels [0:NUM_TESTS-1];
    integer input_file, label_file, log_file, scanned;
    integer frames_done = 0;
    integer output_index = 0;
    integer correct = 0;
    integer prediction = 0;
    logic signed [31:0] max_score;
    longint cycles = 0;
    localparam MAX_CYCLES = 64'd4000000 * NUM_TESTS + 64'd10000;

    mlp dut (
        .clk(clk), .rst_n(rst_n),
        .s_axis_tdata(data_in), .s_axis_tvalid(data_valid),
        .s_axis_tready(ready_in), .s_axis_tlast(input_last),
        .m_axis_tdata(data_out), .m_axis_tvalid(data_out_valid),
        .m_axis_tready(1'b1), .m_axis_tlast(data_out_last),
        .dbg_valid_in(), .dbg_valid_out()
    );

    always #10 clk = ~clk; // 50 MHz, matching the block design.

    always @(posedge clk) begin
        cycles++;
        if (cycles > MAX_CYCLES)
            $fatal(1, "Timeout: %0d/%0d complete frames", frames_done, NUM_TESTS);
        if (rst_n && data_out_valid) begin
            if (frames_done >= NUM_TESTS || data_out_last !== (output_index == 9))
                $fatal(1, "Unexpected output/last at frame %0d, score %0d",
                       frames_done, output_index);
            if ($isunknown(data_out)) $fatal(1, "Unknown model output");
            if (output_index == 0 || $signed(data_out) > max_score) begin
                max_score = $signed(data_out);
                prediction = output_index;
            end
            if (data_out_last) begin
                if (prediction == labels[frames_done]) correct++;
                $fdisplay(log_file, "Image %0d: predicted=%0d expected=%0d",
                          frames_done, prediction, labels[frames_done]);
                frames_done++;
                output_index = 0;
            end else output_index++;
        end
    end

    initial begin
        input_file = $fopen("test_samples.mem", "r");
        label_file = $fopen("test_labels.mem", "r");
        log_file = $fopen("mnist_log.txt", "w");
        if (!input_file || !label_file || !log_file)
            $fatal(1, "Cannot open MNIST input/label files or output log");
        // Consume exactly the requested prefix of the shared data files.
        // No shortened copies of the 10,000-image fixture are required.
        for (integer i = 0; i < NUM_TESTS*784; i++) begin
            scanned = $fscanf(input_file, "%h", pixels[i]);
            if (scanned != 1) $fatal(1, "Insufficient MNIST pixels at word %0d", i);
        end
        for (integer i = 0; i < NUM_TESTS; i++) begin
            scanned = $fscanf(label_file, "%h", labels[i]);
            if (scanned != 1 || $isunknown(labels[i]) || labels[i] > 9)
                $fatal(1, "Invalid or missing MNIST label at index %0d", i);
        end
        $fclose(input_file);
        $fclose(label_file);

        repeat (4) @(negedge clk);
        rst_n = 1;
        for (integer image = 0; image < NUM_TESTS; image++) begin
            for (integer pixel = 0; pixel < 784; pixel++) begin
                @(negedge clk);
                data_in = pixels[image*784 + pixel];
                data_valid = 1;
                input_last = (pixel == 783);
                do @(posedge clk); while (!ready_in);
            end
            @(negedge clk);
            data_valid = 0;
            input_last = 0;
            wait (frames_done == image + 1);
            repeat (4) @(negedge clk);
        end
        repeat (10) @(negedge clk);
        $fclose(log_file);
        $display("Completed %0d images, %0d correct, accuracy %.2f%%",
                 frames_done, correct, 100.0*correct/NUM_TESTS);
        $finish;
    end
endmodule
