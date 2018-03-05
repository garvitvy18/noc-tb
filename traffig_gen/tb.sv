
`timescale 1ns / 1ns

module tb ();

   localparam CLK_PERIOD = 10;

   logic clk;
   logic rstn;
   logic snd_complete;
   logic rcv_complete;
   logic test_error;

   initial begin
      clk = 1'b0;
      forever begin
	 #(CLK_PERIOD/2) clk = ~clk;
      end
   end

   initial begin
      rstn = 1'b0;
      #(10*CLK_PERIOD) rstn = 1'b1;
   end

   initial begin
      forever begin
	 # CLK_PERIOD ;
	 if (snd_complete == 1'b1) begin
	    $display("All flits have been sent");
	    break;
	 end
      end

      // Allow all packets to be delivered
      # (1024*CLK_PERIOD) ;

      if (rcv_complete == 1'b1) begin
	 $display("All flits have been received");
	 $stop;
      end

      if (test_error == 1'b1) begin
	 $display("Test error!");
	 $stop;
      end
   end

   gen traffic_gen (.clk(clk), .rstn(rstn),
		    .snd_complete(snd_complete),
		    .rcv_complete(rcv_complete),
		    .test_error(test_error));

endmodule
