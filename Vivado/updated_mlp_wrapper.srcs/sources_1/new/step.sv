module step #(
    parameter int WIDTH=32, p_int=10
)(
    input logic [WIDTH-1:0] in,
    output logic [WIDTH-1:0] out
);

always_comb begin
    out = 'd0;
    if (in > 0 && ~in[WIDTH-1])
        out[WIDTH-p_int] = 'd1;
end

endmodule