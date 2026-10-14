module leakyReLU #(
    parameter int WIDTH = 32, p_int = 10
)(
    input logic [WIDTH-1:0] x, alpha,
    output logic [WIDTH-1:0] y 
);

    logic [WIDTH-1:0] mult; 

    mult2c #(.WIDTH(WIDTH)) mt (x, alpha, mult);

    always_comb begin
        if (x[WIDTH-1])
            y = mult;
        else
            y = x;
    end

endmodule