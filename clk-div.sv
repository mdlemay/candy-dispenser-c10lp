// Copyright (C) 2019 Michael LeMay
// SPDX-License-Identifier: MIT

module clk_div(clk_out, clk_in);
    output clk_out;
    input clk_in;

    parameter DIV_FACTOR = 1;

    integer ctr = 1;

    always @(posedge clk_in) begin
        if (ctr == DIV_FACTOR) begin
            clk_out <= ~clk_out;
            ctr <= 1;
        end else begin
            ctr <= ctr + 1;
        end
    end
endmodule
