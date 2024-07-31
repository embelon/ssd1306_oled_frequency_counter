`default_nettype none

module decoder_7seg_to_21x32pix
(
    input Segments segments_in,

    input [3:0] index_x,
    input [1:0] index_y,

    output [7:0] pix_column
);

    parameter SPACE = 2;

    // adjust space before character (number of empty columns)
    wire [3:0] x = index_x - SPACE;
    wire [1:0] y = index_y;    

    // 'b', 'c', 'e', 'f' segments definition
    wire [7:0] pattern_bcef[8] = 
    {
        8'h0f, 
        8'hfc, 
        8'h1f, 
        8'hfe, 
        8'h0f, 
        8'hfc, 
        8'h07, 
        8'hf8
    };

    // 'a' and 'd' segments are packed with 'g' segments in one table to save space
    parameter ad_mask = 8'hf8;
    parameter g_mask = 8'h03;
    wire [7:0] pattern_adg[12] = {
        8'h40, 
        8'h60 | 8'h01,
        8'h70 | 8'h03,
        8'h78 | 8'h03,
        8'h78 | 8'h03,
        8'h78 | 8'h03,
        8'h78 | 8'h03,
        8'h78 | 8'h03,
        8'h78 | 8'h03,
        8'h70 | 8'h03,
        8'h60 | 8'h01,
        8'h40
    };

    function [7:0] segment_A(input Segments segments, wire [3:0] x, wire [1:0] y);
        if (segments.individual.a && (x >= 2) && (x <= 13) && (y == 0)) begin
            segment_A = ad_mask & pattern_adg[x - 2];
        end else begin
            segment_A = 8'h00;
        end
    endfunction

    function [7:0] segment_D(input Segments segments, wire [3:0] x, wire [1:0] y);
        if (segments.individual.d &&(x >= 2) && (index_x <= 13) && (y == 3)) begin
            segment_D = ad_mask & reverse_8bits(pattern_adg[x - 2]);
        end else begin
            segment_D = 8'h00;
        end
    endfunction

    function [7:0] segment_G(input Segments segments, wire [3:0] x, wire [1:0] y);
        if (segments.individual.g && (x >= 2) && (x <= 13)) begin
            if (y == 1) begin
                return g_mask & pattern_adg[x - 2];
            end else if (y == 2) begin
                return g_mask & reverse_8bits(pattern_adg[x - 2]);
            end 
        end
        return 0'h00;        
    endfunction

    function [7:0] segment_B(input Segments segments, [3:0] x, [1:0] y)
        if (segments.individual.b && (x >= 12) && (x <= 15) && ((y == 0) || (y == 1))) begin
            return pattern_bcef[{!x[1:0], y[0]}];
        end
        return 0'h00;
    endfunction

    function [7:0] segment_C(input Segments segments, [3:0] x, [1:0] y)
        if (segments.individual.c && (x >= 12) && (x <= 15) && ((y == 2) || (y == 3))) begin
            return reverse_8bits(pattern_bcef[{!x[1:0], !y[0]}]);
        end
        return 0'h00;
    endfunction

    function [7:0] segment_E(input Segments segments, [3:0] x, [1:0] y)
        if (segments.individual.e && (x <= 3) && ((y == 2) || (y == 3))) begin
            return reverse_8bits(pattern_bcef[{x[1:0], !y[0]}]);
        end
        return 0'h00;
    endfunction

    function [7:0] segment_F(input Segments segments, [3:0] x, [1:0] y)
        if (segments.individual.f && (x <= 3) && ((y == 0) || (y == 1))) begin
            return pattern_bcef[{x[1:0], y[0]}];
        end
        return 0'h00;
    endfunction

always @(digit_in, index_x, index_y) begin
    if (index_x < SPACE) begin
        pix_column <= 8'h00;
    end else begin
        pix_column <= segment_A(segments_in, x, y) ||
            segment_B(segments_in, x, y) ||
            segment_C(segments_in, x, y) ||
            segment_D(segments_in, x, y) ||
            segment_E(segments_in, x, y) ||
            segment_F(segments_in, x, y) ||
            segment_G(segments_in, x, y);
    end
end

endmodule