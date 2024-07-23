`default_nettype none

module spi 
#(
	parameter WIDTH = 8,
    parameter IDLE_TIME = 4
)
(
    input clk_in,    
    input reset_in,

    input transmitt,
    input deactivate_cs_after,
    input [WIDTH-1:0] data_in,

    output [WIDTH-1:0] data_out,
    output ready,

    output select,
    output sck,
    output mosi,
    input miso
);

parameter DELAY_CNT_WIDTH = $clog2(IDLE_TIME);

// State machine
parameter S_IDLE = 0, S_TRIGGER = 1, S_TRANSMISSION = 2;
reg [1:0] state_r;

reg [DELAY_CNT_WIDTH-1:0] cnt_r;
reg deactivate_cs_r;

reg chip_select_r;

wire trigger_shift_reg;
wire shift_reg_ready;

shift_register #(.WIDTH(WIDTH)) shift_reg (
    .clk_in(clk_in),
    .reset_in(reset_in),

    .start(trigger_shift_reg),
    .data_in(data_in),

    .ready(shift_reg_ready),
    .data_out(data_out),

    .clk_out(sck),
    .serial_out(mosi),
    .serial_in(miso)
);

always @(posedge clk_in) begin
    if (reset_in) begin
        state_r <= S_IDLE;
        cnt_r <= IDLE_TIME;
        deactivate_cs_r <= 1'b0;
        chip_select_r <= 1'b1;
    end else begin
        case (state_r)
            S_IDLE: begin
                if (transmitt & shift_reg_ready) begin
                    deactivate_cs_r <= deactivate_cs_after;
                    state_r <= S_TRIGGER;
                    chip_select_r <= 1'b0;
                end
            end
            S_TRIGGER: begin
                if (!shift_reg_ready) begin
                    state_r <= S_TRANSMISSION;
                end
            end
            S_TRANSMISSION: begin
                if (shift_reg_ready) begin
                    chip_select_r <= deactivate_cs_r;
                    state_r <= S_IDLE;
                end
            end
        endcase
    end
end

assign trigger_shift_reg = (state_r == S_TRIGGER);

assign select = chip_select_r;

assign ready = !reset_in & (state_r == S_IDLE);

endmodule