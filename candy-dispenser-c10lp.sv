// Copyright (C) 2019 Michael LeMay
// SPDX-License-Identifier: MIT

module candy_dispenser_c10lp(clk_50m, led, servo, pr0);

input clk_50m; // pin E1   - fixed 50MHz clock
output led;    // pin L14  - LED 0
output servo;  // pin G2   - Arduino IO4 - servo control
input pr0;     // pin F3   - Arduino IO2 - photoresistor

// divide 50MHz clock to 1MHz:
reg clk_1m = 0;
reg [5:0] clk_1m_ctr = 0;

always @(posedge clk_50m) begin
    if (clk_1m_ctr == 50) begin
        clk_1m <= ~clk_1m;
        clk_1m_ctr <= 0;
    end else begin
        clk_1m_ctr <= clk_1m_ctr + 1;
    end
end

// divide 1MHz clock to 1kHz:
reg [9:0] clk_1k_ctr = 0;
reg clk_1k = 0;

always @(posedge clk_1m) begin
    if (clk_1k_ctr == 0) begin
        clk_1k <= ~clk_1k;
    end
    clk_1k_ctr <= clk_1k_ctr + 1;
end

// divide 1kHz clock to 1Hz:
reg [9:0] clk_1_ctr = 0;
reg clk_1 = 0;

always @(posedge clk_1k) begin
    if (clk_1_ctr == 0) begin
        clk_1 <= ~clk_1;
    end
    clk_1_ctr <= clk_1_ctr + 1;
end

// blink LED at 1Hz:
assign led = clk_1;

// init values for generating servo PWM control with a unit of 1MHz terms:
reg [10:0] servo_init_retracted = 1500;
reg [10:0] servo_init_extended = 700;
reg [10:0] pwm_width_init = 0;
// counter to be decremented while sending the PWM pulse:
reg [10:0] pwm_width_ctr = 0;
// 14-bit counter incremented on 1MHz clock to implement a 16ms resend timer:
reg [13:0] pwm_resend_ctr = 0;
// 18-bit counter decremented on a 1MHz clock to implement a 250ms travel-time counter:
reg [17:0] servo_travel_ctr = 0;
reg servo_travel_req = 0;

always @(posedge clk_1m) begin
    if (servo_travel_ctr != 0 || servo_travel_req == 1) begin
        servo_travel_ctr <= servo_travel_ctr - 1;
    end

    if (pwm_width_ctr == 0) begin
        servo <= 0;
        if (pwm_resend_ctr == 0 && servo_travel_ctr != 0) begin
            pwm_width_ctr <= pwm_width_init;
        end
    end else begin
        servo <= 1;
        pwm_width_ctr <= pwm_width_ctr - 1;
    end
    pwm_resend_ctr <= pwm_resend_ctr + 1;
end

reg debounced_pr0 = 0;
reg [9:0] debounced_pr0_lvl = 0;
// this is set when dispensing begins and remains set until
// both dispensing is complete and the hand has been removed.
reg hand_remaining = 0;

always @(posedge clk_1k) begin
    if (pr0 == 0 && debounced_pr0_lvl < 1000) begin
        debounced_pr0_lvl <= debounced_pr0_lvl + 1;
    end
    if (pr0 == 1 && 0 < debounced_pr0_lvl) begin
        debounced_pr0_lvl <= debounced_pr0_lvl - 1;
    end

    // The button is considered to be pressed if it has been pressed for 75%
    // of the preceding second:
    debounced_pr0 <= 750 < debounced_pr0_lvl;

    if (servo_travel_ctr == 0) begin
        if (pwm_width_init == servo_init_extended && hand_remaining == 1) begin
            pwm_width_init <= servo_init_retracted;
            // start the servo's travel to the retracted position.
            servo_travel_req <= 1;
        end else begin
            if (debounced_pr0 == 0) begin
                hand_remaining <= 0;
            end

            // the previous servo travel command already completed.
            if (debounced_pr0 == 1 && hand_remaining == 0) begin
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
