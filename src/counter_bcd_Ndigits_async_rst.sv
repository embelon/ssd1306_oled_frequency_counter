`default_nettype none

module counter_bcd_Ndigits_async_rst
#(
    parameter DIGITS_NUM = 6
)
(
    input bit clk_in,

    input bit reset_in,
    input bit enable_in,

    output bit [4*DIGITS_NUM-1:0] digits_out, 
    output bit carry_out
);

wire [DIGITS_NUM-1:0] carry;

counter_bcd_1digit_async_rst digit_0
(
    .clk_in(clk_in),
    .reset_in(reset_in),

    .enable_in(enable_in),
    .carry_in(1'b1),

    .digit_out(digits_out[3:0]),
    .carry_out(carry[0])
);

genvar g;
generate 
    for (g = 1; g < DIGITS_NUM; g++) begin
        counter_bcd_1digit_async_rst digit_x
        (
            .clk_in(clk_in),
            .reset_in(reset_in),

            .enable_in(enable_in),
            .carry_in(carry[g-1]),

            .digit_out(digits_out[4*g+3:4*g]),
            .carry_out(carry[g])
        );
    end
endgenerate

assign carry_out = carry[DIGITS_NUM-1];

endmodule
