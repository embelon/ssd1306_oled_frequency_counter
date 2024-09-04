`default_nettype none

module ssd1306_microcode_exec
#(
    parameter MICROCODE_SIZE = 48,
    localparam MICROCODE_ADDRESS_BITS = $clog2(MICROCODE_SIZE)
)
(
    input bit clk_in,
    input bit reset_in,         // triggers only internal reset (without init procedure)

    // interface to control microcode
    input bit [MICROCODE_ADDRESS_BITS-1:0] procedure_offset_in,    // microcode procedure offset
    input bit procedure_start_in,                                  // 1 -> triggers procedure execution
    output bit procedure_done_out,                                 // goes 1 when procedure is finished
    
    // interface to control SPI shift register
    output bit spi_tx_trigger_out,    
    output bit [7:0] spi_data_out,
    output bit spi_last_byte_out,
    input bit spi_ready_in,

    // IO controlled by init module directly
    output reg oled_rstn_out,
    output reg oled_vbatn_out,
    output reg oled_vcdn_out,
    output reg oled_dc_out
);

localparam ROM_DATA_WIDTH = 10;

reg [MICROCODE_ADDRESS_BITS-1:0] rom_index_r;
wire [ROM_DATA_WIDTH-1:0] rom_data;

ssd1306_microcode_rom 
#(
    .SIZE(MICROCODE_SIZE), 
    .DATA_WIDTH(ROM_DATA_WIDTH)
) microcode_rom
(
    .address(rom_index_r),
    .data(rom_data),
    .address_overflow()
);

// opcodes for local commands (not sent to SSD1306)
// GOTO is 8'b1yyy_yyyy, where y is 7 bit absolute address
wire cmd_goto;
wire [6:0] cmd_goto_address;
assign cmd_goto = rom_data[7];
assign cmd_goto_address = rom_data[6:0] - 1;

// DELAY is 8'b01yy_yyyy, where y is 6 bit delay
localparam CMD_DELAY_CODE   = 8'b0100_0000;
localparam CMD_DELAY_MASK   = 8'b1100_0000;
wire cmd_delay;
wire [5:0] cmd_delay_value;
assign cmd_delay = (rom_data[7:0] & CMD_DELAY_MASK) == CMD_DELAY_CODE;
assign cmd_delay_value = rom_data[5:0];

// SET_PIN is 8'b0010_pp0s, where:
// pp[1:0] is pin to be altered, 00 -> oled_resetn, 01 -> oled_vbatn, 10 -> oled_vcdn, 11 -> oled_dc
// s[0:0] is state to be set
localparam CMD_SET_PIN_CODE = 8'b0010_0000;
localparam CMD_SET_PIN_MASK = 8'b1111_0000;
wire cmd_set_pin;
assign cmd_set_pin = (rom_data[7:0] & CMD_SET_PIN_MASK) == CMD_SET_PIN_CODE;
localparam RESET_PIN = 2'b00, VBATN_PIN = 2'b01, VCDN_PIN = 2'b10, DC_PIN = 2'b11;
wire [1:0] pin_index;
assign pin_index = rom_data[3:2];
wire pin_state;
assign pin_state = rom_data[0];

// STOP is 8'b0000_00001
localparam CMD_STOP_CODE    = 8'b0000_0001;
localparam CMD_STOP_MASK    = 8'b1111_1111;
wire cmd_stop;
assign cmd_stop = (rom_data[7:0] & CMD_STOP_MASK) == CMD_STOP_CODE;

// NOP is 8'b0000_0000
localparam CMD_NOP_CODE     = 8'b0000_0000;
localparam CMD_NOP_MASK     = 8'b1111_1111;
wire cmd_nop;
assign cmd_nop = (rom_data[7:0] & CMD_NOP_MASK) == CMD_NOP_CODE;

wire command_interpreted;

assign spi_data_out = rom_data[7:0];
assign spi_last_byte_out = rom_data[8];
assign command_interpreted = rom_data[9];

reg [16:0] delay_cnt;

typedef enum {S_RESET, S_IDLE, S_FETCH_EXECUTE, S_DELAY, S_SEND, S_WAIT, S_RETIRE} e_state;
e_state state_r;

always @(posedge clk_in) begin
    if (reset_in) begin
        oled_rstn_out <= 1'b0;
        oled_vbatn_out <= 1'b1;
        oled_vcdn_out <= 1'b1;
        oled_dc_out <= 1'b0;
        rom_index_r <= 0;
        delay_cnt <= 0;
        state_r <= S_RESET;        
    end else begin
        case (state_r)
            S_RESET: begin
                oled_rstn_out <= 1'b0;
                rom_index_r <= 0;
                delay_cnt <= 0;
                state_r <= S_IDLE;                
            end
            S_IDLE: begin
                if (spi_ready_in && procedure_start_in) begin
                    rom_index_r <= procedure_offset_in;
                    state_r <= S_FETCH_EXECUTE;
                end
            end                    
            S_FETCH_EXECUTE: begin
                if (command_interpreted) begin
                    if (cmd_goto) begin
                        if (cmd_goto_address < MICROCODE_SIZE) begin
                            rom_index_r <= cmd_goto_address[MICROCODE_ADDRESS_BITS-1:0];    
                        end
                        state_r <= S_RETIRE;
                    end else if (cmd_delay) begin
                        delay_cnt <= {cmd_delay_value, 11'h000};
                        state_r <= S_DELAY;
                    end else if (cmd_set_pin) begin
                        case (pin_index)
                            RESET_PIN: begin oled_rstn_out <= pin_state; end
                            VBATN_PIN: begin oled_vbatn_out <= pin_state; end
                            VCDN_PIN: begin oled_vcdn_out <= pin_state; end
                            DC_PIN: begin oled_dc_out <= pin_state; end
                        endcase
                        state_r <= S_RETIRE;
                    end else if (cmd_stop) begin
                        state_r <= S_IDLE;
                    end else if (cmd_nop) begin
                        state_r <= S_RETIRE;
                    end
                end else begin
                    state_r <= S_SEND;
                end
            end
            S_DELAY: begin
                if (!(|delay_cnt)) begin
                    state_r <= S_RETIRE;
                end
                delay_cnt <= delay_cnt - 1;
            end
            S_SEND: begin
                if (!spi_ready_in) begin
                    state_r <= S_WAIT;                    
                end
            end
            S_WAIT: begin
                if (spi_ready_in) begin
                    state_r <= S_RETIRE;
                end
            end
            S_RETIRE: begin
                if (rom_index_r < MICROCODE_SIZE) begin
                    rom_index_r <= rom_index_r + 1;         // prepare next command address
                    state_r <= S_FETCH_EXECUTE;
                end else begin
                    state_r <= S_IDLE;
                end
            end
        endcase
    end
end

assign procedure_done_out = (state_r == S_IDLE);

assign spi_tx_trigger_out = (state_r == S_SEND);

endmodule
