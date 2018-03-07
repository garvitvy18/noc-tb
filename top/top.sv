`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 03/05/2018 05:28:02 PM
// Design Name:
// Module Name: top
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module top
  (
   input 	sys_clk_p,
   input 	sys_clk_n,
   input 	reset,
   output 	led_snd_complete,
   output 	led_rcv_complete,
   output 	led_test_error,
   input logic 	uart_rx,
   output logic uart_tx,
   output logic uart_err
   );

   logic 	clk;
   logic 	rstn;
   logic [15:0] reset_cnt;

   IBUFGDS sys_clk_buf
     (
      .I(sys_clk_p),
      .IB(sys_clk_n),
      .O(clk)
      );

   always_ff @(posedge clk or posedge reset) begin
      if (reset == 1'b1) begin
         reset_cnt <= 0;
         rstn <= 1'b0;
      end
      else begin
         if (reset_cnt[15] == 1'b0)
           reset_cnt <= reset_cnt + 1;
         else
           rstn <= 1'b1;
      end
   end

   gen dut
     (
      .clk(clk),
      .rstn(rstn),
      .snd_complete_o(led_snd_complete),
      .rcv_complete_o(led_rcv_complete),
      .test_error(led_test_error),
      .uart_rx(uart_rx),
      .uart_tx(uart_tx),
      .uart_err(uart_err)
      );

endmodule
