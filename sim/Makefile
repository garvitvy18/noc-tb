
VCOM = vcom -quiet -93
SVLOG = vlog -sv -quiet

# SIM_GUI = 1

all: sim-compile-sync

work:
	vlib work


sim-compile-sync: work
	$(VCOM) -mixedsvvh ../dut_sync/pkg/*.vhd
	$(VCOM) ../dut_sync/*.vhd
	$(SVLOG) ../traffig_gen/gen.sv
	$(SVLOG) ../traffig_gen/tb.sv


sim: sim-compile-sync
ifdef SIM_GUI
	vsim tb -novopt
else
	vsim tb -c -novopt
endif

clean:
	rm -rf work transcript *.wlf

.PHONY: sim-compile-sync sim clean
