
import nocpackage::*;

module gen
  (
   input logic 	clk,
   input logic 	rstn,

   output logic snd_complete,
   output logic rcv_complete,
   output logic test_error

   );

   // Injected flits per tile (power of 2 only)
   localparam MAX_SND_COUNT = 512;

   // Packet size in flits (power of 2 and >= MAX_SND_COUNT)
   localparam PKT_SIZE = 4;

   // NoC Size --> Begin
   localparam XLEN = 4;
   localparam YLEN = 4;
   localparam TILES_NUM = XLEN * YLEN;

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
   // NoC Size --> End

   // Helper function
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


   // Local registers and counters
   logic [63:0] psr_state[0:TILES_NUM-1];
   logic [63:0] psr_state_next[0:TILES_NUM-1];
   logic [63:0] psr_next[0:TILES_NUM-1];
   logic [$clog2(TILES_NUM)-1:0] dst_next[0:TILES_NUM-1];
   logic [$clog2(TILES_NUM)-1:0] dst_current[0:TILES_NUM-1];
   logic [$clog2(TILES_NUM)-1:0] src_next[0:TILES_NUM-1];
   logic [$clog2(TILES_NUM)-1:0] src_current[0:TILES_NUM-1];
   logic [31:0] snd_count[0:TILES_NUM-1];
   logic [0:TILES_NUM-1] snd_done;
   logic 	new_packet[0:TILES_NUM-1];
   logic 	new_flit[0:TILES_NUM-1];
   logic [0:TILES_NUM-1][31:0] total_snd[0:TILES_NUM-1]; // unpacked sender / packed receiver
   logic [0:TILES_NUM-1][31:0] total_rcv[0:TILES_NUM-1]; // unpacked receiver / packed sender
   logic [0:TILES_NUM-1][0:TILES_NUM-1] match_sndrcv;    // Both packed
   logic [0:TILES_NUM-1][0:TILES_NUM-1] mismatch_sndrcv;    // Both packed

   (* KEEP = "TRUE" *) logic [63:0] 			latency;

   logic				incr_snd_count[0:TILES_NUM-1];
   logic [0:TILES_NUM-1] 		incr_total_snd[0:TILES_NUM-1];
   logic 				sample_dst[0:TILES_NUM-1];

   noc_flit_vector input_data[TILES_NUM-1:0];
   logic 	input_req[TILES_NUM-1:0];
   logic 	input_ack[TILES_NUM-1:0];
   noc_flit_vector output_data[TILES_NUM-1:0];
   logic 	output_req[TILES_NUM-1:0];
   logic 	output_ack[TILES_NUM-1:0];

   logic 	en;

   genvar 	i, j;

   // Traffic Generator --> Begin

   // Enable traffic generation after reset
   always_ff @(posedge clk)
     if (rstn == 1'b0)
       en <= 1'b0;
     else
       en <= 1'b1;


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
	 always_comb begin
	    input_req[i] = 1'b0; // No request by default
	    input_data[i] = 0;
	    incr_snd_count[i] = 1'b0;
	    incr_total_snd[i] = '0;
	    sample_dst[i] = 1'b0;

	    if (en == 1'b1 && snd_count[i] < MAX_SND_COUNT) begin

	       if (PKT_SIZE == 1) begin
		  // Send single-flit packet
		  if (input_ack[i] == 1'b1) begin
		     incr_snd_count[i] = 1'b1;
		     incr_total_snd[i][dst_next[i]] = 1'b1;
		     sample_dst[i] = 1'b1;
		     input_req[i] = 1'b1;
		     input_data[i] = create_header(tile_y[i],
						   tile_x[i],
						   tile_y[dst_next[i]],
						   tile_x[dst_next[i]],
						   interrupt,
						   snd_count[i][reserved_width-1:0]);
		     input_data[i][noc_flit_size-1:noc_flit_size-2] = preamble_1flit;
		     $display("%t: Tile %d - Send %d", $time, i, dst_next[i]);
		  end // if (input_ack[i])
	       end // if (PKT_SIZE == 1)
	       else begin
		  if (| snd_count[i][$clog2(PKT_SIZE)-1:0] == 1'b0) begin
		     // Send header
		     if (input_ack[i] == 1'b1) begin
			incr_snd_count[i] = 1'b1;
			incr_total_snd[i][dst_next[i]] = 1'b1;
			sample_dst[i] = 1'b1;
			input_req[i] = 1'b1;
			input_data[i] = create_header(tile_y[i],
						      tile_x[i],
						      tile_y[dst_next[i]],
						      tile_x[dst_next[i]],
						      interrupt,
						      snd_count[i][reserved_width-1:0]);
			$display("%t: Tile %d - Send %d", $time, i, dst_next[i]);
 		     end // if (input_ack[i])
		  end // if (| snd_count[i][$clog2(PKT_SIZE)-1:0] == 1'b0)
		  else if (& snd_count[i][$clog2(PKT_SIZE)-1:0] == 1'b1) begin
		     // Send tail
		     if (input_ack[i] == 1'b1) begin
			incr_snd_count[i] = 1'b1;
			incr_total_snd[i][dst_current[i]] = 1'b1;
		     	input_req[i] = 1'b1;
		     	input_data[i][noc_flit_size-1:noc_flit_size-2] = preamble_tail;
		     	input_data[i][noc_flit_size-3:0] = snd_count[i];
		     end
		  end
		  else begin
		     // Send body
		     if (input_ack[i] == 1'b1) begin
			incr_snd_count[i] = 1'b1;
			incr_total_snd[i][dst_current[i]] = 1'b1;
		     	input_req[i] = 1'b1;
		     	input_data[i][noc_flit_size-1:noc_flit_size-2] = preamble_body;
		     	input_data[i][noc_flit_size-3:0] = snd_count[i];
		     end
		  end // else: !if(& snd_count[i][$clog2(PKT_SIZE)-1:0] == 1'b1)

	       end // else: !if(PKT_SIZE == 1)

	    end // if (en == 1'b1 && snd_count[i] < MAX_SND_COUNT)

	 end // always_comb

	 always_ff @(posedge clk or negedge rstn) begin
	    if (rstn == 1'b0) begin
	       snd_count[i] <= 0;
	       dst_current[i] <= 0;
	    end
	    else begin
	       if (sample_dst[i] == 1'b1) begin
		  dst_current[i] <= dst_next[i];
	       end
	       if (incr_snd_count[i] == 1'b1) begin
		 snd_count[i] <= snd_count[i] + 1;
	       end
	    end // else: !if(rstn == 1'b0)
	 end // always_ff @

	 for (j = 0; j < TILES_NUM; j++) begin
	    always_ff @(posedge clk or negedge rstn) begin
	       if (rstn == 1'b0) begin
		  total_snd[i][j] <= 0;
	       end
	       else begin
		  if (incr_total_snd[i][j] == 1'b1) begin
		     total_snd[i][j] = total_snd[i][j] + 1;
		  end
	       end
	    end
	 end

	 // always accept incoming packets for now.
	 assign output_ack[i] = 1'b1;
	 assign new_flit[i] = output_req[i] & output_ack[i];
	 assign new_packet[i] = output_data[i][noc_flit_size-1] & new_flit[i];
	 assign src_next[i] = output_data[i][29:27] * XLEN + output_data[i][24:22];

	 always_ff @(posedge clk) begin
	    if (rstn == 1'b0) begin
	       src_current[i] <= '0;
	       total_rcv[i] <= '0;
	    end
	    else begin
	       if (new_flit[i] == 1'b1) begin
		  if (new_packet[i] == 1'b1) begin
		     $display("%t: Tile %d - Receiving new packet", $time, i);
		     src_current[i] <= src_next[i];
		     total_rcv[i][src_next[i]] <= total_rcv[i][src_next[i]] + 1;
		  end
		  else begin
		     total_rcv[i][src_current[i]] <= total_rcv[i][src_current[i]] + 1;
		  end
	       end
	    end
	 end

      end // for (i = 0; i < TILES_NUM; i++)

   endgenerate
   // Traffic Generator --> End

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


   // Check
   assign snd_complete = & snd_done;
   assign rcv_complete = & match_sndrcv;
   assign test_error = | mismatch_sndrcv;

   generate
      for (i = 0; i < TILES_NUM; i++) begin

	 always_ff @(posedge clk) begin
	    if (rstn == 1'b0) begin
	       snd_done[i] <= 1'b0;
	    end
	    else begin
	    end
	    if (snd_count[i] == MAX_SND_COUNT) begin
	       snd_done[i] <= 1'b1;
	    end
	 end

	 for (j = 0; j < TILES_NUM; j++) begin

	    always_ff @(posedge clk) begin
	       if (rstn == 1'b0) begin
		  match_sndrcv[i][j] <= 1'b0;
		  mismatch_sndrcv[i][j] <= 1'b0;
	       end
	       else begin
		  if (snd_done[i] == 1'b1 && total_snd[i][j] == total_rcv[j][i]) begin
		     match_sndrcv[i][j] <= 1'b1;
		     mismatch_sndrcv[i][j] <= 1'b0;
		  end
		  if (snd_done[i] == 1'b1 && total_snd[i][j] != total_rcv[j][i]) begin
		     match_sndrcv[i][j] <= 1'b0;
		     mismatch_sndrcv[i][j] <= 1'b1;
		  end
	       end
	    end

	 end // for (j = 0; j < TILES_NUM; j++)

      end // for (i = 0; i < TILES_NUM; i++)

   endgenerate

   // Measure latency (try output this 
   always_ff @(posedge clk) begin
      if (rstn == 1'b0) begin
	 latency <= 0;
      end
      else begin
	 if (en == 1'b1 && rcv_complete == 1'b0) begin
	    latency <= latency + 1;
	 end
      end
   end

   always_comb begin
      if (rcv_complete == 1'b1)
	$display("Total latency is %d", latency);
   end

endmodule // gen
