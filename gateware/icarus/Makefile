# Makefile for Icarus Verilog simulation
# 02-11-2019 E. Brombaugh

# sources
SOURCES = 	tb_f303_ice5_fm.v ../icestorm/f303_ice5_fm.v \
            ../src/clkgen.v ../src/exptab.v ../src/fm_gen.v \
            ../src/i2s_out.v ../src/spi_slave.v ../src/exp_conv.v \
            ../src/get_env.v ../src/get_wave.v  ../src/sintab.v

# top level
TOP = tb_f303_ice5_fm
			
# Executables
VLOG = iverilog
WAVE = gtkwave
TECH_LIB = /opt/openfpga/yosys/share/yosys/ice40/cells_sim.v

# targets
all: $(TOP).vcd

wave: $(TOP).vcd $(TOP).gtkw
	$(WAVE) $(TOP).gtkw
	
$(TOP).vcd: $(TOP)
	./$(TOP)

$(TOP): $(SOURCES) $(HEX)
	$(VLOG) -D icarus -l $(TECH_LIB) -o $(TOP) $(SOURCES)
	
clean:
	rm -rf a.out *.obj $(RPT) $(TOP) $(TOP).vcd
	
