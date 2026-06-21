module dense #(
    parameter int n_in = 1, n_mult = 1, layer_size = 1, WIDTH = 32, p_int = 10,
    parameter int slope = 0,
    parameter logic [2:0] activation_function = 0
)(
    clk,
    rst,
    start,
    X,
    W,
    bias,
    Y,
    addr_w,
    addr_b,
    finish
);

    localparam int t2s = ((n_mult/n_in) == 0) ? 1 : n_mult/n_in;

    
    input logic                                 clk;
    input logic                                 rst;
    input logic                                 start;
    input logic  [                  WIDTH-1:0]  X       [n_in];
    input logic  [                  WIDTH-1:0]  W       [n_mult];
    input logic  [                  WIDTH-1:0]  bias    [t2s];
    output logic [                  WIDTH-1:0]  Y       [layer_size];
    output logic [$clog2(n_in*layer_size)-1:0]  addr_w;
    output logic [     $clog2(layer_size)-1:0]  addr_b;
    output logic                                finish;

    typedef enum logic [2:0] {linear, sigmoid, relu, tanh, leaky, step} acfunc;
    typedef enum logic [1:0] { INIT, CALC, FINISH } states;

    states current, next;

    logic [WIDTH*2-1:0] Mres   [n_mult];
    logic   [WIDTH-1:0] X_temp [n_mult];
    logic   [WIDTH-1:0] W_temp [n_mult];

    logic [WIDTH*2-1:0] Y_temp_in  [layer_size];
    logic [WIDTH*2-1:0] Y_temp_out [layer_size];
    logic   [WIDTH-1:0] Y_cmb      [layer_size];

    logic [WIDTH*2-1:0] temp, temp_ff;

    logic [WIDTH*2-1:0] adj_bias [t2s];

    logic [WIDTH*2-1:0] temp2    [t2s];
    logic [WIDTH*2-1:0] temp2_ff [t2s];

    logic [$clog2(n_in+n_mult):0] counter_in, counter_in_ff;
    logic [$clog2(layer_size):0] counter_n, counter_n_ff;

    genvar i;
    generate
        for (i = 0; i < n_mult; i++) begin : multPF
            mult2c #(
                    .WIDTH(WIDTH)
                )
                mpf
                (
                    X_temp[i],
                    W_temp[i],
                    Mres[i]
                );
        end
        if (activation_function == sigmoid) begin
            if (t2s < 2) begin
                hard_sigmoid #(
                        .WIDTH(WIDTH*2),
                        .p_int(p_int*2),
                        .slope(slope)
                    )
                    hard_sig
                    (
                        Y_temp_in[0],
                        Y_temp_out[0]
                    );
            end
            else begin
                for (i = 0; i < t2s; i++) begin : hard_sigmoid
                    hard_sigmoid #(
                            .WIDTH(WIDTH*2),
                            .p_int(p_int*2),
                            .slope(slope)
                        )
                        hard_sig
                        (
                            Y_temp_in[i],
                            Y_temp_out[i]
                        );
                end
            end
        end
        if (activation_function == relu) begin
            if (t2s < 2) begin
                ReLU #(
                        .WIDTH(WIDTH*2)
                    )
                    relu
                    (
                        Y_temp_in[0],
                        Y_temp_out[0]
                    );
            end
            else begin
                for (i = 0; i < t2s; i++) begin : ReLU
                    ReLU #(
                            .WIDTH(WIDTH*2)
                        )
                        relu
                        (
                            Y_temp_in[i],
                            Y_temp_out[i]
                        );
                end
            end
        end
        if (activation_function == tanh) begin
            if (t2s < 2) begin
                hard_tanh #(
                        .WIDTH(WIDTH*2),
                        .p_int(p_int*2),
                        .slope(slope)
                    )
                    hard_th
                    (
                        Y_temp_in[0],
                        Y_temp_out[0]
                    );
            end
            else begin
                for (i = 0; i < t2s; i++) begin : hard_tanh
                    hard_tanh #(
                            .WIDTH(WIDTH*2),
                            .p_int(p_int*2),
                            .slope(slope)
                        )
                        hard_th
                        (
                            Y_temp_in[i],
                            Y_temp_out[i]
                        );
                end
            end
        end
        if (activation_function == leaky) begin
            if (t2s < 2) begin
                leakyReLU #(
                        .WIDTH(WIDTH*2),
                        .p_int(p_int*2)
                    )
                    leaky
                    (
                        Y_temp_in[0],
                        slope,
                        Y_temp_out[0]
                    );
            end
            else begin
                for (i = 0; i < t2s; i++) begin : leaky_ReLU
                    leakyReLU #(
                            .WIDTH(WIDTH*2),
                            .p_int(p_int*2)
                        )
                        leaky
                        (
                            Y_temp_in[i],
                            slope,
                            Y_temp_out[i]
                        );
                end
            end
        end
        if (activation_function == step) begin
            if (t2s < 2) begin
                step #(
                        .WIDTH(WIDTH*2),
                        .p_int(p_int*2)
                    )
                    stp
                    (
                        Y_temp_in[0],
                        Y_temp_out[0]
                    );
            end
            else begin
                for (i = 0; i < t2s; i++) begin : step
                    step #(
                            .WIDTH(WIDTH*2),
                            .p_int(p_int*2)
                        )
                        stp
                        (
                            Y_temp_in[i],
                            Y_temp_out[i]
                        );
                end
            end
        end
    endgenerate

    assign addr_w = (t2s < 2) ? counter_n_ff*n_in+counter_in_ff : counter_n_ff*n_in;
    assign addr_b = counter_n_ff;

    always_comb begin
        for (int i = 0; i < t2s; i++)
        //  adj_bias[i] = bias[i] << (WIDTH-p_int);
            adj_bias[i] = bias[i] << (p_int);
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            current       <= INIT;
            counter_in_ff <= 'd0;
            counter_n_ff  <= 'd0;
            temp_ff       <= 'd0;

            for (int i = 0; i < t2s; i++)
                temp2_ff[i] <= 'd0;

            for (int i = 0;i < layer_size; i++)
                Y[i] = 'd0;
        end
        else begin
            current       <= next;
            counter_in_ff <= counter_in;
            counter_n_ff  <= counter_n;

            if (current == CALC || current == FINISH)
                temp_ff <= temp;
            else
                temp_ff <= 'd0;

            if (current == CALC || current == FINISH)
                for (int i = 0; i < t2s; i++)
                    temp2_ff[i] <= 'd0;
            else
                for (int i = 0; i < t2s; i++)
                    temp2_ff[i] <= 'd0;
            Y <= Y_cmb;
        end
    end

    always_comb begin
        temp       = 'd0;
        finish     = 'd0;
        counter_in = 'd0;
        counter_n  = 'd0;
        next       = current;

        for (int i = 0; i < t2s; i++)
            temp2[i] = 'd0;

        for (int i = 0; i < n_mult; i++) begin
            X_temp[i] = 'd0;
            W_temp[i] = 'd0;
        end
        for (int i = 0; i < layer_size; i++)
            Y_temp_in[i]  = 'd0;


        Y_cmb = Y;
        
        case (current)
            INIT: begin
                if (start) begin
                    next = CALC;
                end
            end
            CALC: begin
                if (t2s < 2) begin
                    counter_n  = counter_n_ff;
                    counter_in = counter_in_ff + n_mult;
                    temp       = temp_ff;

                    for (int i = 0; i < n_mult; i++) begin
                        if (i+counter_in_ff >= n_in) begin
                            X_temp[i] = 'd0;
                            W_temp[i] = 'd0;
                        end
                        else begin
                            X_temp[i] = X[i+counter_in_ff];
                            //W_temp[i] = W[counter_n_ff][i+counter_in_ff];
                            W_temp[i] = W[i];
                        end
                        temp += Mres[i];
                    end

                    if (counter_in >= n_in) begin
                        Y_temp_in[0] = temp + adj_bias[0];
                        if (activation_function == linear)
                            Y_cmb[counter_n_ff] = Y_temp_in[0][(WIDTH*2-1)-p_int-:WIDTH];
                        if (
                            activation_function == sigmoid ||
                            activation_function == relu    ||
                            activation_function == tanh    ||
                            activation_function == leaky   ||
                            activation_function == step
                            )
                            Y_cmb[counter_n_ff] = Y_temp_out[0][(WIDTH*2-1)-p_int-:WIDTH];

                        counter_n  = counter_n_ff + 'd1;
                        counter_in = 'd0;
                        temp = 'd0;
                        if (counter_n == layer_size) begin
                            counter_n = 'd0;
                            next = FINISH;
                        end
                    end
                end
                else begin
                    counter_n  = counter_n_ff + t2s;

                    for (int i = 0; i < t2s; i++)
                        temp2[i] = temp2_ff[i];

                    for (int i = 0; i < t2s; i++) begin
                        for (int j = 0; j < n_in; j++) begin
                            X_temp[n_in*i+j] = X[j];
                            //W_temp[n_in*i+j] = W[i+counter_n_ff][j];
                            W_temp[n_in*i+j] = W[i*n_in + j];
                            temp2[i]        += Mres[n_in*i+j];
                        end
                        Y_temp_in[i] = temp2[i] + adj_bias[i];
                        if (activation_function == linear)
                            Y_cmb[i+counter_n_ff] = Y_temp_in[i][(WIDTH*2-1)-p_int-:WIDTH];
                        if (
                            activation_function == sigmoid ||
                            activation_function == relu    ||
                            activation_function == tanh    ||
                            activation_function == leaky   ||
                            activation_function == step
                            )
                            Y_cmb[i+counter_n_ff] = Y_temp_out[i][(WIDTH*2-1)-p_int-:WIDTH];
                    end

                    if (counter_n >= layer_size) begin
                        counter_n = 0;
                        next = FINISH;
                    end
                end
            end
            FINISH: begin
                finish = 'd1;
                next   = INIT;
            end
        endcase
        
        if (rst) begin
            for (int i = 0; i< layer_size; i++)
                Y_cmb[i] = 'd0;
        end
    end

endmodule