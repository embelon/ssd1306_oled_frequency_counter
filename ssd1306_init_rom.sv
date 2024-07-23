`default_nettype none

module ssd1306_init_rom
#(
    parameter SIZE = 32,
    parameter DATA_WIDTH = 9,
    parameter INIT_FILE = "ssd1306_init_sequence.mif",
    localparam ADDRESS_BITS = $clog2(SIZE)
)
(
    input [ADDRESS_BITS-1:0] address,
    output [DATA_WIDTH-1:0] data,
    output last
);

logic [DATA_WIDTH-1:0] rom [0:SIZE-1];

initial begin
    $readmemh(INIT_FILE, rom);
end

assign data = (address < SIZE) ? rom[address] : {DATA_WIDTH-1{1'b0}};
assign last = address == SIZE;

endmodule
