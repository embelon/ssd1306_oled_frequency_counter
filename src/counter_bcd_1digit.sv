`default_nettype none

module counter_bcd_1digit
(
    input bit clk_in,
    input bit reset_in,

    input bit enable_in,
    input bit carry_in,

    output reg [3:0] digit_out,
    output bit carry_out
);

always @(posedge clk_in) begin
    if (reset_in) begin
        digit_out <= 4'h0;
    end else if (enable_in && carry_in) begin
        digit_out <= (digit_out == 9) ? 4'h0 : (digit_out + 1);
    end
end

assign carry_out = !reset_in && carry_in && (digit_out == 9);

endmodule
