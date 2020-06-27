// Copyright (C) 2019 Michael LeMay
// SPDX-License-Identifier: MIT

// Generate a train of repeated pulse-width-modulated control signals
module pwm_train(clk_1M, pwm_ctrl, req, idle, width);
    input clk_1M;
    output pwm_ctrl;
    input req;
    output idle;
    input [10:0] width;

    // width of 1MHz counter for controlling how often to resend the pulse
    parameter RESEND_CTR_SZ = 0;
    // width of 1MHz counter for controlling how long to keep sending pulses
    parameter DURATION_CTR_SZ = 0;

    // counter to be decremented while sending the PWM pulse:
    reg [10:0] width_ctr = 0;
    reg [RESEND_CTR_SZ-1:0] resend_ctr = 0;
    reg [DURATION_CTR_SZ-1:0] duration_ctr = 0;

    assign idle = duration_ctr == 0;

    always @(posedge clk_1M) begin
        if (duration_ctr != 0 || req) begin
            duration_ctr <= duration_ctr - 1;
        end

        if (width_ctr == 0) begin
            pwm_ctrl <= 0;
            if (resend_ctr == 0 && duration_ctr != 0) begin
                width_ctr <= width;
            end
        end else begin
            pwm_ctrl <= 1;
            width_ctr <= width_ctr - 1;
        end
        resend_ctr <= resend_ctr + 1;
    end

endmodule