module mult2c #(parameter int WIDTH=32) (A, B, OUT);
    input  logic [WIDTH-1:0] A, B;
    output logic [WIDTH*2-1:0] OUT;

    // Keep the signed multiply visible to synthesis so it can use DSP blocks.
    // The 2*WIDTH destination retains the complete two's-complement product,
    // including the most-negative input; magnitude and sign correction are
    // unnecessary and would add negators and multiplexers around the DSPs.
    assign OUT = $signed(A) * $signed(B);
endmodule
