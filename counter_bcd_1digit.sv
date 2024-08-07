`default_nettype none

module counter_bcd_1digit
(
    input clk_in,
    input reset_in,
    input enable_in,

    output reg [3:0] digit_out,
    output carry_out
);

always @(posedge clk_in) begin
    if (reset_in) begin
        digit_out <= 4'h0;
    end else if (enable_in) begin
        digit_out <= (digit_out == 9) ? 4'h0 : (digit_out + 1);
    end
end

assign carry_out = !reset_in && enable_in && (digit_out == 9);

endmodule
