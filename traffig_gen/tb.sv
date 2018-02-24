
`timescale 1ns / 1ns

module tb ();

   localparam CLK_PERIOD = 10;

   logic clk;
   logic rstn;
   logic en;

   initial begin
      clk = 1'b0;
      forever begin
	 #(CLK_PERIOD/2) clk = ~clk;
      end
   end

   initial begin
      rstn = 1'b0;
      #(10*CLK_PERIOD) rstn = 1'b1;
      #CLK_PERIOD en = 1'b1;
      #(100*CLK_PERIOD) $stop;
   end

   gen traffic_gen (.clk(clk), .rstn(rstn), .en(en));

endmodule
