`default_nettype none

module shift_reg 
#(
	parameter WIDTH = 8
)
(
    input clk_in,
    input start,
    input [WIDTH-1:0] data_in,

    output ready,
    output [WIDTH-1:0] data_out,

    output clk_out,
    output serial_out,
    input serial_in
);

parameter BIT_COUNT_WIDTH = $clog2(WIDTH+1);

reg [WIDTH-1:0] shadow_reg = 0;
reg [BIT_COUNT_WIDTH-1:0] bit_counter = 0;

assign ready = !|bit_counter;

always @(posedge clk_in) begin
    if (ready & start) begin
        shadow_reg <= data_in;
        bit_counter <= bit_counter + 1;
    end
    if (!ready) begin
        shadow_reg <= {shadow_reg[WIDTH-2:0], serial_in};
        bit_counter <= bit_counter + 1;
    end
    if (bit_counter == WIDTH) begin
        bit_counter <= 0;
    end
end

assign clk_out = !clk_in & !ready;
assign serial_out = shadow_reg[WIDTH-1];

assign data_out = ready ? shadow_reg : 0;

endmodule
