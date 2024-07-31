`default_nettype none

module counter_bcd_1digit
(
    input clk_in,
    input reset_in,
    input enable_in,

    output reg [3:0] digit,
    output carry_out
);

always @(posedge clk_in) begin
    if (reset_in) begin
        digit <= 4'h0;
    end else if (enable_in) begin
        digit <= (digit == 9) ? 4'h0 : (digit + 1);
    end
end

assign carry_out = !reset_in && enable_in && (digit == 9);

endmodule
