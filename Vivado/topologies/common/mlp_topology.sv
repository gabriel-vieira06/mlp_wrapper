// Shared accelerator for one, two or three hidden ReLU layers, followed by
// a linear output layer. Memory files follow the actual layer order H1..H4.
module mlp_topology #(
    parameter int WIDTH = 32,
    parameter int P_INT = 10,
    parameter int N_MULT = 1,
    parameter int INPUT_SIZE = 784,
    parameter int OUTPUT_SIZE = 10,
    parameter int HIDDEN_LAYERS = 2,
    parameter int H1_SIZE = 64,
    parameter int H2_SIZE = 32,
    parameter int H3_SIZE = 128
)(
    input  wire clk,
    input  wire rst,
    input  wire [WIDTH-1:0] data_in,
    input  wire data_valid,
    output wire ready_in,
    output wire [WIDTH-1:0] data_out,
    output wire data_out_valid,
    output wire data_out_last,
    input  wire ready_out
);
    localparam int INPUT_ADDR_WIDTH = $clog2(INPUT_SIZE);
    localparam int OUTPUT_ADDR_WIDTH = $clog2(OUTPUT_SIZE);

    wire [WIDTH-1:0] input_parallel [INPUT_SIZE];
    wire [WIDTH-1:0] unused_read [N_MULT];
    logic [WIDTH-1:0] input_read [N_MULT];
    wire [INPUT_ADDR_WIDTH-1:0] input_read_addr;
    logic [INPUT_ADDR_WIDTH-1:0] pixel_count;
    logic start_h1;
    logic busy;
    logic streaming_out;
    logic [OUTPUT_ADDR_WIDTH-1:0] out_count;
    wire [WIDTH-1:0] h1_out [H1_SIZE];
    wire h1_finish;
    wire [WIDTH-1:0] scores [OUTPUT_SIZE];
    wire final_finish;

    // One complete input frame is accepted at a time. During output stalls,
    // hold the selected score and TLAST stable until the beat is accepted.
    assign ready_in = !rst && !busy;
    assign data_out = scores[out_count];
    assign data_out_valid = streaming_out && !rst;
    assign data_out_last = streaming_out && (out_count == OUTPUT_SIZE-1) && !rst;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            pixel_count <= 0;
            start_h1 <= 0;
            busy <= 0;
            streaming_out <= 0;
            out_count <= 0;
        end else begin
            start_h1 <= 0;
            if (data_valid && ready_in) begin
                if (pixel_count == INPUT_SIZE-1) begin
                    pixel_count <= 0;
                    start_h1 <= 1;
                    busy <= 1;
                end else pixel_count <= pixel_count + 1'b1;
            end
            if (final_finish) begin
                streaming_out <= 1;
                out_count <= 0;
            end else if (streaming_out && ready_out) begin
                if (out_count == OUTPUT_SIZE-1) begin
                    streaming_out <= 0;
                    out_count <= 0;
                    busy <= 0;
                end else out_count <= out_count + 1'b1;
            end
        end
    end

    generate
        for (genvar lane = 0; lane < N_MULT; lane++) begin : unused_read_tieoff
            assign unused_read[lane] = {WIDTH{1'b0}};
        end
        if (N_MULT == 1) begin : input_bram
            (* ram_style = "block" *) logic [WIDTH-1:0] pixels [INPUT_SIZE];
            always_ff @(posedge clk) begin
                if (data_valid && ready_in) pixels[pixel_count] <= data_in;
                input_read[0] <= pixels[input_read_addr];
            end
            for (genvar k = 0; k < INPUT_SIZE; k++) begin : parallel_tieoff
                assign input_parallel[k] = {WIDTH{1'b0}};
            end
        end else begin : input_registers
            logic [WIDTH-1:0] pixels [INPUT_SIZE];
            always_ff @(posedge clk) begin
                if (data_valid && ready_in) pixels[pixel_count] <= data_in;
            end
            for (genvar k = 0; k < INPUT_SIZE; k++) begin : parallel_input
                assign input_parallel[k] = pixels[k];
            end
            for (genvar lane = 0; lane < N_MULT; lane++) begin : serial_tieoff
                assign input_read[lane] = {WIDTH{1'b0}};
            end
        end
    endgenerate

    mlp_topology_layer #(
        .WIDTH(WIDTH), .P_INT(P_INT), .N_MULT(N_MULT),
        .INPUT_SIZE(INPUT_SIZE), .OUTPUT_SIZE(H1_SIZE),
        .ACTIVATION(2), .REGISTERED_INPUT(N_MULT == 1),
        .WEIGHT_FILE("H1W.mem"), .BIAS_FILE("H1B.mem")
    ) hidden1 (
        .clk(clk), .rst(rst), .start(start_h1),
        .x(input_parallel), .x_read(input_read), .addr_x(input_read_addr),
        .y(h1_out), .finish(h1_finish)
    );

    generate
        if (HIDDEN_LAYERS == 1) begin : one_hidden
            mlp_topology_layer #(
                .WIDTH(WIDTH), .P_INT(P_INT), .N_MULT(N_MULT),
                .INPUT_SIZE(H1_SIZE), .OUTPUT_SIZE(OUTPUT_SIZE),
                .ACTIVATION(0), .WEIGHT_FILE("H2W.mem"), .BIAS_FILE("H2B.mem")
            ) output_layer (
                .clk(clk), .rst(rst), .start(h1_finish),
                .x(h1_out), .x_read(unused_read), .addr_x(),
                .y(scores), .finish(final_finish)
            );
        end else begin : additional_hidden
            wire [WIDTH-1:0] h2_out [H2_SIZE];
            wire h2_finish;
            mlp_topology_layer #(
                .WIDTH(WIDTH), .P_INT(P_INT), .N_MULT(N_MULT),
                .INPUT_SIZE(H1_SIZE), .OUTPUT_SIZE(H2_SIZE),
                .ACTIVATION(2), .WEIGHT_FILE("H2W.mem"), .BIAS_FILE("H2B.mem")
            ) hidden2 (
                .clk(clk), .rst(rst), .start(h1_finish),
                .x(h1_out), .x_read(unused_read), .addr_x(),
                .y(h2_out), .finish(h2_finish)
            );

            if (HIDDEN_LAYERS == 2) begin : two_hidden
                mlp_topology_layer #(
                    .WIDTH(WIDTH), .P_INT(P_INT), .N_MULT(N_MULT),
                    .INPUT_SIZE(H2_SIZE), .OUTPUT_SIZE(OUTPUT_SIZE),
                    .ACTIVATION(0), .WEIGHT_FILE("H3W.mem"), .BIAS_FILE("H3B.mem")
                ) output_layer (
                    .clk(clk), .rst(rst), .start(h2_finish),
                    .x(h2_out), .x_read(unused_read), .addr_x(),
                    .y(scores), .finish(final_finish)
                );
            end else begin : three_hidden
                wire [WIDTH-1:0] h3_out [H3_SIZE];
                wire h3_finish;
                mlp_topology_layer #(
                    .WIDTH(WIDTH), .P_INT(P_INT), .N_MULT(N_MULT),
                    .INPUT_SIZE(H2_SIZE), .OUTPUT_SIZE(H3_SIZE),
                    .ACTIVATION(2), .WEIGHT_FILE("H3W.mem"), .BIAS_FILE("H3B.mem")
                ) hidden3 (
                    .clk(clk), .rst(rst), .start(h2_finish),
                    .x(h2_out), .x_read(unused_read), .addr_x(),
                    .y(h3_out), .finish(h3_finish)
                );
                mlp_topology_layer #(
                    .WIDTH(WIDTH), .P_INT(P_INT), .N_MULT(N_MULT),
                    .INPUT_SIZE(H3_SIZE), .OUTPUT_SIZE(OUTPUT_SIZE),
                    .ACTIVATION(0), .WEIGHT_FILE("H4W.mem"), .BIAS_FILE("H4B.mem")
                ) output_layer (
                    .clk(clk), .rst(rst), .start(h3_finish),
                    .x(h3_out), .x_read(unused_read), .addr_x(),
                    .y(scores), .finish(final_finish)
                );
            end
        end
    endgenerate
endmodule

// A dense layer and its synchronous weight ROM. Keeping this wiring shared
// prevents topology variants from diverging in address widths or memory sizes.
module mlp_topology_layer #(
    parameter int WIDTH = 32,
    parameter int P_INT = 10,
    parameter int N_MULT = 1,
    parameter int INPUT_SIZE = 784,
    parameter int OUTPUT_SIZE = 64,
    parameter int ACTIVATION = 2,
    parameter bit REGISTERED_INPUT = 0,
    parameter string WEIGHT_FILE = "H1W.mem",
    parameter string BIAS_FILE = "H1B.mem"
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [WIDTH-1:0] x [INPUT_SIZE],
    input wire [WIDTH-1:0] x_read [N_MULT],
    output wire [$clog2(INPUT_SIZE)-1:0] addr_x,
    output wire [WIDTH-1:0] y [OUTPUT_SIZE],
    output wire finish
);
    localparam int BIAS_LANES = (N_MULT / INPUT_SIZE < 1) ? 1 : N_MULT / INPUT_SIZE;
    wire [WIDTH-1:0] weights [N_MULT];
    wire [WIDTH-1:0] biases [BIAS_LANES];
    wire [$clog2(INPUT_SIZE * OUTPUT_SIZE)-1:0] addr_w;
    wire [$clog2(OUTPUT_SIZE)-1:0] addr_b;

    dense #(
        .n_in(INPUT_SIZE), .n_mult(N_MULT), .layer_size(OUTPUT_SIZE),
        .WIDTH(WIDTH), .p_int(P_INT), .activation_function(ACTIVATION),
        .REGISTERED_INPUT(REGISTERED_INPUT)
    ) compute (
        .clk(clk), .rst(rst), .start(start),
        .X(x), .X_read(x_read), .addr_x(addr_x),
        .W(weights), .bias(biases), .Y(y),
        .addr_w(addr_w), .addr_b(addr_b), .finish(finish)
    );

    mem_behavioral_W #(
        .ADDR_WIDTH($clog2(INPUT_SIZE * OUTPUT_SIZE)), .DATA_WIDTH(WIDTH),
        .DEPTH(INPUT_SIZE * OUTPUT_SIZE), .n_mult(N_MULT), .FILENAME(WEIGHT_FILE)
    ) weight_rom (
        .clk(clk), .addr(addr_w), .dout(weights)
    );
    mem_behavioral_B #(
        .ADDR_WIDTH($clog2(OUTPUT_SIZE)), .DATA_WIDTH(WIDTH),
        .DEPTH(OUTPUT_SIZE), .t2s(BIAS_LANES), .FILENAME(BIAS_FILE)
    ) bias_rom (
        .addr(addr_b), .dout(biases)
    );
endmodule
