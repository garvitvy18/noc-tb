//------------------------------------------------------------------------------
// lookahead_routing_multicast.sv  (Ring NoC, multicast, assert-rich)
//------------------------------------------------------------------------------
// Expects noc_pkg.sv unchanged.
//------------------------------------------------------------------------------

module lookahead_routing_multicast #(
    parameter int DEST_SIZE = 6
) (
    input  logic                     clk,               // used for assertions only
    input  noc::xy_t                 position,          // ONLY .x used
    input  noc::xy_t [0:DEST_SIZE-1] destination,       // ONLY .x used
    input  logic        [DEST_SIZE-1:0] val,            // active destinations bitmap
    input  noc::direction_t          current_routing,   // go_west/go_east/go_local
    output noc::direction_t          next_routing       // one-hot result
);

    // Use x bit-width from the package (avoid struct scope resolution in $bits)
    typedef logic [noc::xWidth-1:0] x_t;

    //--------------------------------------------------------------------------
    // Next-hop indices in the ring for WEST/EAST (combinational)
    //--------------------------------------------------------------------------
    x_t next_west_x;
    x_t next_east_x;

    // WEST: (x - 1 + kRingSize) % kRingSize
    assign next_west_x = x_t'((position.x + noc::kRingSize - 1) % noc::kRingSize);
    // EAST: (x + 1) % kRingSize
    assign next_east_x = x_t'((position.x + 1) % noc::kRingSize);

    //--------------------------------------------------------------------------
    // Multicast fold
    //   any_match_w/e : Is there ANY active destination equal to next_west/east?
    //   any_val       : Is there ANY destination active at all?
    //--------------------------------------------------------------------------
    logic any_val, any_match_w, any_match_e, any_match;

    always_comb begin
        any_val     = |val;
        any_match_w = 1'b0;
        any_match_e = 1'b0;

        for (int i = 0; i < DEST_SIZE; i++) begin
            if (val[i]) begin
                if (destination[i].x == next_west_x) any_match_w = 1'b1;
                if (destination[i].x == next_east_x) any_match_e = 1'b1;
            end
        end

        unique case (1'b1)
            current_routing.go_west : any_match = any_match_w;
            current_routing.go_east : any_match = any_match_e;
            default                 : any_match = 1'b0; // local/idle
        endcase
    end

    //--------------------------------------------------------------------------
    // Final one-hot selection (no mixed local+dir encodings)
    //--------------------------------------------------------------------------
    always_comb begin
        if (any_match) begin
            next_routing = noc::goLocal;
        end else if (any_val) begin
            // Keep the selected forward direction exactly as-is
            next_routing = current_routing;
        end else begin
            // No destinations set: transparent
            next_routing = current_routing;
        end
    end

//------------------------------------------------------------------------------
// Assertions (simulation only)
//------------------------------------------------------------------------------
`ifndef SYNTHESIS
    // Small helpers for readability
    function automatic bit is_west (input noc::direction_t d); return d.go_west;  endfunction
    function automatic bit is_east (input noc::direction_t d); return d.go_east;  endfunction
    function automatic bit is_local(input noc::direction_t d); return d.go_local; endfunction

    // Position bounds
    property p_bounds_position; @(posedge clk) (position.x < noc::kRingSize); endproperty
    a_bounds_position: assert property (p_bounds_position)
      else $error("lookahead_routing_mc: position.x=%0d out of range [0..%0d]",
                  position.x, noc::kRingSize-1);

    // Destination bounds (for every active entry)
    for (genvar di = 0; di < DEST_SIZE; di++) begin : gen_bounds_dest
        property p_bounds_dest; @(posedge clk)
            (!val[di]) or (destination[di].x < noc::kRingSize);
        endproperty
        a_bounds_dest: assert property (p_bounds_dest)
          else $error("lookahead_routing_mc: destination[%0d].x=%0d out of range [0..%0d]",
                      di, destination[di].x, noc::kRingSize-1);
    end

    // Current routing must be legal and onehot0 across 3 bits
    property p_curr_dir_legal; @(posedge clk)
        (is_west(current_routing) or is_east(current_routing) or is_local(current_routing))
        and $onehot0(current_routing);
    endproperty
    a_curr_dir_legal: assert property (p_curr_dir_legal)
      else $error("lookahead_routing_mc: illegal current_routing=%b", current_routing);

    // Output must be onehot0 (never local+dir or west+east at once)
    property p_next_onehot; @(posedge clk) $onehot0(next_routing); endproperty
    a_next_onehot: assert property (p_next_onehot)
      else $error("lookahead_routing_mc: next_routing not onehot0 (got %b)", next_routing);

    // When there IS a match on the chosen forward next-hop, we must localize
    property p_local_when_match_w;
        @(posedge clk)
        ( is_west(current_routing) && any_val && any_match_w ) |-> is_local(next_routing);
    endproperty
    a_local_when_match_w: assert property (p_local_when_match_w)
      else begin
        automatic int first; first = -1;
        for (int i = 0; i < DEST_SIZE; i++)
            if (val[i] && destination[i].x == next_west_x) begin first = i; break; end
        $error("lookahead_routing_mc: expected goLocal on WEST match: pos_x=%0d nextW_x=%0d first_dest_idx=%0d dest_x=%0d next=%b",
               position.x, next_west_x, first, (first>=0)? destination[first].x : -1, next_routing);
      end

    property p_local_when_match_e;
        @(posedge clk)
        ( is_east(current_routing) && any_val && any_match_e ) |-> is_local(next_routing);
    endproperty
    a_local_when_match_e: assert property (p_local_when_match_e)
      else begin
        automatic int first; first = -1;
        for (int i = 0; i < DEST_SIZE; i++)
            if (val[i] && destination[i].x == next_east_x) begin first = i; break; end
        $error("lookahead_routing_mc: expected goLocal on EAST match: pos_x=%0d nextE_x=%0d first_dest_idx=%0d dest_x=%0d next=%b",
               position.x, next_east_x, first, (first>=0)? destination[first].x : -1, next_routing);
      end

    // If there are valid destinations but no next-hop match, keep the forward direction
    property p_keep_forward_w;
        @(posedge clk)
        ( is_west(current_routing) && any_val && !any_match_w ) |-> (next_routing == noc::goWest);
    endproperty
    a_keep_forward_w: assert property (p_keep_forward_w)
      else $error("lookahead_routing_mc: expected keep WEST (curr=%b) but next=%b",
                  current_routing, next_routing);

    property p_keep_forward_e;
        @(posedge clk)
        ( is_east(current_routing) && any_val && !any_match_e ) |-> (next_routing == noc::goEast);
    endproperty
    a_keep_forward_e: assert property (p_keep_forward_e)
      else $error("lookahead_routing_mc: expected keep EAST (curr=%b) but next=%b",
                  current_routing, next_routing);

    // No destinations: pass-through
    property p_passthrough_when_no_val; @(posedge clk)
        (!any_val) |-> (next_routing == current_routing);
    endproperty
    a_passthrough_when_no_val: assert property (p_passthrough_when_no_val)
      else $error("lookahead_routing_mc: no destinations, but next(%b) != current(%b)",
                  next_routing, current_routing);

    // Quick sanity
    initial begin
        if (noc::kRingSize <= 1) $fatal(1, "kRingSize must be > 1 for a ring.");
    end
`endif

endmodule

