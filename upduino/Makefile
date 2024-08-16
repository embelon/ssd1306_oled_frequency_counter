
# ---- iCE40 Upduino 2.0 Board ----

upduino.json: ../src/shift_register.sv ../src/spi.sv ../src/ssd1306_microcode_rom.sv ../src/ssd1306_microcode_exec.sv ../src/ssd1306_driver.sv ../src/counter_bcd_1digit.sv ../src/counter_bcd_Ndigits.sv ../src/counter_bcd_1digit_async_rst.sv ../src/counter_bcd_Ndigits_async_rst.sv ../src/decoder_bin_to_7seg.sv ../src/decoder_7seg_to_21x32pix.sv ../src/data_streamer.sv ../src/oled_frequency_counter.sv upduino.sv
	yosys -ql upduino.log -p 'synth_ice40 -top upduino -json upduino.json' $^

upduino_syn.v: upduino.json
	yosys -p 'read_json upduino.json; write_verilog upduino_syn.v'

upduino.asc: upduino.pcf upduino.json
	nextpnr-ice40 --freq 14 --up5k --package sg48 --asc upduino.asc --pcf upduino.pcf --json upduino.json

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
