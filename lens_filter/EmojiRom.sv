`timescale 1ns / 1ps

module EmojiROM #(
    parameter W = 64,
    parameter H = 64,
    parameter NUM = 6,
    parameter MEM_FILE = "emoji_all.mem"
) (   
    input logic clk,
    input logic [$clog2(W*H*NUM)-1:0] addr,
    output logic [15:0] data
);

    logic [15:0] mem[0:W*H*NUM-1];

    initial begin   
        $readmemh(MEM_FILE, mem);

    end

    always_ff @(posedge clk) begin
        data <= mem[addr];
    end

endmodule
