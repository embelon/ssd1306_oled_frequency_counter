`default_nettype none

typedef struct packed {
    bit g;
    bit f;
    bit e;
    bit d;
    bit c;
    bit b;
    bit a;
} IndividualSegments;

typedef union packed {
    bit [6:0] binary;
    IndividualSegments individual;
} Segments;

module decoder_bin_to_7seg
(
    input [3:0] digit,
    output Segments segments
);

always @(*) begin
    //                                  {g, f, e, d, c, b, a}
    case (digit)
        4'd00 :   segments.individual = {0, 1, 1, 1, 1, 1, 1};
        4'd01 :   segments.individual = {0, 0, 0, 0, 1, 1, 0};
        4'd02 :   segments.individual = {1, 0, 1, 1, 0, 1, 1};
        4'd03 :   segments.individual = {1, 0, 0, 1, 1, 1, 0};
        4'd04 :   segments.individual = {0, 1, 0, 1, 1, 0, 0};
        4'd05 :   segments.individual = {1, 1, 0, 1, 1, 0, 1};
        4'd06 :   segments.individual = {1, 1, 1, 1, 1, 0, 1};
        4'd07 :   segments.individual = {0, 0, 0, 0, 1, 1, 1};
        4'd08 :   segments.individual = {1, 1, 1, 1, 1, 1, 1};
        4'd09 :   segments.individual = {1, 1, 0, 1, 1, 1, 1};
        4'h0a :   segments.individual = {1, 1, 1, 0, 1, 1, 1};
        4'h0b :   segments.individual = {1, 1, 1, 1, 1, 0, 0};
        4'h0c :   segments.individual = {1, 0, 1, 1, 0, 1, 0};
        4'h0d :   segments.individual = {1, 0, 1, 1, 1, 1, 0};
        4'h0e :   segments.individual = {1, 1, 1, 1, 0, 0, 1};
        4'h0f :   segments.individual = {1, 1, 1, 0, 0, 0, 1};
    endcase
end

endmodule
