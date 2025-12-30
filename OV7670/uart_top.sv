`timescale 1ns / 1ps

module uart_top (
    input        clk,
    input        reset,
    input        i_rx,

    input        i_tx_fifo_push,
    input  [7:0] i_tx_fifo_data,
    output       o_tx,
    output       o_rx_fifo_empty,
    output [7:0] o_rx_fifo_data,
    output       o_tx_fifo_full
);
    wire       w_baud_tick;
    wire       w_rx_done;
    wire [7:0] w_rx_data;
    wire [7:0] w_tx_fifo_data;
    wire       w_rx_fifo_empty;
    wire       w_tx_fifo_full;
    wire       w_tx_fifo_empty;
    wire       w_tx_busy;

    assign o_rx_fifo_empty = ~w_rx_fifo_empty;
    assign o_tx_busy = w_tx_busy;

    uart_tx U_UART_TX (
        .clk            (clk),
        .reset          (reset),
        .i_start_trigger(~w_tx_fifo_empty),
        .i_tx_data      (w_tx_fifo_data),
        .i_baud_tick    (w_baud_tick),
        .o_tx           (o_tx),
        .o_tx_busy      (w_tx_busy)
    );

    fifo #(
        .BIT_WIDTH(8),
        .WORD_DEPTH(16),
        .WORD_DEPTH_BIT(4)
    ) U_TX_FIFO (
        .clk        (clk),
        .reset      (reset),
        .i_push_data(i_tx_fifo_data),
        .i_push     (i_tx_fifo_push),
        .i_pop      (~w_tx_busy),
        .o_pop_data (w_tx_fifo_data),
        .o_full     (o_tx_fifo_full),
        .o_empty    (w_tx_fifo_empty)

    );

    fifo #(
        .BIT_WIDTH(8),
        .WORD_DEPTH(4),
        .WORD_DEPTH_BIT(2)
    ) U_RX_FIFO (
        .clk        (clk),
        .reset      (reset),
        .i_push_data(w_rx_data),
        .i_push     (w_rx_done),
        .i_pop      (~w_rx_fifo_empty),
        .o_pop_data (o_rx_fifo_data),
        .o_full     (),
        .o_empty    (w_rx_fifo_empty)
    );

    uart_rx U_UART_RX (
        .clk        (clk),
        .reset      (reset),
        .i_rx       (i_rx),
        .i_baud_tick(w_baud_tick),
        .o_rx_data  (w_rx_data),
        .o_rx_done  (w_rx_done)
    );

    baud_tick_gen U_BAUD_TICK_GEN (
        .clk(clk),
        .reset(reset),
        .o_baud_tick(w_baud_tick)
    );


endmodule

module baud_tick_gen (
    input  logic clk,
    input  logic reset,
    output logic o_baud_tick
);

    // baudrate
    // parameter BAUDRATE = 9600 * 16;
    parameter BAUDRATE = 115200 * 16;

    // localparam BAUD_count = 100_000_000 / BAUDRATE;
    localparam BAUD_count = 100_000_000 / BAUDRATE;
    logic [$clog2(BAUD_count)-1:0] counter_reg, counter_next;
    logic tick_reg, tick_next;

    // output
    assign o_baud_tick = tick_reg;

    //SL
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            tick_reg <= 0;
        end else begin
            counter_reg <= counter_next;
            tick_reg    <= tick_next;
        end
    end

    // next CL
    always @(*) begin
        counter_next = counter_reg;
        tick_next    = tick_reg;
        if (counter_reg == BAUD_count - 1) begin
            counter_next = 0;
            tick_next = 1'b1;
        end else begin
            counter_next = counter_reg + 1;
            tick_next = 1'b0;

        end
    end


endmodule
