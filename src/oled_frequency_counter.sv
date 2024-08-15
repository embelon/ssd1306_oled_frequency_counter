`default_nettype none

module oled_frequency_counter
(
    input bit clk_ref_in,
    input bit reset_in,

    input bit clk_x_in,

	// Interface to controll SSD1306 OLED Display
	output bit oled_rstn_out,
	output bit oled_vbatn_out,	
	output bit oled_vcdn_out,
	output bit oled_csn_out,
	output bit oled_dc_out,
	output bit oled_clk_out,
	output bit oled_mosi_out
);

	typedef enum {S_MEASURE, S_DISPLAY} e_state;
    e_state state;

	wire prescaler_carry_out;
    // clk divider to get refresh trigger
    // assuming clk_ref_in is 1MHz
    counter_bcd_Ndigits #(.DIGITS_NUM(6))
    prescaler
    (
        .clk_in(clk_ref_in),
        .reset_in(reset_in),
        .enable_in(1'b1),

        .digits_out(),
        .carry_out(prescaler_carry_out)
    );

	assign state = prescaler_carry_out ? S_DISPLAY : S_MEASURE;

    wire streamer_ready;

	wire cnt_reset, cnt_enable;
	assign cnt_reset = reset_in || ((state == S_DISPLAY) && streamer_ready);
	assign cnt_enable = (state == S_MEASURE);

	localparam DIGITS_NUM = 6;
	wire [4*DIGITS_NUM-1:0] cnt_digits;

	counter_bcd_Ndigits #(.DIGITS_NUM(DIGITS_NUM))
	counter
	(
		.clk_in(clk_x_in),
		.reset_in(cnt_reset),
		.enable_in(cnt_enable),

		.digits_out(cnt_digits), 
		.carry_out()
	);

	wire oled_reset = reset_in;

	wire [7:0] oled_data;
	wire oled_write_stb;
	wire oled_sync_stb;
	wire oled_ready;

	ssd1306_driver oled_driver
	(
		.clk_in(clk_ref_in),
		.reset_in(oled_reset),   			// triggers init / reinit
		
		// data / command interface
		.data_in(oled_data),
		.write_stb_in(oled_write_stb),		// send data from data_in to lcd
		.sync_stb_in(oled_sync_stb),		// send commands to go back to (0,0)
		.ready_out(oled_ready),    			// driver is ready for data / command

		// output signals controlling OLED (connected to pins)
		.oled_rstn_out(oled_rstn_out),
		.oled_vbatn_out(oled_vbatn_out),	
		.oled_vcdn_out(oled_vcdn_out),
		.oled_csn_out(oled_csn_out),
		.oled_dc_out(oled_dc_out),
		.oled_clk_out(oled_clk_out),
		.oled_mosi_out(oled_mosi_out)
	);

    wire refresh_display;
    assign refresh_display = (state == S_DISPLAY);

	data_streamer #(.DIGITS_NUM(DIGITS_NUM))
	streamer
	(
		.clk_in(clk_ref_in),
		.reset_in(reset_in),

		// data interface, data to be displayed as number
		.digits_in(cnt_digits),
		.dec_point_position_in(3'h5),
		.refresh_stb_in(refresh_display),
		.ready_out(streamer_ready),

		// output interface (to be connected to oled driver)
		.oled_data_out(oled_data),
		.oled_write_stb_out(oled_write_stb),
		.oled_sync_stb_out(oled_sync_stb),
		.oled_ready_in(oled_ready)
	);


endmodule
