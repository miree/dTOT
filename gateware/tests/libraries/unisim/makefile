GHDLFLAGS = --ieee=synopsys --std=93c -P../libraries/unisim

# main target is the wave output file
all: unisim-obj93.cf

unisim-obj93.cf: dcm.vhd         \
                 ibufds.vhd      \
                 vcomponents.vhd 
	ghdl -a --work=unisim $(GHDLFLAGS) $?

clean:
	rm -f *.o testbench unisim-obj*.cf simulation.ghw 
