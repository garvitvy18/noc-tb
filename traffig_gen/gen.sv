
import nocpackage::*;

module gen
  (
   input logic clk,
   input logic rstn,
   input logic en
   );

   localparam XLEN = 4;
   localparam YLEN = 4;
   localparam TILES_NUM = XLEN * YLEN;
   localparam MAX_SND_COUNT = 4;

   const yx_vec tile_x[0:TILES_NUM - 1]
     = {
	3'b000,
	3'b001,
	3'b010,
	3'b011,
	3'b000,
	3'b001,
	3'b010,
	3'b011,
	3'b000,
	3'b001,
	3'b010,
	3'b011,
	3'b000,
	3'b001,
	3'b010,
	3'b011
	};

   const yx_vec tile_y[0:TILES_NUM - 1]
     = {
	3'b000,
	3'b000,
	3'b000,
	3'b000,
	3'b001,
	3'b001,
	3'b001,
	3'b001,
	3'b010,
	3'b010,
	3'b010,
	3'b010,
	3'b011,
	3'b011,
	3'b011,
	3'b011
	};

   logic [63:0] psr_state[0:TILES_NUM-1];
   logic [63:0] psr_state_next[0:TILES_NUM-1];
   logic [63:0] psr_next[0:TILES_NUM-1];
   logic [$clog2(TILES_NUM)-1:0] dst_next[0:TILES_NUM-1];
   logic [$clog2(MAX_SND_COUNT):0] snd_count[0:TILES_NUM-1];

   noc_flit_vector input_data[TILES_NUM-1:0];
   logic 	input_req[TILES_NUM-1:0];
   logic 	input_ack[TILES_NUM-1:0];
   noc_flit_vector output_data[TILES_NUM-1:0];
   logic 	output_req[TILES_NUM-1:0];
   logic 	output_ack[TILES_NUM-1:0];

   function noc_flit_type create_header
     (
      local_yx local_y,
      local_yx local_x,
      local_yx remote_y,
      local_yx remote_x,
      noc_msg_type msg_type,
      reserved_field_type reserved
      );

      noc_flit_type header;
      logic [next_routing_width-1:0] go_left, go_right, go_up, go_down;

      header = 0;
      header[noc_flit_size - 1 : noc_flit_size - preamble_width] = preamble_header;
      header[noc_flit_size - preamble_width - 1 : noc_flit_size - preamble_width - yx_width] = {2'b00, local_y};
      header[noc_flit_size - preamble_width - yx_width - 1 : noc_flit_size - preamble_width - 2*yx_width] = {2'b00, local_x};
      header[noc_flit_size - preamble_width - 2*yx_width - 1 : noc_flit_size - preamble_width - 3*yx_width] = {2'b00, remote_y};
      header[noc_flit_size - preamble_width - 3*yx_width - 1 : noc_flit_size - preamble_width - 4*yx_width] = {2'b00, remote_x};
      header[noc_flit_size - preamble_width - 4*yx_width - 1 : noc_flit_size - preamble_width - 4*yx_width - msg_type_width] = msg_type;
      header[noc_flit_size - preamble_width - 4*yx_width - msg_type_width - 1 : noc_flit_size - preamble_width - 4*yx_width - msg_type_width - reserved_width] = reserved;

      if (local_x < remote_x)
	go_right = 'b01000;
      else
	go_right = 'b10111;

      if (local_x > remote_x)
	go_left = 'b00100;
      else
	go_left = 'b11011;

      if (local_y < remote_y)
	header[next_routing_width - 1 : 0] = 'b01110 & go_left & go_right;
      else
	header[next_routing_width - 1 : 0] = 'b01101 & go_left & go_right;

      if ((local_y == remote_y) && (local_x == remote_x))
	header[next_routing_width - 1 : 0] = 'b1000;

      return header;
   endfunction

   genvar 	i;

   generate

      for (i = 0; i < TILES_NUM; i++) begin

	 // Pseudo-random-number generator state update
	 always_ff @(posedge clk) begin : xorshift64star_state;
	    if (rstn == 1'b0) begin
	       psr_state[i] <= (123 + i) * 64'hd109f4920f1102dd;
	    end
	    else begin
	       psr_state[i] <= psr_state_next[i];
	    end
	 end

	 // Pseudo-random-generator state compute (https://en.wikipedia.org/wiki/Xorshift)
	 always_comb begin : xorshift64star
	    logic [63:0] x;
	    psr_state_next[i] = psr_state[i];
	    x =  psr_state[i];
	    if (en == 1'b1) begin
	       x ^= x >> 12; // a
	       x ^= x << 25; // b
	       x ^= x >> 27; // c
	       psr_state_next[i] = x;
	    end
	 end // block: xorshift64star
	 assign psr_next[i] = psr_state_next[i] * 64'h2545F4914F6CDD1D;

	 always_comb begin
	    dst_next[i] = psr_next[i][$clog2(TILES_NUM)-1:0];
	    if (psr_next[i][$clog2(TILES_NUM)-1:0] == i)
	      dst_next[i] = i + 1;
	 end

	 // Send flit
	 always_ff @(posedge clk or negedge rstn) begin
	    if (rstn == 1'b0) begin
	       snd_count[i] <= 0;
	       input_data[i] <= 0;
	       input_req[i] <= 1'b0;
	    end
	    else begin
	       input_req[i] <= 1'b0; // No request by default

	       if (i == 0) begin // TODO: remove
		  if (en == 1'b1 && snd_count[i] < MAX_SND_COUNT) begin

		     // if (snd_count[i][0] == 1'b0) begin
		     // 	// Send header
			if (~input_req[i] || input_ack[i]) begin
			   snd_count[i] <= snd_count[i] + 1;
			   input_req[i] <= 1'b1;
			   input_data[i] <= 34'h300000000 |
					    create_header(tile_y[i],
							  tile_x[i],
							  tile_y[dst_next[i]],
							  tile_x[dst_next[i]],
							  interrupt,
							  'b0000);
			   $display("%t: Tile %d - Send %d", $time, i, dst_next[i]);
			end
		     // end
		     // else begin
		     // 	// Send tail
		     // 	if (~input_req[i] || input_ack[i]) begin
		     // 	   snd_count[i] <= snd_count[i] + 1;
		     // 	   input_req[i] <= 1'b1;
		     // 	   input_data[i][noc_flit_size-1:noc_flit_size-2] <= 2'b01;
		     // 	end
		     // end

		  end // if (en == 1'b1 && snd_count[i] < MAX_SND_COUNT)
	       end // if (i == 0)
	    end // else: !if(rstn == 1'b0)
	 end // always_ff @

	 // always accept incoming packets for now.
	 assign output_ack[i] = 1'b1;

	 always_ff @(posedge clk) begin
	    if (rstn != 1'b0) begin
	       if (output_req[i] == 1'b1) begin
		  $display("%t: Tile %d - Receiving data", $time, i);
	       end
	    end
	 end

      end // for (i = 0; i < TILES_NUM; i++)

   endgenerate


   sync_wrap #(.XLEN(XLEN), .YLEN(YLEN), .TILES_NUM(TILES_NUM), .flit_size(noc_flit_size)) dut
     (
      .clk(clk),
      .rstn(rstn),
      .input_data_i(input_data),
      .input_req_i(input_req),
      .input_ack_o(input_ack),
      .output_data_o(output_data),
      .output_req_o(output_req),
      .output_ack_i(output_ack)
      );

endmodule // gen
