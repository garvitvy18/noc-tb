// Compute next YX positional routing for a 3D mesh NoC
//
// This module determines the next routing direction (lookahead) for the current flit.
// First the coordinates of the next hop are determined based on the routing direction
// encoded in the header flit. Next, the routing direction is updated based on the
// coordinates of the destination router.
// Packets are routed first west or east (X axis), then north or south (Y axis).
// The YX positional routing is proven to be deadlock free.
//
// There is no delay from inputs destination and current_routing to output next_routing.
// Conversely, to improve timing, the local position input is sampled, thus there is a one-cycle
// delay from input position to output next_routing. Note, however, that position is supposed to be
// a static input after initialization, because it encodes the position of the router on the mesh.
//
// Interface
//
// * Inputs
// - clk: clock.
// - position: static input that encodes the x,y coordinates of the router on the mesh.
// - destination: x,y coordinates of the destination router.
// - current_routing: one-hot encoded routing direction for the current hop.
//
// * Outputs
// - next_routing: one-hot encoded routing direction for the next hop.
//

module lookahead_routing_multicast #(
    parameter integer DEST_SIZE = 6
) (
    input logic clk,
    input noc::xy_t position,
    input noc::xy_t [0:DEST_SIZE-1] destination,
    input logic [DEST_SIZE-1:0] val,
    input noc::direction_t current_routing,
    output noc::direction_t next_routing
);

    logic [2:0] testing_local_west;
    logic [2:0] testing_local_east;
  //  logic [2:0] testing_local_north;
  //  logic [2:0] testing_local_south;
    logic [2:0] testing_local_local;

    noc::direction_t [DEST_SIZE-1:0] routing_paths;

    // Function to compute next routing direction based on ring topology
    function automatic noc::direction_t routing(input noc::xy_t next_position,
                                                input noc::xy_t destination,
						input noc::direction_t current_routing);
	noc::direction_t west,east;
//	west = next_position.x>destination.x?noc::goWest:~noc::goWest;
//	east = next_position.x<destination.x?noc::goEast:~noc::goEast;
  /*      int dist_cw  = (destination.x - next_position.x + noc::kRingSize) % noc::kRingSize;
        int dist_ccw = (next_position.x - destination.x + noc::kRingSize) % noc::kRingSize;
        if (dist_cw == 0 && dist_ccw == 0)
            routing = noc::goLocal; // Already at destination
        else if (dist_cw <= dist_ccw) begin
            east = noc::goEast; // 3'b010
	    west = ~noc::goWest;
	    routing=west&east;
        end else begin
            west = noc::goWest; // 3'b001
	    east = ~noc::goEast;
	    routing=west&east;
        end
*/
	if(next_position.x == destination.x) begin
		routing = noc::goLocal;
	end
	else
		routing = current_routing;
	
//	else if (current_routing.go_west)
//		routing = noc::goWest;
        //routing=west&east;
        // Determine clockwise (East) or counter-clockwise (West) based on destination
       // if (position.x < destination.x) begin
            // If destination is ahead in the ring, route clockwise (East)
          //  routing = noc::goEast;  // Clockwise direction
       // end else if (position.x > destination.x) begin
            // If destination is behind in the ring, route counter-clockwise (West)
           // routing = noc::goWest;  // Counter-clockwise direction
            // If already at destination (same position), route locally
          //  routing = noc::goLocal; // Stay at local port (no movement)
       // end
    endfunction

     // Compute next position for each port (East, West, and Local directions)
    noc::xy_t [1:0] next_position_d, next_position_q;
    
    // East (Clockwise) movement
//    assign next_position_d[noc::kEastPort].x = position.x + 1'b1;  // Move to the next tile (East in the ring)
    //assign next_position_d[noc::kEastPort].y = position.y;         // y-coordinate remains the same

    // West (Counter-clockwise) movement
//    assign next_position_d[noc::kWestPort].x = position.x - 1'b1;  // Move to the previous tile (West in the ring)
    //assign next_position_d[noc::kWestPort].y = position.y;         // y-coordinate remains the same

    // Local movement (when already at the destination)
    //assign next_position_d.x = position.x;         // Stay at the current tile
    //assign next_position_d.y = position.y;         // y-coordinate remains the same
assign next_position_d[noc::kEastPort].x = (position.x + 1) % noc::kRingSize;
assign next_position_d[noc::kWestPort].x = (position.x + noc::kRingSize - 1) % noc::kRingSize;

    always_comb begin
        // The function processes routing for all destinations.
        // final next_routing is an OR of all the next_routing computations
        next_routing = 3'b0;
        for (int rout_num = 0; rout_num < DEST_SIZE; rout_num++) begin
            routing_paths[rout_num] = 3'b000;
        end

        for (int dest_num = 0; dest_num < DEST_SIZE; dest_num++) begin
            if (val[dest_num]) begin
                unique case (current_routing)
                /*    noc::goNorth:
                    routing_paths[dest_num] =
                        routing(next_position_q[noc::kNorthPort], destination[dest_num]);
                    noc::goSouth:
                    routing_paths[dest_num] =
                        routing(next_position_q[noc::kSouthPort], destination[dest_num]); */
                    noc::goWest:
                    routing_paths[dest_num] =
                        routing(next_position_q[noc::kWestPort], destination[dest_num], current_routing);
                    noc::goEast:
                    routing_paths[dest_num] =
                        routing(next_position_q[noc::kEastPort], destination[dest_num], current_routing);
                    default: routing_paths[dest_num] = 3'b000;
                endcase
            end
        end

        for (int rout_num = 0; rout_num < DEST_SIZE; rout_num++) begin
            next_routing = next_routing | routing_paths[rout_num];
        end
    end

endmodule
