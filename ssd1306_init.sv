`default_nettype none

module ssd1306_init
#(
    parameter ssd1306_init_file = "ssd1306_init_sequence.mif"
)
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

// ROM memory for init commands
reg [7:0] commands[0:3];
initial begin
    $readmemh(ssd1306_init_file, commands);
end

reg first_reset = 1'b1;
reg vbat_on = 1'b0;

reg [7:0] command_index = 8'h00;

always @(posedge clk_in) begin
    if (reset) begin
        if (first_reset) begin
            first_reset <= 1'b0;
            vbat_on <= 1'b0;
        end
        command_index <= command_index + 1;
    end
end

assign oled_rstn = !reset;

assign oled_vbatn = !vbat_on;

assign oled_csn = command_ready;

assign command_out = commands[command_index];

assign command_start = reset;

endmodule
