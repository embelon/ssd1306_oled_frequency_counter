`default_nettype none

typedef struct packed
{
    bit [3:0] value;
} Digit;

module counter_bcd_Ndigits
#(
    parameter DIGITS_NUM = 6
)
(
    input clk_in,
    input reset_in,
    input enable_in,

    output Digit [DIGITS_NUM-1:0] digits, 
    output carry_out
);

wire [DIGITS_NUM-1:0] carry;

counter_bcd_1digit digit_0
(
    .clk_in(clk_in),
    .reset_in(reset_in),
    .enable_in(enable_in),

    .digit(digits[0]),
    .carry_out(carry[0])
);

genvar g;
generate 
    for (g = 1; g < DIGITS_NUM; g++) begin
        counter_bcd_1digit digit_x
        (
            .clk_in(clk_in),
            .reset_in(reset_in),
            .enable_in(carry[g]),

            .digit(digits[g]),
            .carry_out(carry[g])
        );
    end
endgenerate

assign carry_out = carry[DIGITS_NUM-1];

endmodule
