
# ---- iCE40 Upduino 2.0 Board ----

upduino.json: upduino.sv shift_reg.v ssd1306_init.sv ssd1306_init_rom.sv
	yosys -ql upduino.log -p 'synth_ice40 -top upduino -json upduino.json' $^

upduino_syn.v: upduino.json
	yosys -p 'read_json upduino.json; write_verilog upduino_syn.v'

upduino.asc: upduino.pcf upduino.json
	nextpnr-ice40 --freq 13 --up5k --asc upduino.asc --pcf upduino.pcf --json upduino.json

upduino.bin: upduino.asc
	icetime -d up5k -c 12 -mtr upduino.rpt upduino.asc
	icepack upduino.asc upduino.bin

upduprog: upduino.bin
	iceprog upduino.bin

# ---- Clean ----

clean:
	rm -f upduino.json upduino.log upduino.asc upduino.rpt upduino.bin
	rm -f upduino_syn.v upduino_syn_tb.vvp upduino_tb.vvp

.PHONY: upduprog updusim updusynsim
