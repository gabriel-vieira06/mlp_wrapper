module hard_sigmoid #(
    parameter int WIDTH = 32,
    parameter int p_int = 10, 
    parameter int slope = 0
)(
    input logic [WIDTH-1:0] in,
    output logic [WIDTH-1:0] out
);

    localparam logic [WIDTH-1:0] slp = slope;

    logic [WIDTH*2-1:0] mult;
    logic [WIDTH-1:0] temp;

    mult2c #(.WIDTH(WIDTH)) mt (in, slp , mult);

    always_comb begin
        temp = mult[WIDTH*2-(p_int+1)-:WIDTH] + (1 << (WIDTH-(p_int+2)));
        if (temp[WIDTH-1] && (-temp >= 0))
            out = 'd0;
        else if (~temp[WIDTH-1] && temp >= (1 << (WIDTH-(p_int+1))))
            out = 1 << (WIDTH-(p_int+1));
        else
            out = temp;
    end

endmodule