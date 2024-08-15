`default_nettype none

module decoder_7seg_to_21x32pix
(
    input bit [6:0] segments_in,
    input bit dec_point_in,

    input bit [4:0] index_x_in,
    input bit [1:0] index_y_in,

    output bit [7:0] pixels_out
);

    localparam X_PIXELS = 21;
    localparam X_MIDDLE_POINT = X_PIXELS / 2;

    bit x_low, x_high, y_low, y_high;
    assign x_low = (index_x_in < X_MIDDLE_POINT);
    assign x_high = !x_low;
    assign y_high = index_y_in[1];
    assign y_low = !y_high;

    bit seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g;
    assign {seg_g, seg_f, seg_e, seg_d, seg_c, seg_b, seg_a} = segments_in;

    bit [2:0] x_rev_index;
    assign x_rev_index[2:0] = X_PIXELS - 2 - index_x_in;

    // index to get pixels from LUT, mirrored in X or Y or both
    reg [3:0] index_bcef;
    // LUT for 'b', 'c', 'e', 'f' segments definition
    reg [7:0] pattern_bcef;
    always_comb begin
        if (x_low && y_low && seg_f) begin
            // segment F
            index_bcef = {index_x_in[2:0], index_y_in[0]};
        end 
        else if (x_low && y_high && seg_e) begin
            // segment E
            index_bcef = {index_x_in[2:0], !index_y_in[0]};
        end
        else if (x_high && y_low && seg_b) begin
            // segment B
            index_bcef = {x_rev_index[2:0], index_y_in[0]};
        end
        else if (x_high && y_high && seg_c) begin
            // segment C
            index_bcef = {x_rev_index[2:0], !index_y_in[0]};
        end
        else begin
            index_bcef = 0;         // blank
        end

        case (index_bcef)
            'h00: pattern_bcef = 8'h00;
            'h01: pattern_bcef = 8'h00;     
            'h02: pattern_bcef = 8'h00;
            'h03: pattern_bcef = 8'h00;     
            'h04: pattern_bcef = 8'hf0;
            'h05: pattern_bcef = 8'h3f;
            'h06: pattern_bcef = 8'hf8;
            'h07: pattern_bcef = 8'h7f;
            'h08: pattern_bcef = 8'hf0;
            'h09: pattern_bcef = 8'h3f;
            'h0a: pattern_bcef = 8'he0;
            'h0b: pattern_bcef = 8'h1f;
            'h0c: pattern_bcef = 8'h00;
            'h0d: pattern_bcef = 8'h00;     
            'h0e: pattern_bcef = 8'h00;
            'h0f: pattern_bcef = 8'h00; 
        endcase
    end

    // LUT for 'a', 'd', 'g' segments definition
    // 'a' and 'd' segments are packed with 'g' segments in one LUT to save some space
    localparam ad_mask = 8'h1f;
    localparam g_mask = 8'hc0;
    reg [7:0] pattern_adg;
    always_comb begin
        case (index_x_in)
            //                   A/D  |  G
            'h00: pattern_adg = 8'h00;
            'h01: pattern_adg = 8'h00;
            'h02: pattern_adg = 8'h00;
            'h03: pattern_adg = 8'h00;
            'h04: pattern_adg = 8'h02;
            'h05: pattern_adg = 8'h06 | 8'h80;
            'h06: pattern_adg = 8'h0e | 8'hc0;
            'h07: pattern_adg = 8'h1e | 8'hc0;
            'h08: pattern_adg = 8'h1e | 8'hc0;
            'h09: pattern_adg = 8'h1e | 8'hc0;
            'h0a: pattern_adg = 8'h1e | 8'hc0;
            'h0b: pattern_adg = 8'h1e | 8'hc0;
            'h0c: pattern_adg = 8'h1e | 8'hc0;
            'h0d: pattern_adg = 8'h0e | 8'hc0;
            'h0e: pattern_adg = 8'h06 | 8'h80;
            'h0f: pattern_adg = 8'h02;
            'h10: pattern_adg = 8'h00;
            'h11: pattern_adg = 8'h00;
            'h12: pattern_adg = 8'h00;
            'h13: pattern_adg = 8'h00;
            default: pattern_adg = 8'h00;
        endcase
    end

    function automatic bit [7:0] reverse_8bits(input bit [7:0] in);
        reverse_8bits[7:0] = {in[0], in[1], in[2], in[3], in[4], in[5], in[6], in[7]};
    endfunction

    wire [7:0] pixels_segA;
    wire [7:0] pixels_segD;
    wire [7:0] pixels_segG;
    wire [7:0] pixels_segBCEF;

    assign pixels_segA = (seg_a && (index_x_in < X_PIXELS) && (index_y_in == 0)) ? 
                        (ad_mask & pattern_adg) : 
                        8'h00;

    assign pixels_segD = (seg_d && (index_x_in < X_PIXELS) && (index_y_in == 3)) ? 
                        reverse_8bits(ad_mask & pattern_adg) : 
                        8'h00;

    assign pixels_segG = !(seg_g && (index_x_in < X_PIXELS)) ? 8'h00 :
                        (index_y_in == 1) ? g_mask & pattern_adg :
                        (index_y_in == 2) ? reverse_8bits(g_mask & pattern_adg) :
                        8'h00;

    assign pixels_segBCEF = y_high ? reverse_8bits(pattern_bcef) : pattern_bcef;

    localparam pattern_dp = 8'he0;
    wire [7:0] pixels_segDP;

    assign pixels_segDP = (dec_point_in && (index_x_in < X_PIXELS) && (index_x_in > X_PIXELS - 3) && (index_y_in == 3)) ? 
                        pattern_dp : 
                        8'h00;

    assign pixels_out = pixels_segA | pixels_segD | pixels_segG | pixels_segBCEF | pixels_segDP;

endmodule
