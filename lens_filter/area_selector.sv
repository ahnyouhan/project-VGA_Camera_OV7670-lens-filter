`timescale 1ns / 1ps

//=============================================================================
// Area Selector for Convex Lens Filter (FIXED)
//=============================================================================
// 수정사항:
// 1. sw3 HIGH일 때 btn_c 눌러도 렌즈 저장 안 됨
// 2. sw3 HIGH일 때 렌즈 미리보기 완전 OFF
//=============================================================================

module area_selector #(
    parameter IMG_WIDTH  = 320,
    parameter IMG_HEIGHT = 240,
    parameter MAX_LENS   = 8,
    parameter DEFAULT_R  = 30,
    parameter DEFAULT_K  = 40
) (
    input  logic        clk,
    input  logic        reset,
    
    input  logic        sw0_edit_mode,
    input  logic        sw0_falling,
    input  logic        sw1_size_mode,
    input  logic        sw2_k_mode,
    input  logic        sw3_emoji_mode,
    input  logic        sw14_rising,
    
    input  logic        btn_u,
    input  logic        btn_d,
    input  logic        btn_l,
    input  logic        btn_r,
    input  logic        btn_c,
    
    output logic [8:0]  current_center_x,
    output logic [7:0]  current_center_y,
    output logic [7:0]  current_R,
    output logic [7:0]  current_K,
    output logic        preview_enable,
    
    output logic [2:0]  lens_count,
    output logic [8:0]  lens_center_x [0:MAX_LENS-1],
    output logic [7:0]  lens_center_y [0:MAX_LENS-1],
    output logic [7:0]  lens_R [0:MAX_LENS-1],
    output logic [7:0]  lens_K [0:MAX_LENS-1],
    
    output logic        save_trigger
);

    logic btn_u_d, btn_d_d, btn_l_d, btn_r_d, btn_c_d;
    logic btn_u_rise, btn_d_rise, btn_l_rise, btn_r_rise, btn_c_rise;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            btn_u_d <= 0; btn_d_d <= 0; btn_l_d <= 0; btn_r_d <= 0; btn_c_d <= 0;
        end else begin
            btn_u_d <= btn_u; btn_d_d <= btn_d; btn_l_d <= btn_l; btn_r_d <= btn_r; btn_c_d <= btn_c;
        end
    end

    assign btn_u_rise = btn_u & ~btn_u_d;
    assign btn_d_rise = btn_d & ~btn_d_d;
    assign btn_l_rise = btn_l & ~btn_l_d;
    assign btn_r_rise = btn_r & ~btn_r_d;
    assign btn_c_rise = btn_c & ~btn_c_d;

    logic [27:0] hold_counter;
    logic [1:0]  speed_level;
    logic        slow_tick;
    logic [21:0] tick_counter;
    logic [21:0] tick_threshold;

    wire any_btn_held = btn_u | btn_d | btn_l | btn_r;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            hold_counter <= 0;
            speed_level <= 0;
        end else if (!any_btn_held) begin
            hold_counter <= 0;
            speed_level <= 0;
        end else begin
            if (hold_counter < 28'hFFFFFFF)
                hold_counter <= hold_counter + 1;
            
            if (hold_counter < 28'd50_000_000)
                speed_level <= 0;
            else if (hold_counter < 28'd150_000_000)
                speed_level <= 1;
            else
                speed_level <= 2;
        end
    end

    always_comb begin
        case (speed_level)
            2'd0: tick_threshold = 22'd2_000_000;
            2'd1: tick_threshold = 22'd1_000_000;
            2'd2: tick_threshold = 22'd500_000;
            default: tick_threshold = 22'd2_000_000;
        endcase
    end

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            tick_counter <= 0;
            slow_tick <= 0;
        end else begin
            if (tick_counter >= tick_threshold) begin
                tick_counter <= 0;
                slow_tick <= 1;
            end else begin
                tick_counter <= tick_counter + 1;
                slow_tick <= 0;
            end
        end
    end

    logic sw0_d, sw0_rising;
    
    always_ff @(posedge clk, posedge reset) begin
        if (reset)
            sw0_d <= 0;
        else
            sw0_d <= sw0_edit_mode;
    end
    
    assign sw0_rising = sw0_edit_mode & ~sw0_d;

    logic [8:0] temp_center_x;
    logic [7:0] temp_center_y;
    logic [7:0] temp_R;
    logic [7:0] temp_K;

    // 렌즈 모드에서만 btn_c로 위치 리셋 (sw3 HIGH면 무시!)
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            temp_center_x <= IMG_WIDTH / 2;
        end else if (sw0_falling || sw0_rising) begin
            temp_center_x <= IMG_WIDTH / 2;
        end else if (sw0_edit_mode && !sw3_emoji_mode && btn_c_rise) begin
            // 렌즈 모드에서만 C로 중앙 리셋 (수정!)
            temp_center_x <= IMG_WIDTH / 2;
        end else if (sw0_edit_mode && !sw3_emoji_mode && !sw1_size_mode && !sw2_k_mode) begin
            if (btn_l_rise || (btn_l && slow_tick)) begin
                if (temp_center_x > 0)
                    temp_center_x <= temp_center_x - 1;
            end else if (btn_r_rise || (btn_r && slow_tick)) begin
                if (temp_center_x < IMG_WIDTH - 1)
                    temp_center_x <= temp_center_x + 1;
            end
        end
    end

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            temp_center_y <= IMG_HEIGHT / 2;
        end else if (sw0_falling || sw0_rising) begin
            temp_center_y <= IMG_HEIGHT / 2;
        end else if (sw0_edit_mode && !sw3_emoji_mode && btn_c_rise) begin
            // 렌즈 모드에서만 C로 중앙 리셋 (수정!)
            temp_center_y <= IMG_HEIGHT / 2;
        end else if (sw0_edit_mode && !sw3_emoji_mode && !sw1_size_mode && !sw2_k_mode) begin
            if (btn_u_rise || (btn_u && slow_tick)) begin
                if (temp_center_y > 0)
                    temp_center_y <= temp_center_y - 1;
            end else if (btn_d_rise || (btn_d && slow_tick)) begin
                if (temp_center_y < IMG_HEIGHT - 1)
                    temp_center_y <= temp_center_y + 1;
            end
        end
    end

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            temp_R <= DEFAULT_R;
        end else if (sw0_falling || sw0_rising) begin
            temp_R <= DEFAULT_R;
        end else if (sw0_edit_mode && !sw3_emoji_mode && btn_c_rise) begin
            // 렌즈 모드에서만 C로 초기화 (수정!)
            temp_R <= DEFAULT_R;
        end else if (sw0_edit_mode && !sw3_emoji_mode && sw1_size_mode) begin
            if (btn_u_rise || (btn_u && slow_tick)) begin
                if (temp_R < 8'd120)
                    temp_R <= temp_R + 1;
            end else if (btn_d_rise || (btn_d && slow_tick)) begin
                if (temp_R > 8'd5)
                    temp_R <= temp_R - 1;
            end
        end
    end

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            temp_K <= DEFAULT_K;
        end else if (sw0_falling || sw0_rising) begin
            temp_K <= DEFAULT_K;
        end else if (sw0_edit_mode && !sw3_emoji_mode && btn_c_rise) begin
            // 렌즈 모드에서만 C로 초기화 (수정!)
            temp_K <= DEFAULT_K;
        end else if (sw0_edit_mode && !sw3_emoji_mode && sw2_k_mode) begin
            if (btn_u_rise || (btn_u && slow_tick)) begin
                if (temp_K < 8'd200)
                    temp_K <= temp_K + 1;
            end else if (btn_d_rise || (btn_d && slow_tick)) begin
                if (temp_K > 8'd1)
                    temp_K <= temp_K - 1;
            end
        end
    end

    assign current_center_x = temp_center_x;
    assign current_center_y = temp_center_y;
    assign current_R = temp_R;
    assign current_K = temp_K;

    logic [2:0] lens_cnt_reg;

    // 렌즈 저장: sw3 HIGH일 때는 저장 안 함! (핵심 수정!)
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            lens_cnt_reg <= 0;
            for (int i = 0; i < MAX_LENS; i++) begin
                lens_center_x[i] <= 0;
                lens_center_y[i] <= 0;
                lens_R[i] <= DEFAULT_R;
                lens_K[i] <= DEFAULT_K;
            end
        end else if (sw0_falling) begin
            lens_cnt_reg <= 0;
            for (int i = 0; i < MAX_LENS; i++) begin
                lens_center_x[i] <= 0;
                lens_center_y[i] <= 0;
                lens_R[i] <= DEFAULT_R;
                lens_K[i] <= DEFAULT_K;
            end
        end else if (sw0_edit_mode && !sw3_emoji_mode && btn_c_rise) begin
            // 렌즈 모드에서만 저장! (sw3 HIGH면 저장 안 함!)
            if (lens_cnt_reg < MAX_LENS) begin
                lens_center_x[lens_cnt_reg] <= temp_center_x;
                lens_center_y[lens_cnt_reg] <= temp_center_y;
                lens_R[lens_cnt_reg] <= temp_R;
                lens_K[lens_cnt_reg] <= temp_K;
                lens_cnt_reg <= lens_cnt_reg + 1;
            end
        end
    end

    assign lens_count = lens_cnt_reg;

    // 렌즈 미리보기: sw3 HIGH면 완전 OFF! (수정!)
    always_ff @(posedge clk, posedge reset) begin
        if (reset)
            preview_enable <= 1'b0;
        else
            preview_enable <= sw0_edit_mode && !sw3_emoji_mode;
    end

    always_ff @(posedge clk, posedge reset) begin
        if (reset)
            save_trigger <= 1'b0;
        else
            save_trigger <= sw14_rising;
    end

endmodule