// Copyright (C) 2019 Michael LeMay
// SPDX-License-Identifier: MIT

module pwm_cont(clk, val, ctrl);
    parameter VAL_SZ;
    input clk;
    input [VAL_SZ-1:0] val;
    output ctrl;

    reg [VAL_SZ-1:0] ctr;

    assign ctrl = ctr < val;

    initial begin
        ctr = 0;
    end

    always @(posedge clk) begin
        ctr <= ctr + 1;
    end
endmodule
