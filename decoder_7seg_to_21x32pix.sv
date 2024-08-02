`default_nettype none

module decoder_7seg_to_21x32pix
(
    input Segments segments_in,

    input [4:0] index_x,
    input [1:0] index_y,

    output [7:0] pixels
);

    localparam X_PIXELS = 21;
    localparam X_MIDDLE_POINT = X_PIXELS / 2;

    bit x_low, x_high, y_low, y_high;
    assign x_low = (index_x < X_MIDDLE_POINT);
    assign x_high = !x_low;
    assign y_high = index_y[1];
    assign y_low = !y_high;

    bit [2:0] x_back_index;
    assign x_back_index = X_PIXELS - 1 - index_x;

    // index to get pixels from LUT, mirrored in X or Y or both
    reg [3:0] index_bcef;
    // LUT for 'b', 'c', 'e', 'f' segments definition
    reg [7:0] pattern_bcef;
    always @* begin
        if (x_low && y_low && segments_in.individual.f) begin
            // segment F
            index_bcef = {index_x[2:0], index_y[0]};
        end 
        else if (x_low && y_high && segments_in.individual.e) begin
            // segment E
            index_bcef = {index_x[2:0], !index_y[0]};
        end
        else if (x_high && y_low && segments_in.individual.b) begin
            // segment B
            index_bcef = {x_back_index[2:0], index_y[0]};
        end
        else if (x_high && y_high && segments_in.individual.c) begin
            // segment C
            index_bcef = {x_back_index[2:0], !index_y[0]};
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
            'h05: pattern_bcef = 8'hfc;
            'h06: pattern_bcef = 8'h1f;
            'h07: pattern_bcef = 8'hfe;
            'h08: pattern_bcef = 8'h0f;
            'h09: pattern_bcef = 8'hfc;
            'h0a: pattern_bcef = 8'h07;
            'h0b: pattern_bcef = 8'hf8;
            'h0c: pattern_bcef = 8'h00;
            'h0d: pattern_bcef = 8'h00;     
            'h0e: pattern_bcef = 8'h00;
            'h0f: pattern_bcef = 8'h00; 
        endcase
    end

    // LUT for 'a', 'd', 'g' segments definition
    // 'a' and 'd' segments are packed with 'g' segments in one LUT to save some space
    parameter ad_mask = 8'hf8;
    parameter g_mask = 8'h03;
    reg [7:0] pattern_adg;
    always @* begin
        case (index_x)
            //                   A/D  |  G
            'h00: pattern_adg = 8'h00;
            'h01: pattern_adg = 8'h00;
            'h02: pattern_adg = 8'h00;
            'h03: pattern_adg = 8'h00;
            'h04: pattern_adg = 8'h40;
            'h05: pattern_adg = 8'h60 | 8'h01;
            'h06: pattern_adg = 8'h70 | 8'h03;
            'h07: pattern_adg = 8'h78 | 8'h03;
            'h08: pattern_adg = 8'h78 | 8'h03;
            'h09: pattern_adg = 8'h78 | 8'h03;
            'h0a: pattern_adg = 8'h78 | 8'h03;
            'h0b: pattern_adg = 8'h78 | 8'h03;
            'h0c: pattern_adg = 8'h78 | 8'h03;
            'h0d: pattern_adg = 8'h78 | 8'h03;
            'h0e: pattern_adg = 8'h70 | 8'h03;
            'h0f: pattern_adg = 8'h60 | 8'h01;
            'h10: pattern_adg = 8'h40;
            'h11: pattern_adg = 8'h00;
            'h12: pattern_adg = 8'h00;
            'h13: pattern_adg = 8'h00;
            'h14: pattern_adg = 8'h00;
            default: pattern_adg = 8'h00;
        endcase
    end

    function automatic bit [7:0] reverse_8bits(input bit [7:0] in);
        reverse_8bits = {in[0], in[1], in[2], in[3], in[4], in[5], in[6], in[7]};
    endfunction

    wire [7:0] pixels_segA, pixels_segD, pixels_segG;
    wire [7:0] pixels_segBCEF;

    assign pixels_segA = (segments_in.individual.a && (index_x < X_PIXELS) && (index_y == 0)) ? 
                        (ad_mask & pattern_adg) : 
                        8'h00;
    assign pixels_segD = (segments_in.individual.d && (index_x < X_PIXELS) && (index_y == 3)) ? 
                        ad_mask & reverse_8bits(pattern_adg) : 
                        8'h00;

    assign pixels_segG = !(segments_in.individual.g && (index_x < X_PIXELS)) ? 8'h00 :
                        (index_y == 1) ? g_mask & pattern_adg :
                        (index_y == 2) ? g_mask & reverse_8bits(pattern_adg) :
                        8'h00;

    assign pixels_segBCEF = y_high ? reverse_8bits(pattern_bcef) : pattern_bcef;

    assign pixels = pixels_segA || pixels_segD || pixels_segG || pixels_segBCEF;

endmodule