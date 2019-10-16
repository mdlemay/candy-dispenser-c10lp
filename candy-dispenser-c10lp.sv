// Copyright (C) 2019 Michael LeMay
// SPDX-License-Identifier: MIT

module candy_dispenser_c10lp(clk_50M, led, servo, pr0);

input clk_50M; // pin E1   - fixed 50MHz clock
output led;    // pin L14  - LED 0
output servo;  // pin G2   - Arduino IO4 - servo control
input pr0;     // pin F3   - Arduino IO2 - photoresistor

reg clk_1M = 0;
clk_div #(.DIV_FACTOR(50)) clk_div_1M_50M(clk_1M, clk_50M);

reg clk_100k = 0;
clk_div #(.DIV_FACTOR(10)) clk_div_100k_1M(clk_100k, clk_1M);

reg clk_1k = 0;
clk_div #(.DIV_FACTOR(100)) clk_div_1k_100k(clk_1k, clk_100k);

reg clk_1 = 0;
clk_div #(.DIV_FACTOR(1000)) clk_div_1_1k(clk_1, clk_1k);

// blink LED at 1Hz as a heartbeat:
assign led = clk_1;

// init values for generating servo PWM control with a unit of 1MHz terms:
reg [10:0] servo_init_retracted = 1500;
reg [10:0] servo_init_extended = 700;
reg [10:0] pwm_width_init = 0;
reg servo_travel_req = 0;
wire servo_idle;

// RESEND_CTR_SZ: 14-bit counter incremented on 1MHz clock to implement a 16ms resend timer.
// DURATION_CTR_SZ: 18-bit counter decremented on a 1MHz clock to implement a 250ms travel-time counter.
pwm #(.RESEND_CTR_SZ(14), .DURATION_CTR_SZ(18))
    servo_pwm(clk_1M, servo, servo_travel_req, servo_idle, pwm_width_init);

reg debounced_pr0 = 0;
reg [9:0] debounced_pr0_lvl = 0;
// this is set when dispensing begins and remains set until
// both dispensing is complete and the hand has been removed.
reg hand_remaining = 0;

always @(posedge clk_1k) begin
    if (!pr0 && debounced_pr0_lvl < 1000) begin
        debounced_pr0_lvl <= debounced_pr0_lvl + 1;
    end
    if (pr0 && 0 < debounced_pr0_lvl) begin
        debounced_pr0_lvl <= debounced_pr0_lvl - 1;
    end

    // The button is considered to be pressed if it has been pressed for 75%
    // of the preceding second:
    debounced_pr0 <= 750 < debounced_pr0_lvl;

    if (servo_idle) begin
        if (pwm_width_init == servo_init_extended && hand_remaining) begin
            pwm_width_init <= servo_init_retracted;
            // start the servo's travel to the retracted position.
            servo_travel_req <= 1;
        end else begin
            if (!debounced_pr0) begin
                hand_remaining <= 0;
            end

            // the previous servo travel command already completed.
            if (debounced_pr0 && !hand_remaining) begin
                // the desired servo position is extended.
                if (pwm_width_init != servo_init_extended) begin
                    // start the servo's travel to the extended position.
                    pwm_width_init <= servo_init_extended;
                    servo_travel_req <= 1;
                    hand_remaining <= 1;
                end
            end
        end
    end else begin
        servo_travel_req <= 0;
    end
end

endmodule
