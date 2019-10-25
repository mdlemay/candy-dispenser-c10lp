// Copyright (C) 2019 Michael LeMay
// SPDX-License-Identifier: MIT

// Driver for ADC implemented on MAX10 on C10LP EVK, reachable via I2C
module adc(clk_100k, clk_200k, sda, scl, req, done, base_reg, val);
    input clk_100k;
    input clk_200k;
    inout sda;
    output scl;
    input req;
    output done;
    input [7:0] base_reg;
    output [11:0] val;

    localparam I2C_READ_DIR = 1;
    localparam I2C_WRITE_DIR = 0;

    reg i2c_req, i2c_dir;
    wire i2c_done;
    // Set to 0 when accessing the base register and 1 when accessing the second register.
    wire i2c_phase;
    // constant from C10LP EVK user guide, page 30:
    const reg [6:0] i2c_addr = 7'h5E;
    wire [7:0] i2c_reg_addr = {base_reg[7:1],i2c_phase};
    wire [7:0] i2c_dat_from_slv;

    i2c i2c(clk_100k, clk_200k, sda, scl, i2c_req, i2c_dir, i2c_done,
            i2c_addr, i2c_reg_addr, i2c_dat_from_slv);

    typedef enum { RD_REG_IDLE, ADDR, DAT } RdRegPhase;

    RdRegPhase rd_reg_phase = RD_REG_IDLE;
    reg rd_reg_req = 0;

    always @(posedge clk_100k) begin
        case (rd_reg_phase)
        RD_REG_IDLE: begin
            if (rd_reg_req) begin
                rd_reg_phase <= ADDR;
                i2c_req <= 1;
                i2c_dir <= I2C_WRITE_DIR;
            end
        end
        ADDR: begin
            if (i2c_done) begin
                rd_reg_phase <= DAT;
                i2c_req <= 1;
                i2c_dir <= I2C_READ_DIR;
            end else begin
                i2c_req <= 0;
            end
        end
        DAT: begin
            if (i2c_done) begin
                rd_reg_phase <= RD_REG_IDLE;
            end else begin
                i2c_req <= 0;
            end
        end
        endcase
    end

    typedef enum { ACCUM_IDLE, REG0, REG1 } AccumPhase;

    AccumPhase accum_phase = ACCUM_IDLE;

    assign i2c_phase = accum_phase == REG1;

    always @(posedge clk_100k) begin
        case (accum_phase)
        ACCUM_IDLE: begin
            if (req) begin
                rd_reg_req <= 1;
                accum_phase <= REG0;
            end
            done <= 0;
            end
        REG0: begin
            rd_reg_req <= 0;
            if (rd_reg_phase == RD_REG_IDLE) begin
                val[7:0] <= i2c_dat_from_slv;
                rd_reg_req <= 1;
                accum_phase <= REG1;
            end
            end
        REG1: begin
            rd_reg_req <= 0;
            if (rd_reg_phase == RD_REG_IDLE) begin
                val[11:8] <= i2c_dat_from_slv[3:0];
                done <= 1;
                accum_phase <= ACCUM_IDLE;
            end
            end
        endcase
    end
endmodule
