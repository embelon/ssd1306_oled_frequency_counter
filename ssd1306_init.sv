`default_nettype none

module ssd1306_init
(
    input clk_in,
    input reset,        // also triggers init / reinit

    output done,        // done goes 1 when init sequence finished
    
    // signals to control shift register
    output command_start,    
    output [7:0] command_out,
    input command_ready,

    // IO controlled by init module directly
    output oled_rstn,
    output oled_vbatn,
    output oled_csn,
    output oled_dc
);

reg [4:0] rom_index = 4'h00;
wire [8:0] rom_data;
wire rom_last;

ssd1306_init_rom rom
(
    .address(rom_index),
    .data(rom_data),
    .last(rom_last)
);

reg busy = 1'b0;
reg first_reset = 1'b1;
reg vbat_on = 1'b0;

always @(posedge clk_in) begin
    if (reset) begin
        busy <= 1'b0;
        rom_index <= 0;
    end else begin
        if (!busy) begin            
            busy <= 1'b1;
        end 
        if (busy && command_ready) begin
            rom_index <= rom_index + 1;
        end
        if (busy && rom_last) begin
            busy <= 1'b0;
        end
        if (first_reset) begin
            first_reset <= 1'b0;
            vbat_on <= 1'b0;
        end
    end
end

assign done = !busy;

assign oled_rstn = !reset;

assign oled_vbatn = !vbat_on;

assign oled_csn = command_ready;

assign command_out = rom_data[7:0];

assign command_start = busy;

endmodule
