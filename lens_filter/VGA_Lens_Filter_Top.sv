`timescale 1ns / 1ps

//=============================================================================
// VGA Lens Filter + Emoji Overlay Top Module (FIXED)
//=============================================================================
// 수정사항:
// 1. sw0_falling을 emoji_selector에 연결 → sw0 LOW 시 이모티콘 리셋
//=============================================================================

module VGA_Lens_Filter_Top #(
    parameter IMG_WIDTH = 320,
    parameter IMG_HEIGHT = 240,
    parameter MAX_LENS = 8,
    parameter EMOJI_SIZE = 64,
    parameter MAX_EMOJI = 8,
    parameter NUM_EMOJI_TYPES = 6
) (
    input  logic       clk,
    input  logic       reset,
    // Switches
    input  logic       sw0,          // edit_mode (볼록렌즈)
    input  logic       sw1,          // size_mode (radius 조절)
    input  logic       sw2,          // k_mode (굴절률 조절)
    input  logic       sw3,          // emoji_mode (이모티콘)
    input  logic       sw14,         // save trigger
    // Buttons
    input  logic       btnU,
    input  logic       btnD,
    input  logic       btnL,
    input  logic       btnR,
    input  logic       btnC,
    // VGA outputs
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] r_port,
    output logic [3:0] g_port,
    output logic [3:0] b_port,
    // Save signal output
    output logic       save_trigger
);

    //=========================================================================
    // Internal Signals
    //=========================================================================
    logic pclk;
    logic DE;
    logic [9:0] x_pixel, y_pixel;

    // ROM interface
    logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] addr;
    logic [15:0] imgData;

    // Button debouncing
    logic [4:0] btn_raw, btn_debounced;
    assign btn_raw = {btnC, btnR, btnL, btnD, btnU};

    logic btn_u_db, btn_d_db, btn_l_db, btn_r_db, btn_c_db;
    assign {btn_c_db, btn_r_db, btn_l_db, btn_d_db, btn_u_db} = btn_debounced;

    // Edge detection
    logic sw0_falling, sw3_falling;
    logic sw14_rising;

    // Lens filter outputs
    logic [8:0] lens_current_x;
    logic [7:0] lens_current_y;
    logic [7:0] lens_R, lens_K;
    logic       lens_preview_enable;
    logic [2:0] lens_count;
    logic [8:0] lens_center_x       [0:MAX_LENS-1];
    logic [7:0] lens_center_y       [0:MAX_LENS-1];
    logic [7:0] lens_R_array        [0:MAX_LENS-1];
    logic [7:0] lens_K_array        [0:MAX_LENS-1];
    logic       lens_save_trigger;

    // Lens filter RGB output (배경 for emoji)
    logic [3:0] lens_r, lens_g, lens_b;

    // Emoji selector outputs
    logic [8:0] emoji_current_x;
    logic [8:0] emoji_current_y;
    logic [2:0] emoji_current_type;
    logic emoji_preview_enable;
    logic emoji_selection_mode;
    logic [2:0] emoji_count;
    logic [8:0] emoji_x[0:MAX_EMOJI-1];
    logic [8:0] emoji_y[0:MAX_EMOJI-1];
    logic [2:0] emoji_type[0:MAX_EMOJI-1];

    // Final RGB output
    logic [3:0] final_r, final_g, final_b;

    //=========================================================================
    // VGA Timing Generator
    //=========================================================================
    VGA_Decoder U_VGA_Decoder (
        .clk(clk),
        .reset(reset),
        .pclk(pclk),
        .h_sync(h_sync),
        .v_sync(v_sync),
        .DE(DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel)
    );

    //=========================================================================
    // Image ROM
    //=========================================================================
    ImgROM #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_ROM (
        .clk (clk),
        .pclk(pclk),
        .addr(addr),
        .data(imgData)
    );

    //=========================================================================
    // Button Debouncer
    //=========================================================================
    btn_debouncer_5 U_Btn_Debouncer (
        .clk(clk),
        .reset(reset),
        .btn_in(btn_raw),
        .btn_out(btn_debounced)
    );

    //=========================================================================
    // Edge Detectors
    //=========================================================================
    edge_detector U_SW0_Edge (
        .clk(clk),
        .reset(reset),
        .signal(sw0),
        .rising_edge(),
        .falling_edge(sw0_falling)
    );

    edge_detector U_SW3_Edge (
        .clk(clk),
        .reset(reset),
        .signal(sw3),
        .rising_edge(),
        .falling_edge(sw3_falling)
    );

    edge_detector U_SW14_Edge (
        .clk(clk),
        .reset(reset),
        .signal(sw14),
        .rising_edge(sw14_rising),
        .falling_edge()
    );

    //=========================================================================
    // Lens Area Selector
    //=========================================================================
    area_selector #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .MAX_LENS  (MAX_LENS)
    ) U_Lens_Selector (
        .clk(clk),
        .reset(reset),
        .sw0_edit_mode(sw0),
        .sw0_falling(sw0_falling),
        .sw1_size_mode(sw1),
        .sw2_k_mode(sw2),
        .sw3_emoji_mode(sw3),
        .sw14_rising(sw14_rising),
        .btn_u(btn_u_db),
        .btn_d(btn_d_db),
        .btn_l(btn_l_db),
        .btn_r(btn_r_db),
        .btn_c(btn_c_db),
        .current_center_x(lens_current_x),
        .current_center_y(lens_current_y),
        .current_R(lens_R),
        .current_K(lens_K),
        .preview_enable(lens_preview_enable),
        .lens_count(lens_count),
        .lens_center_x(lens_center_x),
        .lens_center_y(lens_center_y),
        .lens_R(lens_R_array),
        .lens_K(lens_K_array),
        .save_trigger(lens_save_trigger)
    );

    //=========================================================================
    // Lens Filter + Image Reader
    //=========================================================================
    ImgMemReader_lens #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .MAX_LENS  (MAX_LENS)
    ) U_ImgMemReader (
        .clk(clk),
        .reset(reset),
        .pclk(pclk),
        .DE(DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .current_center_x(lens_current_x),
        .current_center_y(lens_current_y),
        .current_R(lens_R),
        .current_K(lens_K),
        .sw0_edit_mode(sw0),
        .preview_enable(lens_preview_enable),
        .lens_count(lens_count),
        .lens_center_x(lens_center_x),
        .lens_center_y(lens_center_y),
        .lens_R(lens_R_array),
        .lens_K(lens_K_array),
        .addr(addr),
        .imgData(imgData),
        .r_port(lens_r),
        .g_port(lens_g),
        .b_port(lens_b)
    );

    //=========================================================================
    // Emoji Selector (sw0_falling 추가!)
    //=========================================================================
    emoji_selector #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .EMOJI_SIZE(EMOJI_SIZE),
        .MAX_EMOJI(MAX_EMOJI),
        .NUM_EMOJI_TYPES(NUM_EMOJI_TYPES)
    ) U_Emoji_Selector (
        .clk(clk),
        .reset(reset),
        .sw0_edit_mode(sw0),
        .sw0_falling(sw0_falling),      // 추가!
        .sw3_emoji_mode(sw3),
        .sw3_falling(sw3_falling),
        .btn_u(btn_u_db),
        .btn_d(btn_d_db),
        .btn_l(btn_l_db),
        .btn_r(btn_r_db),
        .btn_c(btn_c_db),
        .current_emoji_x(emoji_current_x),
        .current_emoji_y(emoji_current_y),
        .current_emoji_type(emoji_current_type),
        .preview_enable(emoji_preview_enable),
        .selection_mode(emoji_selection_mode),
        .emoji_count(emoji_count),
        .emoji_x(emoji_x),
        .emoji_y(emoji_y),
        .emoji_type(emoji_type)
    );

    //=========================================================================
    // Emoji Overlay
    //=========================================================================
    emoji_overlay #(
        .EMOJI_SIZE(EMOJI_SIZE),
        .MAX_EMOJI(MAX_EMOJI),
        .EMOJI_COUNT(NUM_EMOJI_TYPES)
    ) U_Emoji_Overlay (
        .clk(clk),
        .reset(reset),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .bg_r(lens_r),
        .bg_g(lens_g),
        .bg_b(lens_b),
        .sw0_edit_mode(sw0),
        .current_emoji_x(emoji_current_x),
        .current_emoji_y(emoji_current_y),
        .current_emoji_type(emoji_current_type),
        .preview_enable(emoji_preview_enable),
        .emoji_count(emoji_count),
        .emoji_x(emoji_x),
        .emoji_y(emoji_y),
        .emoji_type(emoji_type),
        .r_out(final_r),
        .g_out(final_g),
        .b_out(final_b)
    );

    //=========================================================================
    // Output Assignment
    //=========================================================================
    assign r_port = final_r;
    assign g_port = final_g;
    assign b_port = final_b;
    assign save_trigger = lens_save_trigger;

endmodule