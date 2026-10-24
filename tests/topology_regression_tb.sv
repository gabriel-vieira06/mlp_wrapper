`timescale 1ns / 1ps

// Synthetic functional regression. This tests topology wiring and the legacy
// fixed-point arithmetic; it does not claim accuracy for a trained model.
module topology_regression_tb #(
    parameter int HIDDEN_LAYERS = 2,
    parameter int H1_SIZE = 500,
    parameter int H2_SIZE = 500,
    parameter int H3_SIZE = 128,
    parameter int FRAMES = 2,
    parameter bit USE_ADAPTER = 1,
    parameter bit OUTPUT_STALLS = 0
);
    localparam int LAST_SIZE = HIDDEN_LAYERS == 1 ? H1_SIZE :
                               HIDDEN_LAYERS == 2 ? H2_SIZE : H3_SIZE;
    localparam int MACS = 784*H1_SIZE +
                         (HIDDEN_LAYERS >= 2 ? H1_SIZE*H2_SIZE : 0) +
                         (HIDDEN_LAYERS >= 3 ? H2_SIZE*H3_SIZE : 0) +
                         LAST_SIZE*10;
    localparam longint MAX_CYCLES = 64'(FRAMES) * (6*MACS + 10000);

    logic clk = 0;
    logic rst = 1;
    logic [31:0] data_in = 0;
    logic data_valid = 0;
    logic input_last = 0;
    logic ready_out = 1;
    logic ready_in;
    logic [31:0] data_out;
    logic data_out_valid, data_out_last;
    logic [31:0] pixels [0:FRAMES*784-1];
    int logits_file;
    int frames_done = 0;
    int output_index = 0;
    int outputs_done = 0;
    longint cycles = 0;
    int stalled_cycles = 0;
    logic was_stalled = 0;
    logic [31:0] held_data;
    logic held_last;

    generate
        if (USE_ADAPTER) begin : variant_adapter
            // Compile the actual per-variant top, including reset polarity
            // and its fixed topology parameters, rather than only the core.
            mlp dut (
                .clk(clk), .rst_n(~rst),
                .s_axis_tdata(data_in), .s_axis_tvalid(data_valid),
                .s_axis_tready(ready_in), .s_axis_tlast(input_last),
                .m_axis_tdata(data_out), .m_axis_tvalid(data_out_valid),
                .m_axis_tready(ready_out), .m_axis_tlast(data_out_last),
                .dbg_valid_in(), .dbg_valid_out()
            );
        end else begin : generic_core
            mlp_topology #(
                .WIDTH(32), .P_INT(10), .N_MULT(1),
                .HIDDEN_LAYERS(HIDDEN_LAYERS),
                .H1_SIZE(H1_SIZE), .H2_SIZE(H2_SIZE), .H3_SIZE(H3_SIZE)
            ) dut (
                .clk(clk), .rst(rst), .data_in(data_in), .data_valid(data_valid),
                .ready_in(ready_in), .data_out(data_out),
                .data_out_valid(data_out_valid), .data_out_last(data_out_last),
                .ready_out(ready_out)
            );
        end
    endgenerate

    always #5 clk = ~clk;

    always @(posedge clk) begin
        cycles++;
        if (cycles > MAX_CYCLES)
            $fatal(1, "Timeout: %0d/%0d frames and %0d logits",
                   frames_done, FRAMES, outputs_done);
    end

    // Readiness changes halfway between sampling edges. Scoreboard sampling
    // occurs on the actual transfer edge, so stalled beats are never counted.
    always @(negedge clk) begin
        if (OUTPUT_STALLS) ready_out = cycles % 7 >= 3;
    end

    always @(posedge clk) begin
        if (rst) begin
            was_stalled = 0;
        end else begin
            if (was_stalled && (!data_out_valid || data_out !== held_data ||
                                data_out_last !== held_last))
                $fatal(1, "Output data/valid/last changed while stalled");
            was_stalled = data_out_valid && !ready_out;
            if (was_stalled) stalled_cycles++;
            held_data = data_out;
            held_last = data_out_last;
        end
        if (!rst && data_out_valid && ready_out) begin
            if (frames_done >= FRAMES || output_index >= 10)
                $fatal(1, "Unexpected extra output");
            if (data_out_last !== (output_index == 9))
                $fatal(1, "Incorrect last flag at frame %0d output %0d",
                       frames_done, output_index);
            if ($isunknown(data_out))
                $fatal(1, "Unknown output at frame %0d output %0d",
                       frames_done, output_index);
            $fdisplay(logits_file, "%08x", data_out);
            outputs_done++;
            if (data_out_last) begin
                frames_done++;
                output_index = 0;
            end else begin
                output_index++;
            end
        end
    end

    initial begin
        $readmemh("synthetic_inputs.mem", pixels);
        logits_file = $fopen("logits.hex", "w");
        if (!logits_file) $fatal(1, "Cannot create logits.hex");
        repeat (4) @(negedge clk);
        rst = 0;

        for (int frame = 0; frame < FRAMES; frame++) begin
            for (int pixel = 0; pixel < 784; pixel++) begin
                @(negedge clk);
                if ((frame + pixel) % 29 == 0) begin
                    data_valid = 0;
                    @(negedge clk);
                end
                data_in = pixels[frame*784 + pixel];
                input_last = pixel == 783;
                data_valid = 1;
                do @(posedge clk); while (!ready_in);
            end
            @(negedge clk);
            data_valid = 0;
            input_last = 0;
            wait (frames_done == frame + 1);
            // Exercise multiple complete frames without resetting memories.
            repeat (4) @(negedge clk);
        end

        repeat (10) @(negedge clk);
        if (frames_done != FRAMES || outputs_done != FRAMES*10 || output_index != 0)
            $fatal(1, "Incomplete result: %0d frames and %0d logits",
                   frames_done, outputs_done);
        if (OUTPUT_STALLS && stalled_cycles == 0)
            $fatal(1, "Output backpressure was enabled but no beat stalled");
        $fclose(logits_file);
        $display("PASS: %0d frames, %0d logits, %0d cycles, %0d stalled cycles",
                 frames_done, outputs_done, cycles, stalled_cycles);
        $finish;
    end
endmodule
