GHDLFLAGS = --ieee=synopsys --std=93c -P../libraries/unisim

# main target is the wave output file
all: simulation.ghw

# view target generates the wave file and starts the viewer
view: simulation.ghw 
	gtkwave simulation.ghw --save=simulation.gtkw &

# regenerate wave output and update viewer
simulation.ghw: testbench 
	ghdl -r testbench --stop-time=10000ns --wave=simulation.ghw --ieee-asserts=disable-at-0
	gsettings set com.geda.gtkwave reload 0
	#vcd2fst simulation.vcd simulation.fst && rm simulation.vcd

testbench: 	\
		../../src/tdc_clk_gen.vhd \
		testbench.vhd
	make -C ../libraries/unisim
	ghdl -a $(GHDLFLAGS) $?
	ghdl -m $(GHDLFLAGS) testbench

clean:
	rm -f *.o testbench work-obj*.cf simulation.ghw 
