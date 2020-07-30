# Makefile for icestorm tools + yosys + nextpnr
# Modified from examples in icestorm distribution
# 01-16-18 E. Brombaugh

# src directory
VPATH = ../src

SRC =	f303_ice5_fm.v ../src/clkgen.v ../src/exptab.v ../src/fm_gen.v \
        ../src/i2s_out.v ../src/spi_slave.v ../src/exp_conv.v \
        ../src/get_env.v ../src/get_wave.v  ../src/sintab.v

# project stuff
PROJ = f303_ice5_fm
PIN_DEF = f303_ice5_fm.pcf
SDC = f303_ice5_fm.sdc
DEVICE = u4k

YOSYS = yosys
YOSYS_SYNTH_ARGS = -dsp -relut -dffe_min_ce_use 4
NEXTPNR = nextpnr-ice40
NEXTPNR_ARGS = --pre-pack $(SDC) --placer heap
ICEPACK = icepack
ICETIME = icetime
ICEPROG = iceprog
ICEBRAM = icebram
CDCPROG = cdc_prog
VERILATOR = verilator
TECH_LIB = /usr/local/share/yosys/ice40/cells_sim.v

all: $(PROJ).bin
		
%.json: $(SRC)
	$(YOSYS) -p 'synth_ice40 $(YOSYS_SYNTH_ARGS) -top $(PROJ) -json $@' $(SRC)

%.asc: %.json $(PIN_DEF) 
	$(NEXTPNR) $(NEXTPNR_ARGS) --$(DEVICE) --json $< --pcf $(PIN_DEF) --asc $@
		
%.bin: %.asc
	$(ICEPACK) $< $@

%.rpt: %.asc
	$(ICETIME) -d $(DEVICE) -mtr $@ $<

prog: $(PROJ).bin
	$(CDCPROG) -p /dev/ttyACM0 $<

flash: $(PROJ).bin
	$(CDCPROG) -w -p /dev/ttyACM0 $<

lint: $(SRC)
	$(VERILATOR) --lint-only -Wall --top-module $(PROJ) $(TECH_LIB) $(SRC)

clean:
	rm -f *.json *.asc *.rpt *.bin *.hex

.SECONDARY:
.PHONY: all prog clean
