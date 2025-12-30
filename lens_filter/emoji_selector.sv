`timescale 1ns / 1ps

//=============================================================================
// Emoji Selector - 이모티콘 오버레이 관리 (FIXED)
//=============================================================================
// 수정사항:
// 1. sw3 LOW → 확정된 이모티콘 유지, 미리보기만 OFF
// 2. sw0 LOW → 렌즈 + 이모티콘 전체 리셋
//=============================================================================

module emoji_selector #(
    parameter IMG_WIDTH  = 320,
    parameter IMG_HEIGHT = 240,
    parameter EMOJI_SIZE = 64,
    parameter MAX_EMOJI  = 8,
    parameter NUM_EMOJI_TYPES = 6
) (
    input  logic        clk,
    input  logic        reset,
    
    // Mode control
    input  logic        sw0_edit_mode,    // 편집 모드
    input  logic        sw0_falling,      // sw0 falling edge (추가!)
    input  logic        sw3_emoji_mode,   // 이모티콘 모드
    input  logic        sw3_falling,      // sw3 falling edge
    
    // Button inputs (debounced)
    input  logic        btn_u,
    input  logic        btn_d,
    input  logic        btn_l,
    input  logic        btn_r,
    input  logic        btn_c,
    
    // 현재 편집 중인 이모티콘 (미리보기)
    output logic [8:0]  current_emoji_x,
    output logic [8:0]  current_emoji_y,
    output logic [2:0]  current_emoji_type,
    output logic        preview_enable,
    output logic        selection_mode,       // 1: 선택, 0: 위치조정
    
    // 확정된 이모티콘 배열
    output logic [2:0]  emoji_count,
    output logic [8:0]  emoji_x [0:MAX_EMOJI-1],
    output logic [8:0]  emoji_y [0:MAX_EMOJI-1],
    output logic [2:0]  emoji_type [0:MAX_EMOJI-1]
);

    //=========================================================================
    // Button Edge Detection
    //=========================================================================
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

    //=========================================================================
    // Slow Counter (버튼 hold 가속)
    //=========================================================================
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

    //=========================================================================
    // sw3 Entry Detection
    //=========================================================================
    logic sw3_d;
    logic sw3_rising;
    
    always_ff @(posedge clk, posedge reset) begin
        if (reset)
            sw3_d <= 0;
        else
            sw3_d <= sw3_emoji_mode;
    end
    
    assign sw3_rising = sw3_emoji_mode & ~sw3_d;

    //=========================================================================
    // State: Selection Mode (1단계) vs Position Mode (2단계)
    //=========================================================================
    logic selection_mode_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            selection_mode_reg <= 1'b1;
        end else if (sw0_falling) begin
            selection_mode_reg <= 1'b1;  // sw0 LOW: 초기화
        end else if (sw3_rising) begin
            selection_mode_reg <= 1'b1;  // 진입 시 선택 모드
        end else if (sw0_edit_mode && sw3_emoji_mode && btn_c_rise) begin
            // C 버튼: 모드 토글
            if (!selection_mode_reg) begin
                // 위치 확정 후 → 선택 모드로 복귀
                selection_mode_reg <= 1'b1;
            end else begin
                // 선택 확정 → 위치 조정 모드로
                selection_mode_reg <= 1'b0;
            end
        end
    end

    assign selection_mode = selection_mode_reg;

    //=========================================================================
    // Current Emoji Control
    //=========================================================================
    logic [8:0] temp_emoji_x;
    logic [8:0] temp_emoji_y;
    logic [2:0] temp_emoji_type;

    // Emoji Type 선택 (1단계: 선택 모드)
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            temp_emoji_type <= 0;
        end else if (sw0_falling) begin
            temp_emoji_type <= 0;  // sw0 LOW: 초기화
        end else if (sw3_rising) begin
            temp_emoji_type <= 0;  // emoji0부터 시작
        end else if (sw0_edit_mode && sw3_emoji_mode && selection_mode_reg) begin
            // 선택 모드: L/R로 이모티콘 타입 변경
            if (btn_l_rise) begin
                if (temp_emoji_type == 0)
                    temp_emoji_type <= NUM_EMOJI_TYPES - 1;
                else
                    temp_emoji_type <= temp_emoji_type - 1;
            end else if (btn_r_rise) begin
                if (temp_emoji_type == NUM_EMOJI_TYPES - 1)
                    temp_emoji_type <= 0;
                else
                    temp_emoji_type <= temp_emoji_type + 1;
            end
        end else if (sw0_edit_mode && sw3_emoji_mode && !selection_mode_reg && btn_c_rise) begin
            // 위치 확정 후: emoji0으로 리셋
            temp_emoji_type <= 0;
        end
    end

    // Emoji X Position
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            temp_emoji_x <= IMG_WIDTH / 2 - EMOJI_SIZE / 2;
        end else if (sw0_falling) begin
            temp_emoji_x <= IMG_WIDTH / 2 - EMOJI_SIZE / 2;  // sw0 LOW: 초기화
        end else if (sw3_rising || (sw0_edit_mode && sw3_emoji_mode && btn_c_rise)) begin
            // 진입 시 또는 확정 시: 중앙으로
            temp_emoji_x <= IMG_WIDTH / 2 - EMOJI_SIZE / 2;
        end else if (sw0_edit_mode && sw3_emoji_mode && !selection_mode_reg) begin
            // 위치 조정 모드: L/R로 좌우 이동
            if (btn_l_rise || (btn_l && slow_tick)) begin
                if (temp_emoji_x > 0)
                    temp_emoji_x <= temp_emoji_x - 1;
            end else if (btn_r_rise || (btn_r && slow_tick)) begin
                if (temp_emoji_x < IMG_WIDTH - EMOJI_SIZE)
                    temp_emoji_x <= temp_emoji_x + 1;
            end
        end
    end

    // Emoji Y Position
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            temp_emoji_y <= IMG_HEIGHT / 2 - EMOJI_SIZE / 2;
        end else if (sw0_falling) begin
            temp_emoji_y <= IMG_HEIGHT / 2 - EMOJI_SIZE / 2;  // sw0 LOW: 초기화
        end else if (sw3_rising || (sw0_edit_mode && sw3_emoji_mode && btn_c_rise)) begin
            temp_emoji_y <= IMG_HEIGHT / 2 - EMOJI_SIZE / 2;
        end else if (sw0_edit_mode && sw3_emoji_mode && !selection_mode_reg) begin
            // 위치 조정 모드: U/D로 상하 이동
            if (btn_u_rise || (btn_u && slow_tick)) begin
                if (temp_emoji_y > 0)
                    temp_emoji_y <= temp_emoji_y - 1;
            end else if (btn_d_rise || (btn_d && slow_tick)) begin
                if (temp_emoji_y < IMG_HEIGHT - EMOJI_SIZE)
                    temp_emoji_y <= temp_emoji_y + 1;
            end
        end
    end

    assign current_emoji_x = temp_emoji_x;
    assign current_emoji_y = temp_emoji_y;
    assign current_emoji_type = temp_emoji_type;

    //=========================================================================
    // Emoji Array Control (확정된 이모티콘들)
    //=========================================================================
    logic [2:0] emoji_cnt_reg;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            emoji_cnt_reg <= 0;
            for (int i = 0; i < MAX_EMOJI; i++) begin
                emoji_x[i] <= 0;
                emoji_y[i] <= 0;
                emoji_type[i] <= 0;
            end
        end else if (sw0_falling) begin
            // sw0 LOW: 모든 이모티콘 리셋 (수정!)
            emoji_cnt_reg <= 0;
            for (int i = 0; i < MAX_EMOJI; i++) begin
                emoji_x[i] <= 0;
                emoji_y[i] <= 0;
                emoji_type[i] <= 0;
            end
        end else if (sw0_edit_mode && sw3_emoji_mode && !selection_mode_reg && btn_c_rise) begin
            // 위치 조정 모드에서 C: 확정 (배열에 추가)
            if (emoji_cnt_reg < MAX_EMOJI) begin
                emoji_x[emoji_cnt_reg] <= temp_emoji_x;
                emoji_y[emoji_cnt_reg] <= temp_emoji_y;
                emoji_type[emoji_cnt_reg] <= temp_emoji_type;
                emoji_cnt_reg <= emoji_cnt_reg + 1;
            end
        end
        // sw3_falling 시에는 아무것도 안 함 → 확정된 이모티콘 유지!
    end

    assign emoji_count = emoji_cnt_reg;

    //=========================================================================
    // Preview Enable (수정!)
    //=========================================================================
    // sw0 HIGH && sw3 HIGH일 때만 미리보기 ON
    // sw3 LOW면 미리보기 OFF (확정된 이모티콘만 보임)
    always_ff @(posedge clk, posedge reset) begin
        if (reset)
            preview_enable <= 1'b0;
        else
            preview_enable <= (sw0_edit_mode && sw3_emoji_mode);
    end

endmodule