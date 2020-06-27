// Copyright (C) 2019 Michael LeMay
// SPDX-License-Identifier: MIT

// Divide a clock by a specified factor.
// Only even factors are precisely supported.
module clk_div(clk_out, clk_in);
    output clk_out;
    input clk_in;

    parameter DIV_FACTOR = 1;

    integer ctr = 1;

    initial begin
        clk_out = 0;
    end

    always @(posedge clk_in) begin
        // halve factor to account for the fact that triggering only occurs on
        // posedge of input clock:
        if (ctr == DIV_FACTOR/2) begin
            clk_out <= ~clk_out;
            ctr <= 1;
        end else begin
            ctr <= ctr + 1;
        end
    end
endmodule
