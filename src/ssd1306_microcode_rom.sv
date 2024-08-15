`default_nettype none

module ssd1306_microcode_rom
#(
    parameter SIZE = 40,
    parameter DATA_WIDTH = 10,
    parameter INIT_FILE = "ssd1306_microcode.mif",
    localparam ADDRESS_BITS = $clog2(SIZE)
)
(
    input bit [ADDRESS_BITS-1:0] address,
    output bit [DATA_WIDTH-1:0] data,
    output bit address_overflow
);

bit [DATA_WIDTH-1:0] rom [0:SIZE-1];

initial begin
    $readmemh(INIT_FILE, rom);
end

assign address_overflow = (address >= SIZE);
assign data = !address_overflow ? rom[address] : {DATA_WIDTH{1'b0}};

endmodule
