`timescale 1ns / 1ps

// Simulate the selected variant's mlp.v with one paired 1,000-image MNIST batch.
module mlp_variant_tb #(
    parameter integer BATCH_ID = 0,
    parameter integer NUM_TESTS = 1000
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
    string samples_filename, labels_filename, log_filename;
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
                          BATCH_ID*1000 + frames_done, prediction, labels[frames_done]);
                frames_done++;
                output_index = 0;
            end else output_index++;
        end
    end

    initial begin
        if (BATCH_ID < 0 || BATCH_ID > 9)
            $fatal(1, "BATCH_ID must be between 0 and 9");
        if (NUM_TESTS < 1 || NUM_TESTS > 1000)
            $fatal(1, "NUM_TESTS must be between 1 and 1000");
        samples_filename = $sformatf("test_samples_%02d.mem", BATCH_ID);
        labels_filename = $sformatf("test_labels_%02d.mem", BATCH_ID);
        log_filename = $sformatf("mnist_batch_%02d_log.txt", BATCH_ID);
        input_file = $fopen(samples_filename, "r");
        label_file = $fopen(labels_filename, "r");
        log_file = $fopen(log_filename, "w");
        if (!input_file || !label_file || !log_file)
            $fatal(1, "Cannot open %s, %s or %s",
                   samples_filename, labels_filename, log_filename);
        $display("MNIST batch %0d: %s, %s; evaluating %0d images",
                 BATCH_ID, samples_filename, labels_filename, NUM_TESTS);
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
        $display("Batch %0d completed %0d images, %0d correct, accuracy %.2f%%",
                 BATCH_ID, frames_done, correct, 100.0*correct/NUM_TESTS);
        $finish;
    end
endmodule
