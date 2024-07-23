`default_nettype none

module ssd1306_init
(
    input clk_in,
    input reset_in,     // also triggers init / reinit

    output done,        // done goes 1 when init sequence finished
    
    // signals to control shift register
    output command_start,    
    output [7:0] command_out,
    output command_last_byte,
    input command_ready,

    // IO controlled by init module directly
    output reg oled_rstn,
    output reg oled_vbatn,
    output oled_dc
);

parameter ROM_ADDRESS_WIDTH = 5;
parameter ROM_DATA_WIDTH = 10;

reg [ROM_ADDRESS_WIDTH-1:0] rom_index_r;
wire [ROM_DATA_WIDTH-1:0] rom_data;

ssd1306_init_rom #(.DATA_WIDTH(ROM_DATA_WIDTH)) rom
(
    .address(rom_index_r),
    .data(rom_data),
    .address_overflow()
);

// opcodes for local commands (not sent to SSD1306)
parameter CMD_SET_RESET = 4'b0001, CMD_SET_VBAT = 4'b0010, CMD_DELAY = 4'b0011, CMD_STOP = 4'b1111;

wire command_last_byte;
wire command_interpreted;
wire [3:0] local_command;
wire [3:0] local_cmd_data;

assign command_out = rom_data[7:0];
assign command_last_byte = rom_data[8];
assign command_interpreted = rom_data[9];
assign local_command = rom_data[7:4];
assign local_cmd_data = rom_data[3:0];

reg [16:0] delay_cnt;

parameter S_RESET = 0, S_IDLE = 1, S_FETCH_EXECUTE = 2, S_DELAY = 3, S_SEND = 4, S_WAIT = 5, S_RETIRE = 6, S_DONE = 7;
reg [3:0] state_r;

always @(posedge clk_in) begin
    if (reset_in) begin
        oled_rstn <= 1'b0;
        oled_vbatn <= 1'b1;
        rom_index_r <= 0;
        delay_cnt <= 0;
        state_r <= S_RESET;        
    end else begin
        case (state_r)
            S_RESET: begin
                oled_rstn <= 1'b0;
                rom_index_r <= 0;
                delay_cnt <= 0;
                state_r <= S_IDLE;
            end
            S_IDLE: begin
                if (command_ready) begin
                    state_r <= S_FETCH_EXECUTE;
                end
            end
            S_FETCH_EXECUTE: begin
                if (command_interpreted) begin
                    if (local_command == CMD_SET_RESET) begin
                        oled_rstn <= command_out[0];
                        state_r <= S_RETIRE;
                    end
                    if (local_command == CMD_SET_VBAT) begin
                        oled_vbatn <= command_out[0];
                        state_r <= S_RETIRE;
                    end
                    if (local_command == CMD_DELAY) begin
                        delay_cnt <= {local_cmd_data, 13'h0000};
                        state_r <= S_DELAY;
                    end
                    if (local_command == CMD_STOP) begin
                        state_r <= S_DONE;
                    end
                end else begin
                    state_r <= S_SEND;
                end
            end
            S_DELAY: begin
                if (!|delay_cnt) begin
                    state_r <= S_RETIRE;
                end
                delay_cnt <= delay_cnt - 1;
            end
            S_SEND: begin
                if (!command_ready) begin
                    state_r <= S_WAIT;                    
                end
            end
            S_WAIT: begin
                if (command_ready) begin
                    state_r <= S_RETIRE;
                end
            end
            S_RETIRE: begin
                rom_index_r <= rom_index_r + 1;         // prepare next command address
                state_r <= S_FETCH_EXECUTE;
            end
            S_DONE: begin
            end
        endcase
    end
end

assign done = (state_r == S_DONE);

assign command_start = (state_r == S_SEND);

assign oled_dc = 1'b0;

endmodule
