`timescale 1ns / 1ps

module OV7670_CCTV (
    input  logic        clk,
    input  logic        reset,
    // ov7670 side
    output logic        xclk,
    input  logic        pclk,
    input  logic        href,
    input  logic        vsync,
    input  logic [ 7:0] data,
    // vga port
    output logic        h_sync,
    output logic        v_sync,
    output logic [ 3:0] r_port,
    output logic [ 3:0] g_port,
    output logic [ 3:0] b_port,
    // frame splitter port
    input  logic        saving,
    input  logic [16:0] save_rAddr,
    output logic [15:0] ram_rData,
    // frame stop btn
    input  logic        freeze_sw,
    // output scl, sda
    output logic        scl,
    output logic        sda,

    output logic o_DE
);
    logic        sys_clk;
    logic        DE;
    logic [ 9:0] x_pixel;
    logic [ 9:0] y_pixel;
    logic [16:0] vga_rAddr;
    logic [16:0] ram_rAddr;
    logic        we_cam;
    logic        we_ram;
    logic [16:0] wAddr;
    logic [15:0] wData;

    assign xclk = sys_clk;
    assign we_ram = we_cam & ~freeze_sw;
    assign ram_rAddr = saving ? save_rAddr : vga_rAddr;
    assign o_DE = DE;

    pixel_clk_gen U_PXL_CLK_GEN (
        .clk  (clk),
        .reset(reset),
        .pclk (sys_clk)
    );

    VGA_Syncher VGA_Syncher (
        .clk    (sys_clk),
        .reset  (reset),
        .h_sync (h_sync),
        .v_sync (v_sync),
        .DE     (DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel)
    );

    ImgMemReader U_IMG_Reader (
        .DE     (DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .addr   (vga_rAddr),
        .imgData(ram_rData),
        .r_port (r_port),
        .g_port (g_port),
        .b_port (b_port)
    );

    frame_buffer U_Frame_Buffer (
        .wclk (pclk),
        .we   (we_ram),
        .wAddr(wAddr),
        .wData(wData),
        .rclk (sys_clk),
        .oe   (1'b1),
        .rAddr(ram_rAddr),
        .rData(ram_rData)
    );

    OV7670_Mem_Controller U_OV7670_Mem_Controller (
        .pclk (pclk),
        .reset(reset),
        .href (href),
        .vsync(vsync),
        .data (data),
        .we   (we_cam),
        .wAddr(wAddr),
        .wData(wData)
    );

    sccbTop u_sccb (
        .clk,
        .reset,
        .sda,
        .scl
    );
endmodule
