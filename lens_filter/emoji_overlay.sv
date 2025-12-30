`timescale 1ns / 1ps

module emoji_overlay #(
    parameter EMOJI_SIZE = 64,
    parameter MAX_EMOJI  = 8,
    parameter EMOJI_COUNT = 6                    // 0~5 이모티콘
)(
    input  logic       clk,
    input  logic       reset,

    // VGA 좌표
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,

    input  logic [3:0] bg_r,
    input  logic [3:0] bg_g,
    input  logic [3:0] bg_b,

    // emoji_selector 출력
    input  logic        sw0_edit_mode,
    input  logic        preview_enable,
    input  logic [8:0]  current_emoji_x,
    input  logic [8:0]  current_emoji_y,
    input  logic [2:0]  current_emoji_type,

    input  logic [2:0]  emoji_count,
    input  logic [8:0]  emoji_x [0:MAX_EMOJI-1],
    input  logic [8:0]  emoji_y [0:MAX_EMOJI-1],
    input  logic [2:0]  emoji_type [0:MAX_EMOJI-1],

    output logic [3:0]  r_out,
    output logic [3:0]  g_out,
    output logic [3:0]  b_out
);

    //==========================================================
    // ROM: emoji_all.mem (6개의 emoji가 연속으로 저장됨)
    //==========================================================
    localparam BLOCK_SIZE = EMOJI_SIZE * EMOJI_SIZE;  // 4096
    localparam TOTAL_SIZE = BLOCK_SIZE * EMOJI_COUNT; // 4096*6 = 24576

    logic [$clog2(TOTAL_SIZE)-1:0] rom_addr;
    logic [15:0] rom_data;

    EmojiROM #(
        .W(EMOJI_SIZE),
        .H(EMOJI_SIZE*EMOJI_COUNT),
        .MEM_FILE("emoji_all.mem")
    ) ROM0 (
        .clk (clk),
        .addr(rom_addr),
        .data(rom_data)
    );

    //==========================================================
    // 어떤 emoji가 현재 픽셀을 덮는지 판정
    //==========================================================
    logic hit;
    logic [2:0] hit_type;
    logic [9:0] hit_x, hit_y;

    always_comb begin
        hit      = 1'b0;
        hit_type = 0;
        hit_x    = 0;
        hit_y    = 0;

        // ---- preview ----
        if (sw0_edit_mode && preview_enable) begin
            automatic logic [9:0] vx = {current_emoji_x, 1'b0};
            automatic logic [9:0] vy = {current_emoji_y, 1'b0};

            if (x_pixel >= vx && x_pixel < (vx + EMOJI_SIZE) &&
                y_pixel >= vy && y_pixel < (vy + EMOJI_SIZE)) begin
                hit      = 1;
                hit_type = current_emoji_type;
                hit_x    = vx;
                hit_y    = vy;
            end
        end

        // ---- saved emojis ----
        if (!hit) begin
            for (int i = 0; i < MAX_EMOJI; i++) begin
                if (i < emoji_count) begin
                    automatic logic [9:0] vx = {emoji_x[i], 1'b0};
                    automatic logic [9:0] vy = {emoji_y[i], 1'b0};

                    if (x_pixel >= vx && x_pixel < (vx + EMOJI_SIZE) &&
                        y_pixel >= vy && y_pixel < (vy + EMOJI_SIZE)) begin
                        hit      = 1;
                        hit_type = emoji_type[i];
                        hit_x    = vx;
                        hit_y    = vy;
                    end
                end
            end
        end
    end

    //==========================================================
    // ROM 주소 산출 (핵심)
    //==========================================================
    logic [11:0] local_x, local_y;
    logic [$clog2(BLOCK_SIZE)-1:0] pixel_addr;
    logic [$clog2(TOTAL_SIZE)-1:0] emoji_addr;

    assign local_x    = x_pixel - hit_x;
    assign local_y    = y_pixel - hit_y;
    assign pixel_addr = local_y * EMOJI_SIZE + local_x;

    assign emoji_addr = hit_type * BLOCK_SIZE;      // 이모티콘 종류 offset
    assign rom_addr   = hit ? (emoji_addr + pixel_addr) : 0;

    //==========================================================
    // 색상 출력
    //==========================================================
    logic [3:0] er = rom_data[15:12];
    logic [3:0] eg = rom_data[10:7];
    logic [3:0] eb = rom_data[4:1];

    logic transparent = (rom_data == 16'hCE7E);

    assign r_out = (hit && !transparent) ? er : bg_r;
    assign g_out = (hit && !transparent) ? eg : bg_g;
    assign b_out = (hit && !transparent) ? eb : bg_b;

endmodule
