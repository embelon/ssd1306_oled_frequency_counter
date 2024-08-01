
module upduino (
	output led_red,
	output led_green,
    output led_blue,

	output debugA,

	// OLED
	output oled_rstn,
	output oled_vbatn,	
	output oled_vcdn,
	output oled_csn,
	output oled_dc,
	output oled_clk,
	output oled_mosi,
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

	
	wire cnt_reset, cnt_enable;
	assign cnt_reset = !resetn;
	assign cnt_enable = delay[24];

	localparam DIGITS_NUM = 6;
	wire [4*DIGITS_NUM-1:0] cnt_digits;

	counter_bcd_Ndigits #(.DIGITS_NUM(DIGITS_NUM))
	counter
	(
		.clk_in(clk_1M),
		.reset_in(cnt_reset),
		.enable_in(cnt_enable),

		.digits(cnt_digits), 
		.carry_out()
	);


	wire oled_reset = !resetn;
	wire [7:0] oled_data;
	wire oled_write_stb;
	wire oled_sync_stb;
	wire oled_ready;

	ssd1306_driver oled_driver
	(
		.clk_in(clk_1M),
		.reset_in(oled_reset),   		// triggers init / reinit
		
		// data / command interface
		.data_in(oled_data),
		.write_stb(oled_write_stb),		// send data from data_in to lcd
		.sync_stb(oled_sync_stb),		// send commands to go back to (0,0)
		.ready(oled_ready),    			// driver is ready for data / command

		// output signals controlling OLED (connected to pins)
		.oled_rstn(oled_rstn),
		.oled_vbatn(oled_vbatn),	
		.oled_vcdn(oled_vcdn),
		.oled_csn(oled_csn),
		.oled_dc(oled_dc),
		.oled_clk(oled_clk),
		.oled_mosi(oled_mosi)
	);

	data_streamer #(.DIGITS_NUM(DIGITS_NUM))
	streamer
	(
		.clk_in(clk_1M),
		.reset_in(!resetn),

		// data interface, data to be displayed as number
		.digits(cnt_digits),
		.write_stb(!cnt_enable),
		.ready(),

		// output interface (to be connected to oled driver)
		.oled_data(oled_data),
		.oled_write_stb(oled_write_stb),
		.oled_sync_stb(oled_sync_stb),
		.oled_ready(oled_ready)
	);












	assign debugA = oled_ready;

endmodule
