onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/clk
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/rst
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/position
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/data_e_in
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/data_w_in
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/data_p_in
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/data_void_in
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/stop_out
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/data_e_out
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/data_w_out
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/data_p_out
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/data_void_out
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/stop_in
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/state
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/new_state
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/data_in
add wave -noupdate -subitemconfig {{/tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/fifo_head[2]} -expand} /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/fifo_head
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/data_out_crossbar
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/last_flit
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/saved_routing_request
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/final_routing_request
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/next_hop_routing
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/transp_final_routing_request
add wave -noupdate -expand -subitemconfig {{/tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/enhanc_routing_configuration[1]} -expand} /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/enhanc_routing_configuration
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/routing_configuration
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/saved_routing_configuration
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/grant
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/grant_valid
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/rd_fifo
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/no_backpressure
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/rd_fifo_or
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/in_unvalid_flit
add wave -noupdate -expand /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/out_unvalid_flit
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/in_valid_head
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/full
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/empty
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/wr_fifo
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/credits
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/forwarding_tail
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/forwarding_head
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/forwarding_in_progress
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/insert_lookahead_routing
add wave -noupdate /tb/traffic_gen/dut/noc_xy_1/routerinst(0)/router_ij/lookahead_router_wrapper_i/genblk1/router_impl_i/Ports
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {105179 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 218
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {10250 ps} {115250 ps}
