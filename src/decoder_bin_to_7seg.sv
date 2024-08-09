`default_nettype none

module decoder_bin_to_7seg
(
    input logic [3:0] digit_in,
    output logic [6:0] segments_out
);

always_comb begin
    //                     {g, f, e, d, c, b, a}
    case (digit_in)
        4'd00 :   segments_out = 7'b0111111;
        4'd01 :   segments_out = 7'b0000110;
        4'd02 :   segments_out = 7'b1011011;
        4'd03 :   segments_out = 7'b1001111;
        4'd04 :   segments_out = 7'b1100110;
        4'd05 :   segments_out = 7'b1101101;
        4'd06 :   segments_out = 7'b1111101;
        4'd07 :   segments_out = 7'b0000111;
        4'd08 :   segments_out = 7'b1111111;
        4'd09 :   segments_out = 7'b1101111;
        4'h0a :   segments_out = 7'b1110111;
        4'h0b :   segments_out = 7'b1111100;
        4'h0c :   segments_out = 7'b0111001;
        4'h0d :   segments_out = 7'b1011110;
        4'h0e :   segments_out = 7'b1111001;
        4'h0f :   segments_out = 7'b1110001;
    endcase
end

endmodule
