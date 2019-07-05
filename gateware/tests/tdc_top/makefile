GHDLFLAGS = --ieee=synopsys --std=93c -P../libraries/unisim

# main target is the wave output file
all: simulation.ghw

# view target generates the wave file and starts the viewer
view: simulation.ghw 
	gtkwave simulation.ghw --save=simulation.gtkw &

# regenerate wave output and update viewer
simulation.ghw: testbench 
	ghdl -r testbench --stop-time=100000ns --wave=simulation.ghw --ieee-asserts=disable-at-0
	gsettings set com.geda.gtkwave reload 0
	#vcd2fst simulation.vcd simulation.fst && rm simulation.vcd

testbench: 	\
		../../src/fifo.vhd \
		../../src/guarded_fifo.vhd \
		../../src/ft232h_async_fifo.vhd \
		../../src/tdc_clk_gen.vhd \
		../../src/tdc.vhd     \
		../../src/pwm.vhd     \
		../../src/tdc_top.vhd \
		testbench.vhd
	make -C ../libraries/unisim
	ghdl -a $(GHDLFLAGS) $?
	ghdl -m $(GHDLFLAGS) testbench

clean:
	rm -f *.o testbench work-obj*.cf simulation.ghw 


# vpath %vhd  ../../src
# vpath %vhdl ../../src
# vpath %vhd  .
# vpath %vhdl .

# # generic rules
# %.o: %.vhdl
# 	ghdl -a -P../libraries/unisim $< 
# %.o: %.vhd
# 	ghdl -a -P../libraries/unisim $< 



# # main target is the wave output file
# all: simulation.ghw

# # view target generates the wave file and starts the viewer
# view: simulation.ghw 
# 	gtkwave simulation.ghw --save=simulation.gtkw &

# simulation.ghw: testbench makefile
# 	ghdl -r testbench --stop-time=50000ns --wave=simulation.ghw
# 	gconftool-2 --type string --set /com.geda.gtkwave/0/reload 0
# 	gsettings set com.geda.gtkwave reload 0


# # # this has an additional dependency on 
# # # unisim library which is rewritten for
# # # the purpose of this test 
# # testbench.o:                           \
# # 	../libraries/unisim/dcm.o          \
# # 	../libraries/unisim/vcomponents.o

# tdc_top.o:                             \
# 	../libraries/unisim/dcm.o          \
# 	../libraries/unisim/ibufds.o       \
# 	../libraries/unisim/vcomponents.o

# ../libraries/unisim/dcm.o:  ../libraries/unisim/dcm.vhd
# 	ghdl -a --work=unisim --workdir=../libraries/unisim ../libraries/unisim/dcm.vhd

# ../libraries/unisim/ibufds.o:  ../libraries/unisim/ibufds.vhd
# 	ghdl -a --work=unisim --workdir=../libraries/unisim ../libraries/unisim/ibufds.vhd

# ../libraries/unisim/vcomponents.o:  ../libraries/unisim/vcomponents.vhd
# 	ghdl -a --work=unisim --workdir=../libraries/unisim ../libraries/unisim/vcomponents.vhd

	
# # module "$(COMPONENT).o" must be before the testbench "$(COMPONENT)_tb.o" in the dependency list
# testbench:  fifo.o                \
# 			guarded_fifo.o        \
# 			wide_to_narrow_fifo.o \
# 			ft232h_async_fifo.o   \
# 			tdc_clk_gen.o         \
# 			fifo_lut.o            \
# 			guarded_fifo_lut.o    \
# 			pwm.o                 \
# 			tdc.o                 \
#             tdc_top.o             \
#             testbench.o 
# 	ghdl -e -P../libraries/unisim  testbench

# clean:
# 	rm *.o testbench work-obj93.cf simulation.ghw
