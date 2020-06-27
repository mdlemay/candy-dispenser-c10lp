// Copyright (C) 2019 Michael LeMay
// SPDX-License-Identifier: MIT

// 100kHz I2C interface
module i2c(clk_100k, clk_200k, sda, scl, req, done, addr, dat_to_slv, dat_from_slv);
    localparam ADDR_LEN = 7;
    localparam DAT_LEN = 8;
    input clk_100k;
    input clk_200k;
    inout sda;
    output scl;
    input req;
    output done;
    input [ADDR_LEN-1:0] addr;
    input [DAT_LEN-1:0] dat_to_slv;
    output [DAT_LEN-1:0] dat_from_slv;

    typedef enum integer {
        IDLE, START, SHIFT_ADDR, SEND_DIR, ACK_ADDR, RX, TX, ACK_DAT, STOP0, STOP1, RESTART
    } Phase;

    Phase phase = IDLE;

    reg scl_on = 0;

    assign scl = !scl_on | clk_100k;

    integer shift_ctr;

    localparam READ_DIR = 1;
    localparam WRITE_DIR = 0;
    reg dir;

    initial begin
        done = 0;
        sda = 'bz;
        dir = WRITE_DIR;
    end

    always @(negedge clk_200k) begin
        Phase next_phase;
        next_phase = Phase'(phase + 1);
        if (clk_100k) begin
            case (phase)
            IDLE: begin
                done <= 0;
                if (!req) begin
                    next_phase = phase;
                end
                end
            START: begin
                sda <= 0;
                scl_on <= 1;
                shift_ctr <= ADDR_LEN-1;
                end
            RESTART: begin
                sda <= 1;
                next_phase = START;
                dir <= READ_DIR; // switch to reading register value after restart
                end
            STOP1: begin
                sda <= 'bz;
                scl_on <= 0;
                done <= 1;
                dir <= WRITE_DIR; // prepare for next request
                next_phase = IDLE;
                end
            default:
                next_phase = phase;
            endcase
        end else begin
            case (phase)
            SHIFT_ADDR: begin
                sda <= addr[shift_ctr];
                if (shift_ctr != 0) begin
                    shift_ctr <= shift_ctr - 1;
                    next_phase = phase;
                end
                end
            SEND_DIR:
                sda <= dir;
            ACK_ADDR: begin
                sda <= 'bz;
                if (dir == WRITE_DIR) begin
                    next_phase = TX;
                    shift_ctr <= DAT_LEN-1;
                end
                end
            RX: begin
                // FIXME: check for appropriate addr ack.
                dat_from_slv[shift_ctr] <= sda;
                if (shift_ctr == DAT_LEN-1) begin
                    next_phase = ACK_DAT;
                end else begin
                    shift_ctr <= shift_ctr + 1;
                    next_phase = phase;
                end
                end
            TX: begin
                // FIXME: check for appropriate addr ack.
                sda <= dat_to_slv[shift_ctr];
                if (shift_ctr != 0) begin
                    shift_ctr <= shift_ctr - 1;
                    next_phase = phase;
                end
                end
            ACK_DAT: begin
                sda <= 'bz;
                if (dir == WRITE_DIR) begin
                    next_phase = RESTART;
                end
                end
                // FIXME: check for appropriate data ack once back in IDLE.
            STOP0: begin
                sda <= 0;
                end
            default:
                next_phase = phase;
            endcase
        end

        phase <= next_phase;
    end
endmodule
