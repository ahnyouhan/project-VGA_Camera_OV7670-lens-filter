`timescale 1ns / 1ps

module OV7670_CCTV_TOP (
    input  logic       clk,
    input  logic       reset,
    output logic       LED,
    // ov7670 side
    output logic       xclk,
    input  logic       pclk,
    input  logic       href,
    input  logic       vsync,
    input  logic [7:0] data,
    // vga port
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] r_port,
    output logic [3:0] g_port,
    output logic [3:0] b_port,
    // PC port
    input  logic       rx,
    output logic       tx,
    // capture trigger
    input  logic       save_btn,
    // frame stop btn
    input  logic       freeze_sw,
    // output scl, sda
    output logic       scl,
    output logic       sda

);

    logic        tx_fifo_full;
    logic        tx_fifo_push;
    logic [ 7:0] tx_fifo_data;

    logic        saving;
    logic [16:0] save_rAddr;
    logic [15:0] ram_rData;

    logic        o_DE;

    assign LED = saving;

    OV7670_CCTV U_OV7670_CCTV (.*);

    frame_splitter U_FRAME_SPLITTER (
        .clk         (xclk),
        .reset       (reset),
        .start       (save_btn),
        .busy        (saving),
        // VGA state
        .de          (o_DE),
        // frame_buffer read port
        .rd_addr     (save_rAddr),
        .rd_data     (ram_rData),
        // UART TX interface
        .tx_fifo_full(tx_fifo_full),
        .tx_fifo_push(tx_fifo_push),
        .tx_fifo_data(tx_fifo_data)
    );

    uart_top U_UART_TOP (
        .clk            (clk),
        .reset          (reset),
        .i_rx           (rx),
        .i_tx_fifo_push (tx_fifo_push),
        .i_tx_fifo_data (tx_fifo_data),
        .o_tx           (tx),
        .o_tx_fifo_full (tx_fifo_full),
        .o_rx_fifo_empty(),
        .o_rx_fifo_data ()
    );
endmodule

