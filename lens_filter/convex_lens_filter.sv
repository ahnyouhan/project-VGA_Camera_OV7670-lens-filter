`timescale 1ns / 1ps

//=============================================================================
// Convex Lens Filter - BUG FIXED VERSION
//=============================================================================
// 수정사항:
// 1. 렌즈 매칭을 완전한 조합 논리로 분리 (줄무늬 버그 수정)
// 2. Manhattan pre-filter 유지 (타이밍 최적화)
// 3. 정확한 원 판정으로 변경 가능 (옵션)
//=============================================================================

module convex_lens_filter #(
    parameter IMG_WIDTH  = 320,
    parameter IMG_HEIGHT = 240,
    parameter MAX_LENS   = 8,
    parameter USE_CIRCLE = 0  // 1: 정확한 원, 0: Manhattan 사각형
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
    
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] addr
);

    //=========================================================================
    // Stage 0A: 좌표 변환
    //=========================================================================
    logic [8:0] img_x;
    logic [7:0] img_y;
    assign img_x = x_pixel[9:1];
    assign img_y = y_pixel[9:1];

    //=========================================================================
    // Stage 0B: 렌즈 매칭 (완전 조합 논리 - 수정됨!)
    //=========================================================================
    logic        matched_found;
    logic [8:0]  matched_cx;
    logic [7:0]  matched_cy;
    logic [7:0]  matched_R;
    logic [7:0]  matched_K;
    logic signed [10:0] matched_dx, matched_dy;

    always_comb begin
        // 기본값
        matched_found = 1'b0;
        matched_cx = 0;
        matched_cy = 0;
        matched_R = 0;
        matched_K = 0;
        matched_dx = 0;
        matched_dy = 0;

        // 1. 미리보기 렌즈 체크 (최우선)
        if (sw0_edit_mode && preview_enable) begin
            automatic logic signed [10:0] dx_p, dy_p;
            automatic logic [8:0] abs_dx_p;
            automatic logic [7:0] abs_dy_p;
            
            dx_p = $signed({1'b0, img_x}) - $signed({2'b0, current_center_x});
            dy_p = $signed({1'b0, img_y}) - $signed({2'b0, current_center_y});
            abs_dx_p = (dx_p < 0) ? -dx_p : dx_p;
            abs_dy_p = (dy_p < 0) ? -dy_p : dy_p;
            
            if ((abs_dx_p < current_R) && (abs_dy_p < current_R)) begin
                matched_found = 1'b1;
                matched_cx = current_center_x;
                matched_cy = current_center_y;
                matched_R = current_R;
                matched_K = current_K;
                matched_dx = dx_p;
                matched_dy = dy_p;
            end
        end

        // 2. 확정 렌즈 체크 (미리보기 없으면)
        if (!matched_found) begin
            for (int i = 0; i < MAX_LENS; i++) begin
                if (i < lens_count && !matched_found) begin
                    automatic logic signed [10:0] dx_l, dy_l;
                    automatic logic [8:0] abs_dx_l;
                    automatic logic [7:0] abs_dy_l;
                    
                    dx_l = $signed({1'b0, img_x}) - $signed({2'b0, lens_center_x[i]});
                    dy_l = $signed({1'b0, img_y}) - $signed({2'b0, lens_center_y[i]});
                    abs_dx_l = (dx_l < 0) ? -dx_l : dx_l;
                    abs_dy_l = (dy_l < 0) ? -dy_l : dy_l;
                    
                    // Manhattan pre-filter
                    if ((abs_dx_l < lens_R[i]) && (abs_dy_l < lens_R[i])) begin
                        matched_found = 1'b1;
                        matched_cx = lens_center_x[i];
                        matched_cy = lens_center_y[i];
                        matched_R = lens_R[i];
                        matched_K = lens_K[i];
                        matched_dx = dx_l;
                        matched_dy = dy_l;
                    end
                end
            end
        end
    end

    //=========================================================================
    // Stage 1: 매칭 결과 저장 (Registered - 깔끔하게!)
    //=========================================================================
    logic [8:0]  s1_img_x;
    logic [7:0]  s1_img_y;
    logic        s1_de;
    logic        s1_apply_lens;
    logic [8:0]  s1_matched_cx;
    logic [7:0]  s1_matched_cy;
    logic [7:0]  s1_matched_R;
    logic [7:0]  s1_matched_K;
    logic signed [10:0] s1_dx, s1_dy;
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            s1_img_x <= 0;
            s1_img_y <= 0;
            s1_de <= 0;
            s1_apply_lens <= 0;
            s1_matched_cx <= 0;
            s1_matched_cy <= 0;
            s1_matched_R <= 0;
            s1_matched_K <= 0;
            s1_dx <= 0;
            s1_dy <= 0;
        end else if (pclk) begin
            s1_img_x <= img_x;
            s1_img_y <= img_y;
            s1_de <= DE;
            
            // 조합 논리 결과를 그대로 저장 (깔끔!)
            s1_apply_lens <= matched_found;
            s1_matched_cx <= matched_cx;
            s1_matched_cy <= matched_cy;
            s1_matched_R <= matched_R;
            s1_matched_K <= matched_K;
            s1_dx <= matched_dx;
            s1_dy <= matched_dy;
        end
    end

    //=========================================================================
    // Stage 2: 거리 제곱 계산 (Registered)
    //=========================================================================
    logic [19:0]        s2_dist2;
    logic [15:0]        s2_R2;
    logic [7:0]         s2_K;
    logic [8:0]         s2_cx;
    logic [7:0]         s2_cy;
    logic [8:0]         s2_img_x;
    logic [7:0]         s2_img_y;
    logic               s2_apply;
    logic               s2_de;
    logic signed [10:0] s2_dx, s2_dy;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            s2_dist2 <= 0;
            s2_R2 <= 0;
            s2_K <= 0;
            s2_cx <= 0;
            s2_cy <= 0;
            s2_img_x <= 0;
            s2_img_y <= 0;
            s2_apply <= 0;
            s2_de <= 0;
            s2_dx <= 0;
            s2_dy <= 0;
        end else if (pclk) begin
            s2_dist2 <= s1_dx * s1_dx + s1_dy * s1_dy;
            s2_R2 <= s1_matched_R * s1_matched_R;
            s2_K <= s1_matched_K;
            s2_cx <= s1_matched_cx;
            s2_cy <= s1_matched_cy;
            s2_img_x <= s1_img_x;
            s2_img_y <= s1_img_y;
            s2_apply <= s1_apply_lens;
            s2_de <= s1_de;
            s2_dx <= s1_dx;
            s2_dy <= s1_dy;
        end
    end

    //=========================================================================
    // Stage 3: Scale Factor 계산 (Registered)
    //=========================================================================
    logic signed [31:0] s3_scale;
    logic               s3_in_circle;
    logic signed [10:0] s3_dx, s3_dy;
    logic [8:0]         s3_cx;
    logic [7:0]         s3_cy;
    logic [8:0]         s3_img_x;
    logic [7:0]         s3_img_y;
    logic               s3_apply;
    logic               s3_de;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            s3_scale <= 0;
            s3_in_circle <= 0;
            s3_dx <= 0;
            s3_dy <= 0;
            s3_cx <= 0;
            s3_cy <= 0;
            s3_img_x <= 0;
            s3_img_y <= 0;
            s3_apply <= 0;
            s3_de <= 0;
        end else if (pclk) begin
            s3_scale <= 32'd65536 + (s2_K * s2_dist2);
            
            // USE_CIRCLE 파라미터로 선택 가능
            if (USE_CIRCLE)
                s3_in_circle <= (s2_dist2 < s2_R2);  // 정확한 원
            else
                s3_in_circle <= s2_apply;  // Manhattan (이미 걸러짐)
            
            s3_dx <= s2_dx;
            s3_dy <= s2_dy;
            s3_cx <= s2_cx;
            s3_cy <= s2_cy;
            s3_img_x <= s2_img_x;
            s3_img_y <= s2_img_y;
            s3_apply <= s2_apply;
            s3_de <= s2_de;
        end
    end

    //=========================================================================
    // Stage 4: 좌표 변환 (Registered)
    //=========================================================================
    logic signed [31:0] s4_x_dist, s4_y_dist;
    logic [8:0]         s4_cx;
    logic [7:0]         s4_cy;
    logic [8:0]         s4_img_x;
    logic [7:0]         s4_img_y;
    logic               s4_in_circle;
    logic               s4_apply;
    logic               s4_de;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            s4_x_dist <= 0;
            s4_y_dist <= 0;
            s4_cx <= 0;
            s4_cy <= 0;
            s4_img_x <= 0;
            s4_img_y <= 0;
            s4_in_circle <= 0;
            s4_apply <= 0;
            s4_de <= 0;
        end else if (pclk) begin
            s4_x_dist <= s3_dx * s3_scale;
            s4_y_dist <= s3_dy * s3_scale;
            s4_cx <= s3_cx;
            s4_cy <= s3_cy;
            s4_img_x <= s3_img_x;
            s4_img_y <= s3_img_y;
            s4_in_circle <= s3_in_circle;
            s4_apply <= s3_apply;
            s4_de <= s3_de;
        end
    end

    //=========================================================================
    // Stage 5: 최종 주소 계산 (Registered)
    //=========================================================================
    logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] addr_reg;
    logic signed [11:0] x_new, y_new;

    always_comb begin
        x_new = $signed({1'b0, s4_cx}) + (s4_x_dist >>> 17);
        y_new = $signed({1'b0, s4_cy}) + (s4_y_dist >>> 17);
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            addr_reg <= 0;
        end else if (pclk) begin
            if (!s4_de) begin
                addr_reg <= 0;
            end else if (!s4_apply || !s4_in_circle) begin
                addr_reg <= IMG_WIDTH * s4_img_y + s4_img_x;
            end else begin
                if (x_new < 0 || x_new >= IMG_WIDTH || y_new < 0 || y_new >= IMG_HEIGHT)
                    addr_reg <= IMG_WIDTH * s4_img_y + s4_img_x;
                else
                    addr_reg <= IMG_WIDTH * y_new[7:0] + x_new[8:0];
            end
        end
    end

    assign addr = addr_reg;

endmodule