`default_nettype none

module pico_ice (
	// LEDs
	output led_red,
	output led_green,
    output led_blue,

	// Unknown frequency signal
	input clk_x_in,

	// OLED
	output oled_rstn_out,
	output oled_vbatn_out,	
	output oled_vcdn_out,
	output oled_csn_out,
	output oled_dc_out,
	output oled_clk_out,
	output oled_mosi_out,

	// debug
	output dbg_7,
	output dbg_6,
	output dbg_5,
	output dbg_4,
	output dbg_3,
	output dbg_2,
	output dbg_1,
	output dbg_0
);

    wire clk_12M;
//    SB_HFOSC #(.CLKHF_DIV("0b11")) inthosc(.CLKHFPU(1'b1), .CLKHFEN(1'b1), .CLKHF(clk_6M));			// 6MHz internal osc.
    SB_HFOSC #(.CLKHF_DIV("0b10")) inthosc(.CLKHFPU(1'b1), .CLKHFEN(1'b1), .CLKHF(clk_12M));		// 12MHz internal osc.

	wire lock;
	wire clk_20M;					// 20MHz
	SB_PLL40_CORE #(
		.FEEDBACK_PATH("SIMPLE"),
		.PLLOUT_SELECT("GENCLK"),
		.DIVR(4'b0000),
		.DIVF(7'b0110100),
		.DIVQ(3'b101),
		.FILTER_RANGE(3'b001)
	) uut (
		.LOCK(lock),
		.RESETB(1'b1),
		.BYPASS(1'b0),
		.REFERENCECLK(clk_12M),
		.PLLOUTCORE(clk_20M)
	);

	reg clk_10M = 0;				// 20MHz div 2 = 10MHz
	always @(posedge clk_20M) begin
		clk_10M = !clk_10M;
	end
/*
	wire clk;						// 10MHz buffered clock
	SB_GB ClockBuffer(
		.USER_SIGNAL_TO_GLOBAL_BUFFER(clk_10M_buf),
		.GLOBAL_BUFFER_OUTPUT(clk_10M)
	);
*/

	// 5ms reset pulse (65536 / 12M)
	reg [15:0] reset_cnt = 0;
	wire resetn = &reset_cnt;

	always @(posedge clk_12M) begin
		if (!lock && !resetn) begin
			reset_cnt <= 0;
		end else begin
			reset_cnt <= reset_cnt + !resetn;
		end
	end

	reg [24:0] delay = 0;
	always @(posedge clk_12M) begin
		delay <= delay + 25'b1;
	end

	wire clk_1M = delay[3];

	assign led_red = delay[23];

	wire [7:0] debug;
	assign debug[7:0] = {dbg_7, dbg_6, dbg_5, dbg_4, dbg_3, dbg_2, dbg_1, dbg_0};

	oled_frequency_counter freq_counter
	(
		.clk_ref_in(clk_1M),
		.reset_in(!resetn),

		.clk_x_in(clk_x_in),

		// Interface to controll SSD1306 OLED Display
		.oled_rstn_out(oled_rstn_out),
		.oled_vbatn_out(oled_vbatn_out),	
		.oled_vcdn_out(oled_vcdn_out),
		.oled_csn_out(oled_csn_out),
		.oled_dc_out(oled_dc_out),
		.oled_clk_out(oled_clk_out),
		.oled_mosi_out(oled_mosi_out)

		// Debug interface
		// .debug_out(debug[7:0])
	);
	
endmodule
