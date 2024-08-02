`default_nettype none

module ssd1306_driver
(
    input clk_in,
    input reset_in,     // triggers init / reinit
    
	// data / command interface
    input [7:0] data_in,
    input write_stb,	// send data from data_in to lcd
	input sync_stb,		// send commands to go back to (0,0)
    output ready,       // driver is ready for data / command

	// output signals controlling OLED (connected to pins)
	output oled_rstn,
	output oled_vbatn,	
	output oled_vcdn,
	output oled_csn,
	output oled_dc,
	output oled_clk,
	output oled_mosi,
);

	// Internal signals
	reg [7:0] spi_data;
	reg spi_dc;					// data when 1, command when 0
	wire spi_transmitt;			// transmitt trigger
	wire spi_deactivate_cs; 	// deactivate cs after current byte

	// Signals coming from init module
	wire init_command_start;
	wire [7:0] init_command_code;
	wire init_deactivate_cs;
	wire init_done;
	wire init_dc;

	// Signals going to spi driver (MUXed)	
	wire [7:0] spi_driver_data_in;
	wire spi_driver_transmitt;
	wire spi_driver_deactivate_cs;
	// When init is finished (done = 1), then signals comming from init module are disconnected from spi driver
	assign spi_driver_data_in = init_done ? spi_data : init_command_code;
	assign spi_driver_transmitt = init_done ? spi_transmitt : init_command_start;
	assign spi_driver_deactivate_cs = init_done ? spi_deactivate_cs : init_deactivate_cs;

	// When init is finished (done = 1), then dc is controlled locally
	assign oled_dc = init_done ? spi_dc : init_dc;

	// Signals coming from spi driver
	wire spi_ready;

	ssd1306_init init (
    	.clk_in(clk_in),
    	.reset_in(reset_in),        // also triggers init / reinit

    	.done(init_done),      		// done goes 1 when init sequence finished
    
    	// signals to control spi
    	.command_start(init_command_start),
    	.command_out(init_command_code),
		.command_last_byte(init_deactivate_cs),
    	.command_ready(spi_ready),

    	// IO controlled by init module directly
    	.oled_rstn(oled_rstn),
    	.oled_vbatn(oled_vbatn),
		.oled_vcdn(oled_vcdn),
    	.oled_dc(init_dc)
	);

	spi spi_driver (
		.clk_in(clk_in),
		.reset_in(reset_in),

    	.transmitt(spi_driver_transmitt),
		.deactivate_cs_after(spi_driver_deactivate_cs),
    	.data_in(spi_driver_data_in),

    	.data_out(),
    	.ready(spi_ready),

		.select(oled_csn),
		.sck(oled_clk),
		.mosi(oled_mosi),
		.miso(1'b0)
	);

	// commands to be send to display to go back to (0,0)
	parameter S_CMD_LINE_0 = 8'h40;
	parameter S_CMD_OFFSET = 8'hd3;

	// state machine
	parameter S_RESET = 0, S_INIT = 1, S_IDLE = 2;
	parameter S_SET_START_LINE = 3, S_START_LINE_WAIT = 4;
	parameter S_SET_OFFSET_CMD = 5, S_OFFSET_CMD_WAIT = 6;
	parameter S_SEND_DATA = 7, S_DATA_WAIT = 8;
	reg [3:0] state_r;

	always @(posedge clk_in) begin
		if (reset_in) begin
			state_r <= S_RESET;
		end else begin
			case (state_r)
			 	S_RESET: begin
					state_r <= S_INIT;
					spi_data <= 8'h00;
					spi_dc <= 0;
				end
				S_INIT: begin
					if (init_done && spi_ready) begin
						state_r <= S_IDLE;
					end
				end
				S_IDLE: begin
					if (sync_stb) begin
						// start sync command sequence
						spi_dc <= 0;
						state_r <= S_SET_START_LINE;
					end else if (write_stb) begin
						// setup data transfer
						spi_dc <= 1;
						spi_data <= data_in;
						state_r <= S_SEND_DATA;
					end
				end
				S_SET_START_LINE: begin
					// trigger sending start line command
					spi_data <= S_CMD_LINE_0;
					if (!spi_ready) begin		
						// spi driver goes busy, need to wait
						state_r <= S_START_LINE_WAIT;
					end
				end
				S_START_LINE_WAIT: begin
					// wait for set start line command to be sent out to display
					if (spi_ready) begin
						state_r <= S_SET_OFFSET_CMD;
					end
				end
				S_SET_OFFSET_CMD: begin
					spi_data <= S_CMD_OFFSET;
					if (!spi_ready) begin
						// spi driver goes busy, need to wait
						state_r <= S_OFFSET_CMD_WAIT;
					end
				end
				S_OFFSET_CMD_WAIT: begin
					spi_data <= 8'h00;						// prepare second byte of offset command
					if (spi_ready) begin
						state_r <= S_SEND_DATA;
					end
				end
				S_SEND_DATA: begin
					if (!spi_ready) begin
						// spi driver goes busy, need to wait
						state_r <= S_DATA_WAIT;
					end
				end
				S_DATA_WAIT: begin
					if (spi_ready) begin
						spi_dc <= 0;
						spi_data <= 8'h00;
						state_r <= S_IDLE;
					end
				end
			endcase
		end
	end

	assign spi_transmitt = 	(state_r == S_SET_START_LINE) || (state_r == S_SET_OFFSET_CMD) || 
							(state_r == S_SEND_DATA);
	assign spi_deactivate_cs = (state_r == S_SET_START_LINE) || (state_r == S_SEND_DATA);

    assign ready = state_r == S_IDLE;

endmodule
