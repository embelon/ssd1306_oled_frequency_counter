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

always @(posedge clk_in) begin
    if (reset) begin
        busy_r <= 1'b0;
        first_reset_r <= 1'b0;
        vbat_on_r <= 1'b1;
        rom_index_r <= 0;
    end else begin
        if (!busy_r) begin            
            busy_r <= 1'b1;
        end 
        if (busy_r && command_ready) begin
            rom_index_r <= rom_index_r + 1;
        end
        if (busy_r && rom_last) begin
            busy_r <= 1'b0;
        end
        if (first_reset_r) begin
            first_reset_r <= 1'b0;
            vbat_on_r <= 1'b0;
        end
    end
end

assign done = !busy_r;

assign oled_rstn = !reset;

assign oled_vbatn = !vbat_on_r;

assign oled_csn = command_ready;

assign command_out = rom_data[7:0];

assign command_start = busy_r;

endmodule
