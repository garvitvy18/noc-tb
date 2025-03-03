
module gen
  (
   input logic 	clk,
   input logic 	rstn,

   output logic snd_complete_o,
   output logic rcv_complete_o,
   output logic test_error,

   input logic uart_rx,
   output logic uart_tx,
   output logic uart_err
   );

   // Injected flits per tile (power of 2 only)
   localparam MAX_SND_COUNT = 512;

   // Packet size in flits (power of 2 and >= MAX_SND_COUNT)
   localparam PKT_SIZE = 4;

   // NoC Parameters
   localparam PREAMBLE_WIDTH = 2;
   const logic [1:0] preamble_header = 2'b10;
   const logic [1:0] preamble_body = 2'b00;
   const logic [1:0] preamble_tail = 2'b01;
   const logic [1:0] preamble_1flit = 2'b10;

   localparam YX_WIDTH = 3;
   typedef logic [2:0] local_yx;

   localparam MSG_TYPE_WIDTH = 3;
   typedef logic [MSG_TYPE_WIDTH-1:0] noc_msg_type;

   localparam RESERVED_WIDTH = 3;
   typedef logic [RESERVED_WIDTH-1:0] reserved_field_type;

   localparam NOC_FLIT_SIZE = 66;
   typedef logic [NOC_FLIT_SIZE-1:0] noc_flit_type;

   localparam NEXT_ROUTING_WIDTH = 3;

   // NoC Size --> Begin
   localparam XLEN = 4;
   localparam YLEN = 0;
   localparam TILES_NUM = XLEN;

   const local_yx tile_x[0:TILES_NUM - 1]
     = {
	3'b000,
	3'b001, 
	3'b010,
	3'b011 //,
//	3'b000,
//	3'b001 ,
//	 3'b010,
//	 3'b011,
//	 3'b000,
//	 3'b001,
//	 3'b010,
//	 3'b011,
//	 3'b000,
//	 3'b001,
//	 3'b010,
//	 3'b011
	};
   const local_yx tile_y[0:TILES_NUM - 1] = { 3'b000, 3'b000, 3'b000, 3'b000 };
   /*const local_yx tile_y[0:TILES_NUM - 1]
     = {
	3'b000,
	3'b000,
	 3'b000,
	 3'b000,
	3'b001,
	3'b001 ,
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
	}; */
   // NoC Size --> End

   // Helper function
   function noc_flit_type create_header
     (
//      local_yx local_y,
      local_yx local_x,
//      local_yx remote_y,
      local_yx remote_x,
      noc_msg_type msg_type,
      reserved_field_type reserved
      );

      noc_flit_type header;
      logic [NEXT_ROUTING_WIDTH-1:0] go_left, go_right; // go_up, go_down;
      //logic [YX_WIDTH-1:0] dist_cw, dist_ccw;
      header = 0;
      header[NOC_FLIT_SIZE - 1 : NOC_FLIT_SIZE - PREAMBLE_WIDTH] = preamble_header;
//      header[NOC_FLIT_SIZE - PREAMBLE_WIDTH - 1 : NOC_FLIT_SIZE - PREAMBLE_WIDTH - YX_WIDTH] =  local_y;
      header[NOC_FLIT_SIZE - PREAMBLE_WIDTH - 1 : NOC_FLIT_SIZE - PREAMBLE_WIDTH - YX_WIDTH] = local_x;
//      header[NOC_FLIT_SIZE - PREAMBLE_WIDTH - 2*YX_WIDTH - 1 : NOC_FLIT_SIZE - PREAMBLE_WIDTH - 3*YX_WIDTH] = remote_y;
      header[NOC_FLIT_SIZE - PREAMBLE_WIDTH - YX_WIDTH - 1 : NOC_FLIT_SIZE - PREAMBLE_WIDTH - 2*YX_WIDTH] = remote_x;
      header[NOC_FLIT_SIZE - PREAMBLE_WIDTH - 2*YX_WIDTH - 1 : NOC_FLIT_SIZE - PREAMBLE_WIDTH - 2*YX_WIDTH - MSG_TYPE_WIDTH] = msg_type;
      header[NOC_FLIT_SIZE - PREAMBLE_WIDTH - 2*YX_WIDTH - MSG_TYPE_WIDTH - 1 : NOC_FLIT_SIZE - PREAMBLE_WIDTH - 2*YX_WIDTH - MSG_TYPE_WIDTH - RESERVED_WIDTH] = reserved;

    // Determine direction based on local_x and remote_x
    if (local_x < remote_x || (local_x == XLEN-1 && remote_x == 0))
        go_right = 3'b010; // Move East (1)
    else
        go_right = 3'b101; // No move in this direction

    if (local_x > remote_x || (local_x == 0 && remote_x == XLEN-1))
        go_left = 3'b001;  // Move West (0)
    else
        go_left = 3'b110;  // No move in this direction

    // Compute shortest path in a Ring (Clockwise vs Counterclockwise)
   // logic [YX_WIDTH-1:0] dist_cw, dist_ccw;

    //dist_cw  = (remote_x >= local_x) ? (remote_x - local_x) : (XLEN + remote_x - local_x);
    //dist_ccw = (local_x >= remote_x) ? (local_x - remote_x) : (local_x + XLEN - remote_x);
	header[NEXT_ROUTING_WIDTH - 1 : 0] = 3'b011 & go_left & go_right;
    // Select routing direction (Ring-based decision with wrap-around)
    if (local_x == remote_x) begin
        header[NEXT_ROUTING_WIDTH - 1 : 0] = 3'b100; // Enable (2)
	end
    // end else if (dist_cw <= dist_ccw) begin
    //     header[2:0] = 3'b010 & go_right; // Move East (1) or Wrap-around to 0
    // end else begin
    //     header[2:0] = 3'b001 & go_left;  // Move West (0) or Wrap-around to last tile
    // end


      return header;
   endfunction


   // Local registers and counters
   logic 			     soft_reset;
   logic [12:0] 		     wdog;
   logic [3:0] 			     debug_state;
   logic [3:0] 			     debug_next;
   logic 			     csr_we;
   logic [7:0] 			     csr_di;
   logic [7:0] 			     csr_do;
   logic 			     rx_irq;
   logic 			     uart_busy;

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

   logic 				snd_complete;
   logic 				snd_complete_reg;
   logic 				rcv_complete;
   logic 				rcv_complete_reg;

   (* KEEP = "TRUE" *) logic [31:0] 			latency;

   logic				incr_snd_count[0:TILES_NUM-1];
   logic [0:TILES_NUM-1] 		incr_total_snd[0:TILES_NUM-1];
   logic 				sample_dst[0:TILES_NUM-1];

   noc_flit_type input_data[TILES_NUM-1:0];
   logic [TILES_NUM-1:0] input_req;
   logic [TILES_NUM-1:0] input_ack;
   noc_flit_type output_data[TILES_NUM-1:0];
   logic [TILES_NUM-1:0] output_req;
   logic [TILES_NUM-1:0] output_ack;

   logic [TILES_NUM * NOC_FLIT_SIZE - 1:0] input_data_packed;
   logic [TILES_NUM * NOC_FLIT_SIZE - 1:0] output_data_packed;

   logic 	en;

   genvar 	i, j;

   // Traffic Generator --> Begin

   // Enable traffic generation after reset
   always_ff @(posedge clk)
     if (rstn == 1'b0 || soft_reset == 1'b1)
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

	    if (en == 1'b1 && snd_count[i] < MAX_SND_COUNT && rcv_complete_reg == 1'b0) begin

	       if (PKT_SIZE == 1) begin
		  // Send single-flit packet
		  if (input_ack[i] == 1'b1) begin
		     incr_snd_count[i] = 1'b1;
		     incr_total_snd[i][dst_next[i]] = 1'b1;
		     sample_dst[i] = 1'b1;
		     input_req[i] = 1'b1;
		     input_data[i] = create_header(//tile_y[i],
						   tile_x[i],
						   //tile_y[dst_next[i]],
						   tile_x[dst_next[i]],
						   3'b111,
						   snd_count[i][RESERVED_WIDTH-1:0]);
		     input_data[i][NOC_FLIT_SIZE-1:NOC_FLIT_SIZE-2] = preamble_1flit;
		     //$display("%t: Tile %d - Send %d", $time, i, dst_next[i]);
			 $display("%t: Tile %d - Send %d | input_req_single [%d] = %d", $time, i, dst_next[i], i, input_req[i]);
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
			input_data[i] = create_header(//tile_y[i],
						      tile_x[i],
						      //tile_y[dst_next[i]],
						      tile_x[dst_next[i]],
						      3'b111,
						      snd_count[i][RESERVED_WIDTH-1:0]);
			// $display("%t: Tile %d - Send %d", $time, i, dst_next[i]);
			$display("%t: Tile %d - Send %d | input_req_head [%d] = %d", $time, i, dst_next[i], i, input_req[i]);
 		     end // if (input_ack[i])
		  end // if (| snd_count[i][$clog2(PKT_SIZE)-1:0] == 1'b0)
		  else if (& snd_count[i][$clog2(PKT_SIZE)-1:0] == 1'b1) begin
		     // Send tail
		     if (input_ack[i] == 1'b1) begin
			incr_snd_count[i] = 1'b1;
			incr_total_snd[i][dst_current[i]] = 1'b1;
		     	input_req[i] = 1'b1;
		     	input_data[i][NOC_FLIT_SIZE-1:NOC_FLIT_SIZE-2] = preamble_tail;
		     	input_data[i][NOC_FLIT_SIZE-3:0] = snd_count[i];
			$display("%t: Tile %d | input_req_tail [%d] = %d", $time, i, i, input_req[i]);
		     end
		  end
		  else begin
		     // Send body
		     if (input_ack[i] == 1'b1) begin
			incr_snd_count[i] = 1'b1;
			incr_total_snd[i][dst_current[i]] = 1'b1;
		     	input_req[i] = 1'b1;
		     	input_data[i][NOC_FLIT_SIZE-1:NOC_FLIT_SIZE-2] = preamble_body;
		     	input_data[i][NOC_FLIT_SIZE-3:0] = snd_count[i];
			$display("%t: Tile %d | input_req_body [%d] = %d", $time, i, i, input_req[i]);
		     end
		  end // else: !if(& snd_count[i][$clog2(PKT_SIZE)-1:0] == 1'b1)

	       end // else: !if(PKT_SIZE == 1)

	    end // if (en == 1'b1 && snd_complete_reg == 1'b0)

	 end // always_comb

	 always_ff @(posedge clk or negedge rstn) begin
	    if (rstn == 1'b0 || soft_reset == 1'b1) begin
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
	       if (rstn == 1'b0 || soft_reset == 1'b1) begin
		  total_snd[i][j] <= 0;
	       end
	       else begin
		  if (incr_total_snd[i][j] == 1'b1) begin
		     total_snd[i][j] <= total_snd[i][j] + 1;
		  end
	       end
	    end
	 end

	 // always accept incoming packets for now.
	 assign output_ack[i] = 1'b1;
	 assign new_flit[i] = output_req[i] & output_ack[i];
	 assign new_packet[i] = output_data[i][NOC_FLIT_SIZE-1] & new_flit[i];
	// assign src_next[i] = output_data[i][NOC_FLIT_SIZE - PREAMBLE_WIDTH - 1:NOC_FLIT_SIZE - PREAMBLE_WIDTH - YX_WIDTH] * XLEN +
	assign src_next[i] =  output_data[i][NOC_FLIT_SIZE - PREAMBLE_WIDTH - 1 : NOC_FLIT_SIZE - PREAMBLE_WIDTH - YX_WIDTH];
	 always_ff @(posedge clk) begin
	    if (rstn == 1'b0 || soft_reset == 1'b1) begin
	       src_current[i] <= '0;
	       total_rcv[i] <= '0;
	    end
	    else begin
			$display("%t: Before new flit | output_req[%d] = %d, output_ack[%d] = %d", $time, i, output_req[i], i, output_ack[i]);
	       if (new_flit[i] == 1'b1) begin
			$display("%t: New flit", $time);
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

	 assign input_data_packed[(i + 1) * NOC_FLIT_SIZE - 1 : NOC_FLIT_SIZE * i] = input_data[i];
	 assign output_data[i] = output_data_packed[(i + 1) * NOC_FLIT_SIZE - 1 : NOC_FLIT_SIZE * i];

      end // for (i = 0; i < TILES_NUM; i++)

   endgenerate
   // Traffic Generator --> End

   sync_wrap #(.XLEN(XLEN), .YLEN(YLEN), .TILES_NUM(TILES_NUM), .flit_size(NOC_FLIT_SIZE)) dut
     (
      .clk(clk),
      .rstn(rstn),
      .input_data_i(input_data_packed),
      .input_req_i(input_req),
      .input_ack_o(input_ack),
      .output_data_o(output_data_packed),
      .output_req_o(output_req),
      .output_ack_i(output_ack)
      );


   // Check
   assign snd_complete = & snd_done;
   assign rcv_complete = & match_sndrcv;
   assign test_error = (| mismatch_sndrcv) & wdog[12];

   always_ff @(posedge clk) begin
      if (rstn == 1'b0 || soft_reset == 1'b1) begin
	 wdog <= 0;
	 snd_complete_reg <= 1'b0;
	 rcv_complete_reg <= 1'b0;
      end
      else begin
	 if (snd_complete & wdog[12])
	   wdog <= wdog + 1;
	 if (snd_complete)
	   snd_complete_reg <= 1'b1;
	 if (rcv_complete)
	   rcv_complete_reg <= 1'b1;
      end
   end // always_ff @

   assign snd_complete_o = snd_complete_reg;
   assign rcv_complete_o = rcv_complete_reg;

   generate
      for (i = 0; i < TILES_NUM; i++) begin

	 always_ff @(posedge clk) begin
	    if (rstn == 1'b0 || soft_reset == 1'b1) begin
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
	       if (rstn == 1'b0 || soft_reset == 1'b1) begin
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
      if (rstn == 1'b0 || soft_reset == 1'b1) begin
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

   // Send output through simple UART interface
   function [7:0] hex2ascii (logic [3:0] hex);
      logic [7:0] ascii;
      case (hex)
	4'b0000 : ascii = 48;
	4'b0001 : ascii = 49;
	4'b0010 : ascii = 50;
	4'b0011 : ascii = 51;
	4'b0100 : ascii = 52;
	4'b0101 : ascii = 53;
	4'b0110 : ascii = 54;
	4'b0111 : ascii = 55;
	4'b1000 : ascii = 56;
	4'b1001 : ascii = 57;
	4'b1010 : ascii = 65;
	4'b1011 : ascii = 66;
	4'b1100 : ascii = 67;
	4'b1101 : ascii = 68;
	4'b1110 : ascii = 69;
	4'b1111 : ascii = 70;
      endcase // case (hex)
      return ascii;
   endfunction

   always_ff @(posedge clk) begin
      if (rstn == 1'b0)
	debug_state <= 0;
      else
	debug_state <= debug_next;
   end

   always_comb  begin
      soft_reset = 1'b0;
      csr_we = 1'b0;
      csr_di = 0;
      debug_next = debug_state;

      case (debug_state)
	4'h0 :
	  begin
	     if (test_error == 1'b1) begin // ERR (E)
		csr_we = 1'b1;
		csr_di = 8'd69;
		debug_next = 4'h1;
	     end
	     else if (rcv_complete == 1'b1) begin // 0
		csr_we = 1'b1;
		csr_di = 8'd48;
		debug_next = 4'h6;
	     end
	  end
	4'h6 : // x
	  begin
	     if (~uart_busy) begin
		csr_we = 1'b1;
		csr_di = 8'd120;
		debug_next = 4'h7;
	     end
	  end
	4'h7 : // latency[31:28]
	  begin
	     if (~uart_busy) begin
		csr_we = 1'b1;
		csr_di = hex2ascii(latency[31:28]);
		debug_next = 4'h8;
	     end
	  end
	4'h8 : // latency[27:24]
	  begin
	     if (~uart_busy) begin
		csr_we = 1'b1;
		csr_di = hex2ascii(latency[27:24]);
		debug_next = 4'h9;
	     end
	  end
	4'h9 : // latency[23:20]
	  begin
	     if (~uart_busy) begin
		csr_we = 1'b1;
		csr_di = hex2ascii(latency[23:20]);
		debug_next = 4'hA;
	     end
	  end
	4'hA : // latency[19:16]
	  begin
	     if (~uart_busy) begin
		csr_we = 1'b1;
		csr_di = hex2ascii(latency[19:16]);
		debug_next = 4'hB;
	     end
	  end
	4'hB : // latency[15:12]
	  begin
	     if (~uart_busy) begin
		csr_we = 1'b1;
		csr_di = hex2ascii(latency[15:12]);
		debug_next = 4'hC;
	     end
	  end
	4'hC : // latency[11:8]
	  begin
	     if (~uart_busy) begin
		csr_we = 1'b1;
		csr_di = hex2ascii(latency[11:8]);
		debug_next = 4'hD;
	     end
	  end
	4'hD : // latency[7:4]
	  begin
	     if (~uart_busy) begin
		csr_we = 1'b1;
		csr_di = hex2ascii(latency[7:4]);
		debug_next = 4'hE;
	     end
	  end
	4'hE : // latency[3:0]
	  begin
	     if (~uart_busy) begin
		csr_we = 1'b1;
		csr_di = hex2ascii(latency[3:0]);
		debug_next = 4'h3;
	     end
	  end
	4'h1 : // ERR (R)
	  begin
	     if (~uart_busy) begin
		csr_we = 1'b1;
		csr_di = 8'd82;
		debug_next = 4'h2;
	     end
	  end
	4'h2 : // ERR (R)
	  begin
	     if (~uart_busy) begin
		csr_we = 1'b1;
		csr_di = 8'd82;
		debug_next = 4'h3;
	     end
	  end
	4'h3 : // Carriage Return
	  begin
	     if (~uart_busy) begin
		csr_we = 1'b1;
		csr_di = 8'd13;
		debug_next = 4'h4;
	     end
	  end
	4'h4 : // New Line
	  begin
	     if (~uart_busy) begin
		csr_di = 8'd10;
		csr_we = 1'b1;
		debug_next = 4'h5;
	     end
	  end
	4'h5 : // Wait for Soft reset (any char)
	  begin
	     if (rx_irq) begin
		soft_reset = 1'b1;
		debug_next = 4'hf;
	     end
	  end
	4'hF : // Wait for Soft reset (any char)
	  begin
	     soft_reset = 1'b1;
	     if (snd_complete_reg | snd_complete == 1'b0) begin
		debug_next = 4'h0;
	     end
	  end
      endcase
   end // always_comb

   uart debug_uart
     (
      .clk(clk),
      .rst(~rstn),
      .rx(uart_rx),
      .tx(uart_tx),
      .transmit(csr_we),
      .tx_byte(csr_di),
      .received(rx_irq),
      .rx_byte(csr_do),
      .is_receiving(),
      .is_transmitting(uart_busy),
      .recv_error(uart_err)
      );


endmodule // gen
