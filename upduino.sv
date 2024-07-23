
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
	reg [5:0] reset_cnt = 0;
	wire resetn = &reset_cnt;

	always @(posedge clk_12M) begin
		if (!lock && !resetn) begin
			reset_cnt <= 0;
		end else begin
			reset_cnt <= reset_cnt + !resetn;
		end
	end

	reg [23:0] delay = 0;
	always @(posedge clk_12M) begin
		delay <= delay + 22'b1;
	end

	wire clk_1M = delay[3];

	assign led_red = delay[21];

	wire init_trigger_spi;
	wire [7:0] init_command;
	wire init_toggle_cs;
	
	wire spi_ready;

	ssd1306_init init (
    	.clk_in(clk_1M),
    	.reset_in(delay[23]),        // also triggers init / reinit

    	.done(debugA),        		// done goes 1 when init sequence finished
    
    	// signals to control spi
    	.command_start(init_trigger_spi),
    	.command_out(init_command),
		.command_last_byte(init_toggle_cs),
    	.command_ready(spi_ready),

    	// IO controlled by init module directly
    	.oled_rstn(oled_rstn),
    	.oled_vbatn(oled_vbatn),
    	.oled_dc(oled_dc)
	);

	spi spi_driver (
		.clk_in(clk_1M),
		.reset_in(delay[23]),

    	.transmitt(init_trigger_spi),
		.deactivate_cs_after(init_toggle_cs),
    	.data_in(init_command),

    	.data_out(),
    	.ready(spi_ready),

		.select(oled_csn),
		.sck(oled_clk),
		.mosi(oled_mosi),
		.miso(1'b0)
	);

/*	
	shift_register shift (
    	.clk_in(clk_1M),
		.reset(delay[21]),

    	.start(init_cmd_start),
    	.data_in(init_cmd),

    	.ready(cmd_ready),
    	.data_out(),

    	.clk_out(oled_clk),
    	.serial_out(oled_mosi),
    	.serial_in(1'b1)
	);
*/
/*
	wire [7:0] led_red_pwm, led_green_pwm, led_blue_pwm;

	SB_RGBA_DRV 
	#( 
		.CURRENT_MODE("0b1"),  
		.RGB0_CURRENT("0b000001"),
		.RGB1_CURRENT("0b000001"),
		.RGB2_CURRENT("0b000001")
	)
	rgb (
		.RGBLEDEN (1'b1),
		.RGB0PWM  (led_blue_pwm),
		.RGB1PWM  (led_green_pwm),
		.RGB2PWM  (led_red_pwm),
		.CURREN   (1'b1),
		.RGB0     (led_blue),
		.RGB1     (led_green),
		.RGB2     (led_red)
	);

	reg [31:0] gpio;
	assign led_red_pwm = gpio[23:16];
    assign led_green_pwm = gpio[15:8];
    assign led_blue_pwm = gpio[7:0];
*/

endmodule
