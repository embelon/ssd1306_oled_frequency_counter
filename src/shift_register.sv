`default_nettype none

module shift_register
#(
	parameter WIDTH = 8
)
(
    input bit clk_in,
    input bit reset_in,

    input bit start_in,
    input bit [WIDTH-1:0] data_in,

    output bit ready_out,
    output bit [WIDTH-1:0] data_out,

    output bit clk_out,
    output bit serial_out,
    input bit serial_in
);

localparam BIT_COUNT_WIDTH = $clog2(WIDTH+1);

reg [WIDTH-1:0] shadow_reg_r;
reg [BIT_COUNT_WIDTH-1:0] bit_counter_r;

assign ready_out = !(|bit_counter_r) & !reset_in;

always @(posedge clk_in) begin
    if (reset_in) begin
        shadow_reg_r <= 0;
        bit_counter_r <= 0;
    end else begin
        if (ready_out & start_in) begin
            shadow_reg_r <= data_in;
            bit_counter_r <= bit_counter_r + 1;
        end
        if (!ready_out) begin
            shadow_reg_r <= {shadow_reg_r[WIDTH-2:0], serial_in};
            bit_counter_r <= bit_counter_r + 1;
        end
        if (bit_counter_r == WIDTH) begin
            bit_counter_r <= 0;
        end
    end
end

assign clk_out = !clk_in & !ready_out & !reset_in;
assign serial_out = shadow_reg_r[WIDTH-1];

assign data_out = ready_out ? shadow_reg_r : 0;

endmodule
