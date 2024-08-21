
# ---- iCE40 Pico-ICE Board ----

pico-ice.json: ../src/shift_register.sv ../src/spi.sv ../src/ssd1306_microcode_rom.sv ../src/ssd1306_microcode_exec.sv ../src/ssd1306_driver.sv ../src/counter_bcd_1digit.sv ../src/counter_bcd_Ndigits.sv ../src/counter_bcd_1digit_async_rst.sv ../src/counter_bcd_Ndigits_async_rst.sv ../src/decoder_bin_to_7seg.sv ../src/decoder_7seg_to_21x32pix.sv ../src/data_streamer.sv ../src/oled_frequency_counter.sv pico_ice.sv
	yosys -ql pico-ice.log -p 'synth_ice40 -top pico_ice -json pico-ice.json' $^

pico-ice.asc: pico-ice.pcf pico-ice.json
	nextpnr-ice40 --freq 14 --up5k --package sg48 --asc pico-ice.asc --pcf pico-ice.pcf --json pico-ice.json

pico-ice.bin: pico-ice.asc
	icetime -d up5k -c 12 -mtr pico-ice.rpt pico-ice.asc
	icepack pico-ice.asc pico-ice.bin

prog: pico-ice.bin
	dfu-util --alt 1 --download pico-ice.bin --device 1209:b1c0

lint: pico-ice.json
	verilator --lint-only --top pico_ice -I../src pico_ice.sv

# ---- Clean ----

clean:
	rm -f pico-ice.json pico-ice.log pico-ice.asc pico-ice.rpt pico-ice.bin

.PHONY: prog
