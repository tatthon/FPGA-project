/*
 * Copyright (c) 2025 Matt Pongsagon Vichitvejpaisal
 * SPDX-License-Identifier: Apache-2.0

    - wrapper module to make asic_project work with FPGA board

 */
//`timescale 1ns / 1ps
//`default_nettype none

module top_FPGA (
    input wire [7:0] ui_in,
    output wire Hsync,
    output wire Vsync,
    output wire [3:0] vgaRed,
    output wire [3:0] vgaBlue,
    output wire [3:0] vgaGreen,
    inout wire [7:0] uio,       // to rom pmod, not use
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
    wire clk_25;

   // need to instantiate IP clk using Vivado
	clk_wiz_0 instance_name
   (
    // Clock out ports
    .clk_25(clk_25),     // output clk_25
    // Status and control signals
    //.reset(!rst_n), // input reset
   // Clock in ports
    .clk_100(clk));      // input clk_100

    wire ena;
    assign ena = 1;

    
    // uio to ROM pmod
    // - not use in this class
    wire [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    wire [7:0] uo_out;

    //assign uio = uio_oe ? uio_out : 1'bz; // To drive the inout net
    //assign uio_in = uio; // To read from inout net
    assign {uio[0],uio[3],uio[6],uio[7]} = {uio_out[0],uio_out[3],uio_out[6],uio_out[7]};
    assign uio[1] = uio_oe[1] ? uio_out[1] : 1'bz;
    assign uio[2] = uio_oe[2] ? uio_out[2] : 1'bz;
    assign uio[4] = uio_oe[4] ? uio_out[4] : 1'bz;
    assign uio[5] = uio_oe[5] ? uio_out[5] : 1'bz;
    assign {uio_in[5:4], uio_in[2:1]} = rst_n ? {uio[5:4], uio[2:1]} : 4'b0000;
    assign {uio_in[7:6], uio_in[3],uio_in[0]} = 4'b0000;

    // assign uo_out  = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
    // 00 -> 0000  convert 2-bit to 4-bit
    // 01 -> 0101
    // 10 -> 1010
    // 11 -> 1111
    assign Hsync = uo_out[7];
    assign Vsync = uo_out[3];
    assign vgaRed = {uo_out[0],uo_out[4],uo_out[0],uo_out[4]};
    assign vgaGreen = {uo_out[1],uo_out[5],uo_out[1],uo_out[5]};
    assign vgaBlue = {uo_out[2],uo_out[6],uo_out[2],uo_out[6]};


	tt_um_vga_example top (.ui_in(ui_in),.uo_out(uo_out),
					.uio_in(uio_in),.uio_out(uio_out),.uio_oe(uio_oe),
					.ena(ena),.clk(clk_25),.rst_n(rst_n));
	
endmodule










