module candy_dispenser_c10lp(clk_50m, led, servo, btn0);
// Copyright (C) 2019 Michael LeMay
// SPDX-License-Identifier: MIT


input clk_50m;
output led; // pin L14
output servo; // pin G2
input btn0; // pin E15

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
reg [10:0] servo_init_retracted = 1000;
reg [10:0] servo_init_extended = 2000;
reg [10:0] pwm_width_init = 0;
// counter to be decremented while sending the PWM pulse:
reg [10:0] pwm_width_ctr = 0;
// 14-bit counter incremented on 1MHz clock to implement a 16ms resend timer:
reg [11:0] pwm_resend_ctr = 0;
// 20-bit counter decremented on a 1MHz clock to implement a 1s travel-time counter:
reg [19:0] servo_travel_ctr = 0;
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

reg debounced_btn0 = 0;
reg [9:0] debounced_btn0_lvl = 0;

always @(posedge clk_1k) begin
    if (btn0 == 1 && debounced_btn0_lvl < 1000) begin
        debounced_btn0_lvl <= debounced_btn0_lvl + 1;
    end
    if (btn0 == 0 && 0 < debounced_btn0_lvl) begin
        debounced_btn0_lvl <= debounced_btn0_lvl - 1;
    end

    // The button is considered to be pressed if it has been pressed for 75%
    // of the preceding second:
    debounced_btn0 <= 750 < debounced_btn0_lvl;

    if (servo_travel_ctr == 0) begin
        // the previous servo travel command already completed.
        if (debounced_btn0 == 1) begin
            // the desired servo position is extended.
            if (pwm_width_init != servo_init_extended) begin
                // start the servo's travel to the extended position.
                pwm_width_init <= servo_init_extended;
                servo_travel_req <= 1;
            end
        end else begin
            // the desired servo position is retracted.
            if (pwm_width_init != servo_init_retracted) begin
                // start the servo's travel to the retracted position.
                pwm_width_init <= servo_init_retracted;
                servo_travel_req <= 1;
            end            
        end
    end else begin
        servo_travel_req <= 0;
    end
end

endmodule
