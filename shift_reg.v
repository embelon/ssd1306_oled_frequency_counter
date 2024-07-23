`default_nettype none

module shift_reg 
#(
	parameter WIDTH = 8
)
(
    input clk_in,
    input reset,

    input start,
    input [WIDTH-1:0] data_in,

    output ready,
    output [WIDTH-1:0] data_out,

    output clk_out,
    output serial_out,
    input serial_in
);

parameter BIT_COUNT_WIDTH = $clog2(WIDTH+1);

reg [WIDTH-1:0] shadow_reg_r;
reg [BIT_COUNT_WIDTH-1:0] bit_counter_r;

assign ready = !|bit_counter_r;

always @(posedge clk_in) begin
    if (reset) begin
        shadow_reg_r <= 0;
        bit_counter_r <= 0;
    end else begin
        if (ready & start) begin
            shadow_reg_r <= data_in;
            bit_counter_r <= bit_counter_r + 1;
        end
        if (!ready) begin
            shadow_reg_r <= {shadow_reg_r[WIDTH-2:0], serial_in};
            bit_counter_r <= bit_counter_r + 1;
        end
        if (bit_counter_r == WIDTH) begin
            bit_counter_r <= 0;
        end
    end
end

assign clk_out = !clk_in & !ready;
assign serial_out = shadow_reg_r[WIDTH-1];

assign data_out = ready ? shadow_reg_r : 0;

endmodule
