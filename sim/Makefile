VCOM = vcom -quiet -93
VLOG = vlog -quiet
SVLOG = vlog -sv -quiet -suppress 2583

#SIM_GUI = 1

all: sim-compile-sync

work:
		vlib work

sim-compile-sync: work
		$(VCOM) -mixedsvvh ../dut_sync/pkg/*.vhd
		$(VCOM) ../dut_sync/*.vhd
		$(VLOG) ../uart/*.v
		$(SVLOG) ../traffig_gen/gen.sv
		$(SVLOG) ../traffig_gen/tb.sv
		$(SVLOG) ../dut_sync/router/noc_pkg.sv
		$(SVLOG) ../dut_sync/router/router_arbiter.sv
		$(SVLOG) ../dut_sync/router/router_fifo.sv
		$(SVLOG) ../dut_sync/router/lookahead_router_wrapper.sv
	$(SVLOG) ../dut_sync/router/lookahead_routing.sv
		$(SVLOG) ../dut_sync/router/lookahead_router.sv

	


# Uncomment the following lines if needed
#		$(SVLOG) ../dut_sync/router/r*.sv
#		$(SVLOG) ../dut_sync/router/l*.sv

sim: sim-compile-sync
ifdef SIM_GUI
		vsim tb -voptargs="+acc"
else
		vsim tb -c -voptargs="+acc"
endif

clean:
		rm -rf work transcript *.wlf

.PHONY: sim-compile-sync sim clean

