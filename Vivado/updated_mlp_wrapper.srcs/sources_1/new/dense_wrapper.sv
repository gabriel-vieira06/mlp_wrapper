module dense_wrapper #(
    parameter int WIDTH       = 32,  
                  P_INT       = 10,
                  N_MULT      = 1,
                  H1_IN_SIZE  = 784,
                  H1_OUT_SIZE = 64,
                  H2_IN_SIZE  = 64,
                  H2_OUT_SIZE = 32,
                  H3_IN_SIZE  = 32,
                  H3_OUT_SIZE = 10
)(
    clk,
    rst,
    data_in,
    data_out,
    ready_in,
    data_valid,
    data_out_valid,
    data_out_last,
    ready_out
);

    localparam int h1_t2s = ((N_MULT/H1_IN_SIZE)  == 0) ? 1 : N_MULT/H1_IN_SIZE;
    localparam int h2_t2s = ((N_MULT/H2_IN_SIZE)  == 0) ? 1 : N_MULT/H2_IN_SIZE;
    localparam int h3_t2s = ((N_MULT/H3_IN_SIZE)  == 0) ? 1 : N_MULT/H3_IN_SIZE;

    input logic                                 clk;
    input logic                                 rst;
    input logic  [                   WIDTH-1:0] data_in;
    input logic                                 data_valid;
    output logic                                ready_in;
    output logic [                   WIDTH-1:0] data_out;
    output logic                                data_out_valid;
    output logic                                data_out_last;
    input logic                                 ready_out;
    
    logic [                          WIDTH-1:0] input_buffer [H1_IN_SIZE];
    logic [                          WIDTH-1:0] input_read [N_MULT];
    wire  [                          WIDTH-1:0] unused_input_read [N_MULT];
    logic [         $clog2(H1_IN_SIZE)-1:0] input_read_addr;
    logic [               $clog2(H1_IN_SIZE):0] pixel_count;
    logic                                       start_h1;
    
    typedef enum logic [2:0] {linear, sigmoid, relu, tanh, leaky, step} acfunc;
    
    logic [                          WIDTH-1:0] H1_out [H1_OUT_SIZE];
    logic                                       H1_finish;
    
    logic [                          WIDTH-1:0] H2_out [H2_OUT_SIZE];
    logic                                       H2_finish;
    
    logic [                          WIDTH-1:0] H3_out [H3_OUT_SIZE];
    logic                                       H3_finish;
    
    logic [                          WIDTH-1:0] H1_W [N_MULT];
    logic [                          WIDTH-1:0] H1_B [h1_t2s];
    logic [ $clog2(H1_IN_SIZE*H1_OUT_SIZE)-1:0] H1_addr_w;
    logic [            $clog2(H1_OUT_SIZE)-1:0] H1_addr_b;
    
    logic [                          WIDTH-1:0] H2_W [N_MULT];
    logic [                          WIDTH-1:0] H2_B [h2_t2s];
    logic [ $clog2(H2_IN_SIZE*H2_OUT_SIZE)-1:0] H2_addr_w;
    logic [            $clog2(H2_OUT_SIZE)-1:0] H2_addr_b; 
    
    logic [                          WIDTH-1:0] H3_W [N_MULT];
    logic [                          WIDTH-1:0] H3_B [h3_t2s];
    logic [ $clog2(H3_IN_SIZE*H3_OUT_SIZE)-1:0] H3_addr_w;
    logic [            $clog2(H3_OUT_SIZE)-1:0] H3_addr_b; 
    
    logic [            $clog2(H3_OUT_SIZE)-1:0] out_count;
    logic                                       streaming_out;
        
    assign ready_in = (pixel_count < H1_IN_SIZE) && !streaming_out && !rst;

    generate
        // XSim does not support an assignment pattern directly on this
        // unpacked-array port. Tie off each lane through an explicit net.
        for (genvar lane = 0; lane < N_MULT; lane++) begin : unused_read_tieoff
            assign unused_input_read[lane] = {WIDTH{1'b0}};
        end

        if (N_MULT == 1) begin : input_bram
            // One write port and one synchronous read port infer a simple
            // dual-port RAM instead of 784 words of FFs and a wide read mux.
            // Do not reset the array: each frame overwrites every location.
            (* ram_style = "block" *) logic [WIDTH-1:0] pixels [H1_IN_SIZE];
            always_ff @(posedge clk) begin
                if (data_valid && ready_in)
                    pixels[pixel_count] <= data_in;
                input_read[0] <= pixels[input_read_addr];
            end
            for (genvar k = 0; k < H1_IN_SIZE; k++) begin : unused_parallel_input
                assign input_buffer[k] = '0;
            end
        end else begin : input_parallel
            // Preserve the existing multi-lane configuration. Only the
            // default single-lane design uses the input block RAM port.
            always_ff @(posedge clk) begin
                if (data_valid && ready_in)
                    input_buffer[pixel_count] <= data_in;
            end
            for (genvar k = 0; k < N_MULT; k++) begin : unused_serial_input
                assign input_read[k] = '0;
            end
        end
    endgenerate
        
    // STREAMING DE ENTRADA    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            pixel_count <= 0;
            start_h1    <= 0;
        end
        else begin
            start_h1 <= 0;
    
            if (data_valid && ready_in) begin
                if (pixel_count == H1_IN_SIZE-1) begin
                    start_h1    <= 1;
                    pixel_count <= 0;
                end
                else begin
                    pixel_count <= pixel_count + 1;
                end
            end
        end
    end
    
    // STREAMING DE SAÍDA
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            out_count       <= 0;
            streaming_out   <= 0;
            data_out_valid  <= 0;
            data_out_last   <= 0;
            data_out        <= 0;
        end
        else begin
            data_out_valid  <= 0;
            data_out_last   <= 0;
    
            // Quando a rede termina
            if (H3_finish) begin
                streaming_out <= 1;
                out_count     <= 0;
            end
            // Streaming
            else if (streaming_out && ready_out) begin
                data_out       <= H3_out[out_count];
                data_out_valid <= 1;
    
                if (out_count == H3_OUT_SIZE-1) begin
                    data_out_last <= 1;
                    streaming_out <= 0;
                    out_count     <= 0;
                end
                else begin
                    out_count     <= out_count + 1;
                end
            end
        end
    end
    
    dense #(
        .n_in(H1_IN_SIZE), 
        .n_mult(N_MULT), 
        .layer_size(H1_OUT_SIZE), 
        .WIDTH(WIDTH), 
        .p_int(P_INT),
        .activation_function(relu),
        .REGISTERED_INPUT(N_MULT == 1)
    )
    hidden1
    (
        .clk(clk),
        .rst(rst),
        .start(start_h1),
        .X(input_buffer),
        .X_read(input_read),
        .addr_x(input_read_addr),
        .W(H1_W),
        .bias(H1_B),
        .Y(H1_out),
        .addr_w(H1_addr_w),
        .addr_b(H1_addr_b),
        .finish(H1_finish)
    );
    
    dense #(
        .n_in(H2_IN_SIZE), 
        .n_mult(N_MULT), 
        .layer_size(H2_OUT_SIZE), 
        .WIDTH(WIDTH), 
        .p_int(P_INT),
        .activation_function(relu)
    )
    hidden2
    (
        .clk(clk),
        .rst(rst),
        .start(H1_finish),
        .X(H1_out),
        .X_read(unused_input_read),
        .addr_x(),
        .W(H2_W),
        .bias(H2_B),
        .Y(H2_out),
        .addr_w(H2_addr_w),
        .addr_b(H2_addr_b),
        .finish(H2_finish)
    );
    
    dense #(
        .n_in(H3_IN_SIZE), 
        .n_mult(N_MULT), 
        .layer_size(H3_OUT_SIZE), 
        .WIDTH(WIDTH), 
        .p_int(P_INT),
        .activation_function(linear)
    )
    hidden3
    (
        .clk(clk),
        .rst(rst),
        .start(H2_finish),
        .X(H2_out),
        .X_read(unused_input_read),
        .addr_x(),
        .W(H3_W),
        .bias(H3_B),
        .Y(H3_out),
        .addr_w(H3_addr_w),
        .addr_b(H3_addr_b),
        .finish(H3_finish)
    );
    
    mem_behavioral_W #(
        .ADDR_WIDTH($clog2(H1_IN_SIZE*H1_OUT_SIZE)),
        .DEPTH(H1_IN_SIZE*H1_OUT_SIZE),
        .FILENAME("H1W.mem"),
        .n_mult(N_MULT)
    ) H1_W_mem (
        .clk(clk),
        .addr(H1_addr_w),
        .dout(H1_W)
    );
    
    mem_behavioral_W #(
        .ADDR_WIDTH($clog2(H2_IN_SIZE*H2_OUT_SIZE)),
        .DEPTH(H2_IN_SIZE*H2_OUT_SIZE),
        .FILENAME("H2W.mem"),
        .n_mult(N_MULT)
    ) H2_W_mem (
        .clk(clk),
        .addr(H2_addr_w),
        .dout(H2_W)
    );
    
    mem_behavioral_W #(
        .ADDR_WIDTH($clog2(H3_IN_SIZE*H3_OUT_SIZE)),
        .DEPTH(H3_IN_SIZE*H3_OUT_SIZE),
        .FILENAME("H3W.mem"),
        .n_mult(N_MULT)
    ) H3_W_mem (
        .clk(clk),
        .addr(H3_addr_w),
        .dout(H3_W)
    );

    mem_behavioral_B #(
        .ADDR_WIDTH($clog2(H1_OUT_SIZE)),
        .t2s(h1_t2s),
        .DEPTH(H1_OUT_SIZE),
        .FILENAME("H1B.mem")
    ) H1_B_mem (
        //.clk(clk),
        .addr(H1_addr_b),
        .dout(H1_B)
    );
    
    mem_behavioral_B #(
        .ADDR_WIDTH($clog2(H2_OUT_SIZE)),
        .t2s(h2_t2s),
        .DEPTH(H2_OUT_SIZE),
        .FILENAME("H2B.mem")
    ) H2_B_mem (
        //.clk(clk),
        .addr(H2_addr_b),
        .dout(H2_B)
    );
    
    mem_behavioral_B #(
        .ADDR_WIDTH($clog2(H3_OUT_SIZE)),
        .t2s(h3_t2s),
        .DEPTH(H3_OUT_SIZE),
        .FILENAME("H3B.mem")
    ) H3_B_mem (
        //.clk(clk),
        .addr(H3_addr_b),
        .dout(H3_B)
    );

endmodule
