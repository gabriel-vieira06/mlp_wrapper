module mult2c #(parameter int WIDTH=32) (A, B, OUT);
    input  logic [WIDTH-1:0] A, B;
    output logic [WIDTH*2-1:0] OUT;

    logic [WIDTH-1:0] A_t, B_t;

    logic [WIDTH*2-1:0] OUT_t;

    always_comb begin
        A_t = A;
        B_t = B;

        if (A[WIDTH-1]^B[WIDTH-1])begin
            if (A[WIDTH-1])
                A_t = -A;
            if (B[WIDTH-1])
                B_t = -B;

            //OUT = -(A_t * B_t);
        end
        else begin
            if (A[WIDTH-1] && B[WIDTH-1]) begin
                A_t = -A;
                B_t = -B;
            end
            //OUT = A_t * B_t;
        end 

        OUT_t = A_t * B_t;

        if (A[WIDTH-1]^B[WIDTH-1])
            OUT = -OUT_t;
        else
            OUT = OUT_t;       

    end
endmodule
