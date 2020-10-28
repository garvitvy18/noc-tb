
VCOM = vcom -quiet -93
VLOG = vlog -quiet
SVLOG = vlog -sv -quiet -suppress 2583

# SIM_GUI = 1

all: sim-compile-sync

work:
	vlib work


sim-compile-sync: work
	$(VCOM) -mixedsvvh ../dut_sync/pkg/*.vhd
	$(VCOM) ../dut_sync/*.vhd
	$(VLOG) ../uart/*.v
	$(SVLOG) ../traffig_gen/gen.sv
	$(SVLOG) ../traffig_gen/tb.sv


sim: sim-compile-sync
ifdef SIM_GUI
	vsim tb -voptargs="+acc"
else
	vsim tb -c -voptargs="+acc"
endif

clean:
	rm -rf work transcript *.wlf

.PHONY: sim-compile-sync sim clean
