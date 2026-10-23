module dense #(
    parameter int n_in = 1, n_mult = 1, layer_size = 1, WIDTH = 32, p_int = 10,
    parameter int slope = 0,
    parameter logic [2:0] activation_function = 0,
    parameter bit REGISTERED_INPUT = 0
)(
    input  logic                                 clk,
    input  logic                                 rst,
    input  logic                                 start,
    input  logic  [                  WIDTH-1:0]  X       [n_in],
    // Optional synchronous input RAM port, used by the serial first layer.
    input  logic  [                  WIDTH-1:0]  X_read  [n_mult],
    output logic  [        $clog2(n_in)-1:0]     addr_x,
    input  logic  [                  WIDTH-1:0]  W       [n_mult],
    input  logic  [                  WIDTH-1:0]  bias    [((n_mult/n_in) == 0) ? 1 : n_mult/n_in],
    output logic  [                  WIDTH-1:0]  Y       [layer_size],
    output logic  [$clog2(n_in*layer_size)-1:0]  addr_w,
    output logic  [     $clog2(layer_size)-1:0]  addr_b,
    output logic                                 finish
);

    localparam int t2s = ((n_mult/n_in) == 0) ? 1 : n_mult/n_in;

    typedef enum logic [2:0] {linear, sigmoid, relu, tanh, leaky, step} acfunc;
    typedef enum logic [2:0] { INIT, READ_WAIT, FETCH, MULT, ACCUM, ACT_WRITE, FINISH } states;
    states current, next;

    logic [WIDTH*2-1:0] Y_temp_in  [layer_size];
    logic [WIDTH*2-1:0] Y_temp_out [layer_size];
    logic [WIDTH*2-1:0] adj_bias   [t2s];

    // Registradores de Pipeline
    logic [WIDTH-1:0]   X_reg      [n_mult];
    logic [WIDTH-1:0]   W_reg      [n_mult];
    logic [WIDTH*2-1:0] Mres       [n_mult];     
    logic [WIDTH*2-1:0] Mres_reg   [n_mult];     
    
    logic [WIDTH*2-1:0] temp_acc;                
    logic [WIDTH*2-1:0] acc_reg    [layer_size]; 

    logic [$clog2(n_in+n_mult):0] counter_in;
    logic [$clog2(layer_size):0]  counter_n;

    // Ajuste de bias e conexão contínua da Ativação (CORREÇÃO AQUI)
    always_comb begin
        for (int i = 0; i < t2s; i++) begin
            adj_bias[i] = bias[i] << (p_int);
        end
        // O acumulador final alimenta continuamente os módulos de ativação
        // Isso resolve a latência/race condition da FSM sequencial
        for (int k = 0; k < layer_size; k++) begin
            Y_temp_in[k] = acc_reg[k];
        end
    end

    // Geração dos Multiplicadores
    genvar i;
    generate
        for (i = 0; i < n_mult; i++) begin : multPF
            mult2c #(.WIDTH(WIDTH)) mpf (X_reg[i], W_reg[i], Mres[i]);
        end

        // Geração das Funções de Ativação
        if (activation_function == sigmoid) begin
            if (t2s < 2) begin
                hard_sigmoid #(.WIDTH(WIDTH*2), .p_int(p_int*2), .slope(slope)) hard_sig (Y_temp_in[0], Y_temp_out[0]);
            end else begin
                for (i = 0; i < t2s; i++) begin : hard_sigmoid
                    hard_sigmoid #(.WIDTH(WIDTH*2), .p_int(p_int*2), .slope(slope)) hard_sig (Y_temp_in[i], Y_temp_out[i]);
                end
            end
        end
        if (activation_function == relu) begin
            if (t2s < 2) begin
                ReLU #(.WIDTH(WIDTH*2)) relu (Y_temp_in[0], Y_temp_out[0]);
            end else begin
                for (i = 0; i < t2s; i++) begin : ReLU
                    ReLU #(.WIDTH(WIDTH*2)) relu (Y_temp_in[i], Y_temp_out[i]);
                end
            end
        end
        if (activation_function == tanh) begin
            if (t2s < 2) begin
                hard_tanh #(.WIDTH(WIDTH*2), .p_int(p_int*2), .slope(slope)) hard_th (Y_temp_in[0], Y_temp_out[0]);
            end else begin
                for (i = 0; i < t2s; i++) begin : hard_tanh
                    hard_tanh #(.WIDTH(WIDTH*2), .p_int(p_int*2), .slope(slope)) hard_th (Y_temp_in[i], Y_temp_out[i]);
                end
            end
        end
        if (activation_function == leaky) begin
            if (t2s < 2) begin
                leakyReLU #(.WIDTH(WIDTH*2), .p_int(p_int*2)) leaky (Y_temp_in[0], slope, Y_temp_out[0]);
            end else begin
                for (i = 0; i < t2s; i++) begin : leaky_ReLU
                    leakyReLU #(.WIDTH(WIDTH*2), .p_int(p_int*2)) leaky (Y_temp_in[i], slope, Y_temp_out[i]);
                end
            end
        end
        if (activation_function == step) begin
            if (t2s < 2) begin
                step #(.WIDTH(WIDTH*2), .p_int(p_int*2)) stp (Y_temp_in[0], Y_temp_out[0]);
            end else begin
                for (i = 0; i < t2s; i++) begin : step
                    step #(.WIDTH(WIDTH*2), .p_int(p_int*2)) stp (Y_temp_in[i], Y_temp_out[i]);
                end
            end
        end
    endgenerate

    assign addr_w = (t2s < 2) ? (counter_n * n_in) + counter_in : (counter_n * n_in);
    assign addr_b = counter_n;
    assign addr_x = counter_in;

    // --- FSM Pipelinizada Corrigida ---
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            current <= INIT;
            counter_in <= 'd0;
            counter_n <= 'd0;
            temp_acc <= 'd0;
            finish <= 1'b0;
            
            for (int k = 0; k < layer_size; k++) begin
                Y[k] <= 'd0;
                acc_reg[k] <= 'd0;
            end
            for (int k = 0; k < n_mult; k++) begin
                X_reg[k] <= 'd0;
                W_reg[k] <= 'd0;
                Mres_reg[k] <= 'd0;
            end
        end else begin
            case (current)
                INIT: begin
                    finish <= 1'b0;
                    counter_in <= 'd0;
                    counter_n <= 'd0;
                    temp_acc <= 'd0;
                    if (start) current <= READ_WAIT;
                end

                // Allow the synchronous weight ROM (and optional input RAM)
                // to read the address updated by INIT, ACCUM or ACT_WRITE.
                READ_WAIT: current <= FETCH;

                FETCH: begin
                    if (t2s < 2) begin
                        for (int j = 0; j < n_mult; j++) begin
                            if (j + counter_in >= n_in) begin
                                X_reg[j] <= 'd0;
                                W_reg[j] <= 'd0;
                            end else begin
                                if (REGISTERED_INPUT)
                                    X_reg[j] <= X_read[j];
                                else
                                    X_reg[j] <= X[j + counter_in];
                                W_reg[j] <= W[j];
                            end
                        end
                    end else begin
                        for (int j = 0; j < t2s; j++) begin
                            for (int k = 0; k < n_in; k++) begin
                                X_reg[n_in*j+k] <= X[k];
                                W_reg[n_in*j+k] <= W[j*n_in + k];
                            end
                        end
                    end
                    current <= MULT;
                end

                MULT: begin
                    for (int j = 0; j < n_mult; j++) begin
                        Mres_reg[j] <= Mres[j];
                    end
                    current <= ACCUM;
                end

                ACCUM: begin
                    if (t2s < 2) begin
                        logic [WIDTH*2-1:0] step_sum;
                        step_sum = temp_acc;
                        for (int j = 0; j < n_mult; j++) begin
                            step_sum += Mres_reg[j];
                        end
                        temp_acc <= step_sum;
                        counter_in <= counter_in + n_mult;

                        if (counter_in + n_mult >= n_in) begin 
                            acc_reg[0] <= step_sum + adj_bias[0];
                            current <= ACT_WRITE;
                        end else begin
                            current <= READ_WAIT;
                        end
                    end else begin
                        for (int j = 0; j < t2s; j++) begin
                            logic [WIDTH*2-1:0] step_sum_t2s;
                            // Correção 2: Sempre começa de zero (evita estouro da variavel antiga)
                            step_sum_t2s = 'd0; 
                            for (int k = 0; k < n_in; k++) begin
                                step_sum_t2s += Mres_reg[n_in*j+k];
                            end
                            acc_reg[j] <= step_sum_t2s + adj_bias[j];
                        end
                        current <= ACT_WRITE;
                    end
                end

                ACT_WRITE: begin
                    if (t2s < 2) begin
                        if (activation_function == linear) begin
                            // Puxa direto de acc_reg para linear
                            Y[counter_n] <= acc_reg[0][(WIDTH*2-1)-p_int-:WIDTH];
                        end else begin
                            // Y_temp_out agora tem o valor estável graças ao assign combinacional!
                            Y[counter_n] <= Y_temp_out[0][(WIDTH*2-1)-p_int-:WIDTH];
                        end
                        
                        counter_n <= counter_n + 1'b1;
                        counter_in <= 'd0;
                        temp_acc <= 'd0;

                        if (counter_n + 1'b1 >= layer_size) current <= FINISH;
                        else current <= READ_WAIT;
                        
                    end else begin
                        for (int j = 0; j < t2s; j++) begin
                            if (activation_function == linear) begin
                                Y[j+counter_n] <= acc_reg[j][(WIDTH*2-1)-p_int-:WIDTH];
                            end else begin
                                Y[j+counter_n] <= Y_temp_out[j][(WIDTH*2-1)-p_int-:WIDTH];
                            end
                        end
                        
                        counter_n <= counter_n + t2s;
                        if (counter_n + t2s >= layer_size) current <= FINISH;
                        else current <= READ_WAIT;
                    end
                end

                FINISH: begin
                    finish <= 1'b1;
                    current <= INIT;
                end
                
                default: current <= INIT;
            endcase
        end
    end

endmodule
