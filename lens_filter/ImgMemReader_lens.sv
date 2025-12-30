`timescale 1ns / 1ps

//=============================================================================
// Image Memory Reader with Lens Filter - OPTIMIZED
//=============================================================================
// 변경사항:
// - convex_lens_filter가 6 Stage로 증가
// - DE 지연도 6단계로 조정 (DE_d6 사용)
//=============================================================================

module ImgMemReader_lens #(
    parameter IMG_WIDTH  = 320,
    parameter IMG_HEIGHT = 240,
    parameter MAX_LENS   = 8
) (
    input  logic       clk,
    input  logic       reset,
    input  logic       pclk,
    input  logic       DE,
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
    
    input  logic [8:0]  current_center_x,
    input  logic [7:0]  current_center_y,
    input  logic [7:0]  current_R,
    input  logic [7:0]  current_K,
    input  logic        sw0_edit_mode,
    input  logic        preview_enable,
    
    input  logic [2:0]  lens_count,
    input  logic [8:0]  lens_center_x [0:MAX_LENS-1],
    input  logic [7:0]  lens_center_y [0:MAX_LENS-1],
    input  logic [7:0]  lens_R [0:MAX_LENS-1],
    input  logic [7:0]  lens_K [0:MAX_LENS-1],
    
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] addr,
    input  logic [15:0] imgData,
    
    output logic [3:0] r_port,
    output logic [3:0] g_port,
    output logic [3:0] b_port
);

    //=========================================================================
    // Lens Filter - 최적화된 6 Stage 파이프라인
    //=========================================================================
    convex_lens_filter #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .MAX_LENS(MAX_LENS),
        .USE_CIRCLE(1)
    ) u_lens_filter (
        .clk(clk),
        .reset(reset),
        .pclk(pclk),
        .DE(DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .current_center_x(current_center_x),
        .current_center_y(current_center_y),
        .current_R(current_R),
        .current_K(current_K),
        .sw0_edit_mode(sw0_edit_mode),
        .preview_enable(preview_enable),
        .lens_count(lens_count),
        .lens_center_x(lens_center_x),
        .lens_center_y(lens_center_y),
        .lens_R(lens_R),
        .lens_K(lens_K),
        .addr(addr)
    );

    //=========================================================================
    // DE 지연 - 6 Stage에 맞춰 조정
    //=========================================================================
    logic DE_d1, DE_d2, DE_d3, DE_d4, DE_d5, DE_d6;
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            DE_d1 <= 0;
            DE_d2 <= 0;
            DE_d3 <= 0;
            DE_d4 <= 0;
            DE_d5 <= 0;
            DE_d6 <= 0;
        end else if (pclk) begin
            DE_d1 <= DE;
            DE_d2 <= DE_d1;
            DE_d3 <= DE_d2;
            DE_d4 <= DE_d3;
            DE_d5 <= DE_d4;
            DE_d6 <= DE_d5;
        end
    end

    //=========================================================================
    // RGB565 → RGB444 변환 (6단계 지연 적용)
    //=========================================================================
    assign r_port = DE_d6 ? imgData[15:12] : 4'b0;
    assign g_port = DE_d6 ? imgData[10:7]  : 4'b0;
    assign b_port = DE_d6 ? imgData[4:1]   : 4'b0;

endmodule