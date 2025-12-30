module sccbRom #(
    parameter INST_NUM   = 22,
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = $clog2(INST_NUM)
) (
    input  [ADDR_WIDTH-1:0] addr,
    output [DATA_WIDTH-1:0] data
);

  logic [DATA_WIDTH-1:0] mem[2**ADDR_WIDTH];
  initial begin
    $readmemh("ref.mem", mem);
  end
  assign data = mem[addr];

endmodule
