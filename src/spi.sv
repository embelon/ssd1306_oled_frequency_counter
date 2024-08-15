`default_nettype none

module spi
#(
	parameter WIDTH = 8
)
(
    input bit clk_in,    
    input bit reset_in,

    input bit tx_start_in,
    input bit deactivate_cs_in,             // when 1 -> deactivate select line after transmission of current byte
    input bit [WIDTH-1:0] data_in,
    output bit [WIDTH-1:0] data_out,
    output bit tx_done_out,

    output bit select_out,
    output bit sck_out,
    output bit mosi_out,
    input bit miso_in
);

// State machine definition
typedef enum {S_IDLE, S_TRIGGER, S_TRANSMISSION} e_state;
e_state state_r;

reg deactivate_cs_r;
reg chip_select_r;

wire trigger_shift_reg;
wire shift_reg_ready;

shift_register #(.WIDTH(WIDTH)) shift_reg (
    .clk_in(clk_in),
    .reset_in(reset_in),

    .start_in(trigger_shift_reg),
    .data_in(data_in),

    .ready_out(shift_reg_ready),
    .data_out(data_out),

    .clk_out(sck_out),
    .serial_out(mosi_out),
    .serial_in(miso_in)
);

always @(posedge clk_in) begin
    if (reset_in) begin
        state_r <= S_IDLE;
        deactivate_cs_r <= 1'b0;
        chip_select_r <= 1'b1;
    end else begin
        case (state_r)
            S_IDLE: begin
                if (tx_start_in & shift_reg_ready) begin
                    deactivate_cs_r <= deactivate_cs_in;
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

assign select_out = chip_select_r;

assign tx_done_out = !reset_in & (state_r == S_IDLE);

endmodule
