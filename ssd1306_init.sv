`default_nettype none

module ssd1306_init
(
    input clk_in,
    input reset,        // also triggers init / reinit

    output done,        // done goes 1 when init sequence finished
    
    // signals to control shift register
    output command_start,    
    output [7:0] command_out,
    output command_last_byte,
    input command_ready,

    // IO controlled by init module directly
    output oled_rstn,
    output oled_vbatn,
    output oled_dc
);

reg [4:0] rom_index_r;
wire [8:0] rom_data;
wire rom_last;

ssd1306_init_rom rom
(
    .address(rom_index_r),
    .data(rom_data),
    .last(rom_last)
);

reg busy_r;
reg first_reset_r;
reg vbat_on_r;

parameter S_RESET = 0, S_IDLE = 1, S_SEND = 2, S_WAIT = 3, S_DONE = 4;
reg [2:0] state_r;

always @(posedge clk_in) begin
    if (reset) begin
        first_reset_r <= 1'b0;
        vbat_on_r <= 1'b1;
        rom_index_r <= 0;
        state_r <= S_RESET;        
    end else begin
        case (state_r)
            S_RESET: begin
                rom_index_r <= 0;
                state_r <= S_IDLE;
            end
            S_IDLE: begin
                if (command_ready) begin
                    state_r <= S_SEND;
                end
            end
            S_SEND: begin
                if (!command_ready) begin
                    state_r <= S_WAIT;
                    rom_index_r <= rom_index_r + 1;         // prepare next command address
                end
            end
            S_WAIT: begin
                if (command_ready) begin
                    if (|rom_data) begin
                        state_r <= S_SEND;
                    end else begin
                        state_r <= S_DONE;
                    end
                end
            end
            S_DONE: begin
            end

        endcase
    end
end

assign done = (state_r == S_DONE);

assign oled_rstn = !reset;

assign oled_vbatn = !vbat_on_r;

assign command_out = rom_data[7:0];
assign command_last_byte = rom_data[8];

assign command_start = (state_r == S_SEND);

endmodule
