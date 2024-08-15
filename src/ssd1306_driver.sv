`default_nettype none

module ssd1306_driver
(
    input bit clk_in,
    input bit reset_in,     // triggers init / reinit
    
	// data / command interface
    input bit [7:0] data_in,
    input bit write_stb_in,		// send data from data_in to lcd
	input bit sync_stb_in,		// send commands to go back to (0,0)
    output bit ready_out,       // driver is ready for data / command

	// output signals controlling OLED (connected to pins)
	output bit oled_rstn_out,
	output bit oled_vbatn_out,	
	output bit oled_vcdn_out,
	output bit oled_csn_out,
	output bit oled_dc_out,
	output bit oled_clk_out,
	output bit oled_mosi_out
);

	// Internal signals
	reg [7:0] spi_data;
	wire spi_tx_start;			// triggers transmission
	wire spi_deactivate_cs; 	// deactivate cs after current byte

	// Signals coming from microcode executor module
	wire mc_executor_spi_tx_start;
	wire [7:0] mc_executor_spi_data;
	wire mc_executor_deactivate_cs;
	wire mc_executor_dc_pin;
	wire mc_executor_ready;

	// Signals going to spi driver (MUXed)	
	wire [7:0] spi_driver_data_in;
	wire spi_driver_tx_start;
	wire spi_driver_deactivate_cs;
	// When procedure is finished (done = 1), then signals comming from microcode executor module 
	// are disconnected from spi driver
	assign spi_driver_data_in = mc_executor_ready ? spi_data : mc_executor_spi_data;
	assign spi_driver_tx_start = mc_executor_ready ? spi_tx_start : mc_executor_spi_tx_start;
	assign spi_driver_deactivate_cs = mc_executor_ready ? spi_deactivate_cs : mc_executor_deactivate_cs;

	// When procedure is finished (done = 1), then dc is controlled locally (1 -> data only)
	assign oled_dc_out = mc_executor_ready ? 1'b1 : mc_executor_dc_pin;

	// Signals coming from spi driver
	wire spi_driver_ready;

	// microcode offset for init sequence
	localparam S_CMD_INIT_MC_OFFSET = 0;
	// microcode offset for sequence to get dislpay back to (0,0)
	localparam S_CMD_SYNC_MC_OFFSET = 33;

	localparam MICROCODE_SIZE = 44;
	localparam MICROCODE_OFFSET_BITS = $clog2(MICROCODE_SIZE);
	reg [MICROCODE_OFFSET_BITS-1:0] mc_procedure_offset;
	wire mc_procedure_start;

	ssd1306_microcode_exec 
	#( .MICROCODE_SIZE(MICROCODE_SIZE) )
	mc_exec (
    	.clk_in(clk_in),
    	.reset_in(reset_in),        				// triggers only internal reset (wihtout init sequence)

		// interface to control microcode
		.procedure_offset_in(mc_procedure_offset),		// microcode procedure offset
		.procedure_start_in(mc_procedure_start),		// 1 -> triggers procedure execution
    	.procedure_done_out(mc_executor_ready),      	// goes 1 when procedure is finished
    
    	// interface to control SPI shift register
    	.spi_tx_trigger_out(mc_executor_spi_tx_start),
    	.spi_data_out(mc_executor_spi_data),
		.spi_last_byte_out(mc_executor_deactivate_cs),
    	.spi_ready_in(spi_driver_ready),

    	// IO controlled by init module directly
    	.oled_rstn_out(oled_rstn_out),
    	.oled_vbatn_out(oled_vbatn_out),
		.oled_vcdn_out(oled_vcdn_out),
    	.oled_dc_out(mc_executor_dc_pin)
	);

	spi spi_driver (
		.clk_in(clk_in),
		.reset_in(reset_in),

    	.tx_start_in(spi_driver_tx_start),
		.deactivate_cs_in(spi_driver_deactivate_cs),
    	.data_in(spi_driver_data_in),
    	.data_out(),
    	.tx_done_out(spi_driver_ready),

		.select_out(oled_csn_out),
		.sck_out(oled_clk_out),
		.mosi_out(oled_mosi_out),
		.miso_in(1'b0)
	);

	// state machine definition
	// S_RESET_WAIT -> wait for all blocks to become ready after reset
	typedef enum {S_RESET_WAIT, S_MC_EXEC, S_MC_WAIT, S_IDLE, S_SEND_DATA, S_DATA_WAIT} e_state;
	e_state state_r;

	always @(posedge clk_in) begin
		if (reset_in) begin
			mc_procedure_offset <= 0;
			spi_data <= 8'h00;
			state_r <= S_RESET_WAIT;
		end else begin
			case (state_r)
			 	S_RESET_WAIT: begin
					mc_procedure_offset <= 0;
					spi_data <= 8'h00;
					if (mc_executor_ready && spi_driver_ready) begin
						mc_procedure_offset <= S_CMD_INIT_MC_OFFSET;
						state_r <= S_MC_EXEC;
					end
				end
				S_MC_EXEC: begin
					if (!mc_executor_ready) begin
						state_r <= S_MC_WAIT;
					end
				end
				S_MC_WAIT: begin
					if (mc_executor_ready) begin
						state_r <= S_IDLE;
					end
				end
				S_IDLE: begin
					if (sync_stb_in) begin
						// start sync command sequence
						mc_procedure_offset <= S_CMD_SYNC_MC_OFFSET;
						state_r <= S_MC_EXEC;
					end else if (write_stb_in) begin
						// setup data transfer
						spi_data <= data_in;
						state_r <= S_SEND_DATA;
					end
				end
				S_SEND_DATA: begin
					if (!spi_driver_ready) begin
						// spi driver goes busy, need to wait
						state_r <= S_DATA_WAIT;
					end
				end
				S_DATA_WAIT: begin
					if (spi_driver_ready) begin
						spi_data <= 8'h00;
						state_r <= S_IDLE;
					end
				end
			endcase
		end
	end

	assign mc_procedure_start = (state_r == S_MC_EXEC);

	assign spi_tx_start = 	(state_r == S_SEND_DATA);
	assign spi_deactivate_cs = (state_r == S_SEND_DATA);

    assign ready_out = (state_r == S_IDLE);

endmodule
