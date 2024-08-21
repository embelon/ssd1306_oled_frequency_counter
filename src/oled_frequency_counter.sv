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

	// Debug interface
	// output bit [7:0] debug_out
);

	wire cnt_ref_reset;
	wire cnt_ref_enable;
	wire cnt_ref_done;
    // clk divider to get refresh trigger
    // assuming clk_ref_in is 1MHz
    counter_bcd_Ndigits #(.DIGITS_NUM(6))
    counter_ref
    (
        .clk_in(clk_ref_in),
        .reset_in(cnt_ref_reset),
        .enable_in(cnt_ref_enable),

        .digits_out(),
        .carry_out(cnt_ref_done)
    );

    wire streamer_ready;

	wire cnt_x_reset;
	wire cnt_x_enable;

	localparam DIGITS_NUM = 6;
	wire [4*DIGITS_NUM-1:0] cnt_x_digits;

	counter_bcd_Ndigits_async_rst #(.DIGITS_NUM(DIGITS_NUM))
	counter_x
	(
		.clk_in(clk_x_in),
		.reset_in(cnt_x_reset),
		.enable_in(cnt_x_enable),

		.digits_out(cnt_x_digits), 
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

    reg refresh_display;

	data_streamer #(.DIGITS_NUM(DIGITS_NUM))
	streamer
	(
		.clk_in(clk_ref_in),
		.reset_in(reset_in),

		// data interface, data to be displayed as number
		.digits_in(cnt_x_digits),
		.dec_point_position_in(3'h3),
		.refresh_stb_in(refresh_display),
		.ready_out(streamer_ready),

		// output interface (to be connected to oled driver)
		.oled_data_out(oled_data),
		.oled_write_stb_out(oled_write_stb),
		.oled_sync_stb_out(oled_sync_stb),
		.oled_ready_in(oled_ready)
	);

	// state machine definition
	typedef enum {S_IDLE, S_MEASURE, S_DISPLAY} e_state;
    e_state state;

	always @(posedge clk_ref_in) begin
		if (reset_in) begin
			state <= S_IDLE;
			refresh_display <= 1'b0;
		end else begin
			case (state)
				S_IDLE: begin
					if (streamer_ready) begin
						state <= S_MEASURE;
					end					
				end
				S_MEASURE: begin
					// measuring frequency
					if (cnt_ref_done) begin
						state <= S_DISPLAY;
						refresh_display <= 1'b1;
					end
				end
				S_DISPLAY: begin
					if (refresh_display) begin
						if (!streamer_ready) begin
							// clear trigger flag
							refresh_display <= 1'b0;
						end
					end else
					// waiting for display to refresh result
					if (streamer_ready) begin
						// display refreshed
						state <= S_IDLE;
					end
				end
			endcase
		end
	end

	assign cnt_ref_reset = reset_in || (state == S_IDLE);
	assign cnt_ref_enable = (state == S_MEASURE);

	assign cnt_x_reset = reset_in || (state == S_IDLE);
	assign cnt_x_enable = (state == S_MEASURE);

	// assign debug_out[4:0] = {refresh_display, streamer_ready, cnt_ref_done, clk_x_in, cnt_x_enable};

endmodule
