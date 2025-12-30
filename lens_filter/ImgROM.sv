`timescale 1ns / 1ps

module ImgROM #(
    parameter IMG_WIDTH = 320,
    parameter IMG_HEIGHT = 240
) (
    input  logic                                    clk,
    input  logic                                    pclk,   // enable 신호
    input  logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] addr,
    output logic [15:0]                             data
);
    logic [15:0] mem[0:IMG_WIDTH*IMG_HEIGHT-1];

    initial begin
        $readmemh("zz320x240.mem", mem);
    end

    // pclk enable 시 동기 읽기
    always_ff @(posedge clk) begin
        if (pclk) begin
            data <= mem[addr];
        end
    end

endmodule
