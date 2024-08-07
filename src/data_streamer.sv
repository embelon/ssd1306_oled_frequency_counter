`default_nettype none

module data_streamer
#(
    DIGITS_NUM = 6
)
(
    input clk_in,
    input reset_in,

    // data interface, data to be displayed as number
    input [4*DIGITS_NUM-1:0] digits_in,
    input refresh_stb_in,
    output ready_out,

    // output interface (to be connected to oled driver)
    output [7:0] oled_data_out,
    output oled_write_stb_out,
    output oled_sync_stb_out,
    input oled_ready_in
);

    // LCD is 128x32 pixels
    localparam LCD_X_SIZE_PX = 128;
    localparam LCD_Y_SIZE_PX = 32;
    localparam LCD_Y_SIZE_BYTES = LCD_Y_SIZE_PX / 8;

    // one digit is taking 21 pixels in X axis, all 32 pixels in Y axis
    localparam DIGIT_X_SIZE_PX = 21;

    // max values for counters
    localparam DIGIT_CNT_MAX = DIGITS_NUM - 1;
    localparam X_CNT_MAX = DIGIT_X_SIZE_PX - 1;         // 21 pixels, max is 20
    localparam Y_CNT_MAX = LCD_Y_SIZE_BYTES - 1;        // 32 pixels => 4 bytes, max is 3

    // bit length for all counters
    localparam DIGIT_CNT_SIZE = $clog2(DIGIT_CNT_MAX);
    localparam X_CNT_SIZE = $clog2(X_CNT_MAX); 
    localparam Y_CNT_SIZE = $clog2(Y_CNT_MAX);

    // counters for digits, x index and y index
    reg [DIGIT_CNT_SIZE-1:0] digit_cnt_r;
    reg [X_CNT_SIZE-1:0] x_index_r;
    reg [Y_CNT_SIZE-1:0] y_index_r;
    
    // stored input data / digits
    reg [4*DIGITS_NUM-1:0] digits_r;

    // state machine
    localparam S_RESET = 0, S_IDLE = 1, S_SEND_DATA = 2, S_WAIT_FOR_READY = 3, S_SEND_SYNC = 4, S_WAIT_FOR_SYNC = 5;
    reg [2:0] state_r;

    always @(posedge clk_in) begin
        if (reset_in) begin
            digits_r <= 0;            
            digit_cnt_r <= DIGIT_CNT_MAX;
            x_index_r <= 0;
            y_index_r <= 0;
            state_r <= S_RESET;
        end else begin
            case (state_r)
                S_RESET: begin
                    state_r <= S_IDLE;
                end
                S_IDLE: begin
                    if (refresh_stb_in) begin
                        digits_r <= digits_in;
                        digit_cnt_r <= DIGIT_CNT_MAX;
                        x_index_r <= 0;
                        y_index_r <= 0;                        
                        state_r <= S_SEND_DATA;
                    end
                end
                S_SEND_DATA: begin
                    if (!oled_ready_in) begin
                        state_r <= S_WAIT_FOR_READY;
                    end
                end
                S_WAIT_FOR_READY: begin
                    if (oled_ready_in) begin
                        state_r <= S_SEND_DATA;
                        if (y_index_r == Y_CNT_MAX) begin
                            y_index_r <= 0;
                            if (x_index_r == X_CNT_MAX) begin
                                x_index_r <= 0;
                                if (digit_cnt_r == 0) begin
                                    digit_cnt_r <= DIGIT_CNT_MAX;
                                    state_r <= S_SEND_SYNC;
                                end else begin
                                    digit_cnt_r <= digit_cnt_r - 1;
                                end
                            end else begin
                                x_index_r <= x_index_r + 1;
                            end
                        end else begin
                            y_index_r <= y_index_r + 1;                            
                        end
                    end
                end
                S_SEND_SYNC: begin
                    if (!oled_ready_in) begin
                        state_r <= S_WAIT_FOR_SYNC;
                    end
                end
                S_WAIT_FOR_SYNC: begin
                    if (oled_ready_in) begin
                        state_r <= S_IDLE;
                    end
                end
            endcase
        end
    end

    assign oled_write_stb_out = (state_r == S_SEND_DATA);
    assign oled_sync_stb_out = (state_r == S_SEND_SYNC);

    assign ready_out = (state_r == S_IDLE);

    // get actual digit
    wire [3:0] current_digit;
    always_comb begin
        current_digit[3:0] = digits_r >> (4 * digit_cnt_r);
    end
//    assign current_digit = digits_r[4*digit_cnt_r+3:4*digit_cnt_r];

    // first decode number to 7 segments
    wire [6:0] segments7;

    decoder_bin_to_7seg decoder_7seg
    (
        .digit_in(current_digit),
        .segments_out(segments7)
    );

    // now translate 7 segments into pixels
    wire [7:0] pixels;

    decoder_7seg_to_21x32pix graphical_decoder
    (
        .segments_in(segments7),

        .index_x_in(x_index_r),
        .index_y_in(y_index_r),

        .pixels_out(pixels)
    );

    assign oled_data_out = pixels;

endmodule