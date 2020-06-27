// Copyright (C) 2019 Michael LeMay
// SPDX-License-Identifier: MIT

module candy_dispenser_c10lp(clk_50M, led_hb, led_pr, led_pr_cont, servo, sda, scl, din);
    input clk_50M;      // pin E1   - fixed 50MHz clock
    output led_hb;      // pin L14  - LED 0 - heartbeat
    output led_pr;      // pin K15  - LED 1 - lit when photoresistor brightly lit
    output led_pr_cont; // pin J14  - LED 2 - lit more brightly when photoresistor more brightly lit
    output servo;       // pin G2   - Arduino IO4 - PWM servo control
    inout sda;          // pin C8   - I2C SDA to/from MAX10
    output scl;         // pin D8   - I2C SCL to MAX10
    input din;          // pin B1   - Arduino IO0

    wire clk_1M;
    clk_div #(.DIV_FACTOR(50)) clk_div_1M_50M(clk_1M, clk_50M);

    wire clk_200k;
    clk_div #(.DIV_FACTOR(250)) clk_div_200k_1M(clk_200k, clk_50M);

    wire clk_100k;
    clk_div #(.DIV_FACTOR(2)) clk_div_100k_200k(clk_100k, clk_200k);

    wire clk_1k;
    clk_div #(.DIV_FACTOR(100)) clk_div_1k_200k(clk_1k, clk_100k);

    // blink LED at 1Hz as a heartbeat:
    clk_div #(.DIV_FACTOR(1000)) clk_div_1_1k(led_hb, clk_1k);

    // init values for generating servo PWM control with a unit of 1MHz terms:
    reg [10:0] servo_init_retracted = 1500;
    reg [10:0] servo_init_extended = 700;
    reg [10:0] pwm_width_init = 0;
    reg servo_travel_req = 0;
    wire servo_idle;

    // RESEND_CTR_SZ: 14-bit counter incremented on 1MHz clock to implement a 16ms resend timer.
    // DURATION_CTR_SZ: 18-bit counter decremented on a 1MHz clock to implement a 250ms travel-time counter.
    pwm_train #(.RESEND_CTR_SZ(14), .DURATION_CTR_SZ(18))
        servo_pwm(clk_1M, servo, servo_travel_req, servo_idle, pwm_width_init);

    reg adc_req;
    wire adc_done;
    wire [11:0] adc_val;
    reg [11:0] prev_adc_val;
    reg prev_clk_1k_lvl;

    const reg [7:0] ADC0_BASE_REG = 8'h30;
    //adc adc0(clk_100k, clk_200k, sda, scl, adc_req, adc_done, ADC0_BASE_REG, adc_val);

    always @(posedge clk_100k) begin
        if (adc_done) begin
            prev_adc_val <= adc_val;
        end

        if (!prev_clk_1k_lvl && clk_1k) begin
            // this is the first 100kHz posedge since the last posedge of the
            // 1kHz clock.  This issues a new ADC read request 1000 times per
            // second.
            adc_req <= 1;
        end else begin
            adc_req <= 0;
        end

        prev_clk_1k_lvl <= clk_1k;
    end

    integer adc_ptr = 0;

    always @(posedge led_hb) begin
        led_pr_cont <= prev_adc_val[adc_ptr];
        if (adc_ptr == 11) begin
            adc_ptr <= 0;
        end else begin
            adc_ptr <= adc_ptr + 1;
        end
    end

    //pwm_cont #(.VAL_SZ(12)) pwm_pr(clk_100k, prev_adc_val, led_pr_cont);

    // 1862 is the expected ADC value for 3V based on the formula on page 30
    // of the C10LP EVK user guide.
    //wire pr = 1862 < prev_adc_val;
    wire pr = din;

    assign led_pr = !pr;

    reg debounced_pr = 0;
    reg [9:0] debounced_pr_lvl = 0;
    // this is set when dispensing begins and remains set until
    // both dispensing is complete and the hand has been removed.
    reg hand_remaining = 0;

    always @(posedge clk_1k) begin
        if (!pr && debounced_pr_lvl < 1000) begin
            debounced_pr_lvl <= debounced_pr_lvl + 1;
        end
        if (pr && 0 < debounced_pr_lvl) begin
            debounced_pr_lvl <= debounced_pr_lvl - 1;
        end

        // The button is considered to be pressed if it has been pressed for 75%
        // of the preceding second:
        debounced_pr <= 750 < debounced_pr_lvl;

        if (servo_idle) begin
            if (pwm_width_init == servo_init_extended && hand_remaining) begin
                pwm_width_init <= servo_init_retracted;
                // start the servo's travel to the retracted position.
                servo_travel_req <= 1;
            end else begin
                if (!debounced_pr) begin
                    hand_remaining <= 0;
                end

                // the previous servo travel command already completed.
                if (debounced_pr && !hand_remaining) begin
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
