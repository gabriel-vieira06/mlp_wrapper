`timescale 1ns / 1ps

module mult2c_tb;
    logic [7:0] a8, b8;
    logic [15:0] product8;
    logic [31:0] a32, b32;
    logic [63:0] product32;
    logic [31:0] boundary [0:7];
    longint signed expected;
    int checked8 = 0;
    int checked32 = 0;

    mult2c #(.WIDTH(8)) small_dut(a8, b8, product8);
    mult2c #(.WIDTH(32)) full_dut(a32, b32, product32);

    task automatic check32(input logic [31:0] a, b);
        a32 = a;
        b32 = b;
        // Explicitly sign-extend both operands before using the reference
        // multiply, independent of expression width propagation in the DUT.
        expected = longint'($signed(a)) * longint'($signed(b));
        #1;
        if (product32 !== expected)
            $fatal(1, "32-bit multiply: %h * %h = %h, expected %h",
                   a, b, product32, expected);
        checked32++;
    endtask

    initial begin
        boundary[0] = 32'h00000000;
        boundary[1] = 32'h00000001;
        boundary[2] = 32'hffffffff;
        boundary[3] = 32'h7fffffff;
        boundary[4] = 32'h80000000;
        boundary[5] = 32'h80000001;
        boundary[6] = 32'h00010000;
        boundary[7] = 32'hffff0000;

        for (int a = -128; a <= 127; a++) begin
            for (int b = -128; b <= 127; b++) begin
                a8 = 8'(a);
                b8 = 8'(b);
                expected = a * b;
                #1;
                if (longint'($signed(product8)) !== expected)
                    $fatal(1, "8-bit multiply: %0d * %0d = %0d, expected %0d",
                           a, b, $signed(product8), expected);
                checked8++;
            end
        end

        foreach (boundary[a]) begin
            foreach (boundary[b]) check32(boundary[a], boundary[b]);
        end
        repeat (20000) check32($urandom, $urandom);

        $display("PASS: %0d exhaustive 8-bit and %0d boundary/random 32-bit products",
                 checked8, checked32);
        $finish;
    end
endmodule
