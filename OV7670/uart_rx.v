`timescale 1ns / 1ps


module uart_rx (
    input        clk,
    input        reset,
    input        i_rx,
    input        i_baud_tick,
    output [7:0] o_rx_data,
    output       o_rx_done
);

    localparam [1:0] IDLE = 0, START = 1, DATA = 2, STOP = 3;
    //state
    reg [1:0] current_state, next_state;
    // tick count
    reg [4:0] baud_tick_cnt_reg, baud_tick_cnt_next;
    // bit count
    reg [3:0] bit_cnt_reg, bit_cnt_next;
    // output
    reg rx_done_reg, rx_done_next;
    // rx_internal buffer
    reg [7:0] rx_buf_reg, rx_buf_next;

    // output
    assign o_rx_data = rx_buf_reg;
    assign o_rx_done = rx_done_reg;


    // state 
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_state     <= IDLE;
            baud_tick_cnt_reg <= 0;
            bit_cnt_reg       <= 0;
            rx_done_reg       <= 0;
            rx_buf_reg        <= 0;
        end else begin
            current_state     <= next_state;
            baud_tick_cnt_reg <= baud_tick_cnt_next;
            bit_cnt_reg       <= bit_cnt_next;
            rx_done_reg       <= rx_done_next;
            rx_buf_reg        <= rx_buf_next;
        end
    end

    always @(*) begin
        next_state         = current_state;
        baud_tick_cnt_next = baud_tick_cnt_reg;
        bit_cnt_next       = bit_cnt_reg;
        rx_done_next       = rx_done_reg;
        rx_buf_next        = rx_buf_reg;
        case (current_state)
            IDLE: begin
                rx_done_next = 1'b0;
                if (i_baud_tick) begin
                    if (!i_rx) begin
                        baud_tick_cnt_next = 0;
                        next_state = START;
                    end
                end
            end

            START: begin
                if (i_baud_tick) begin
                    if (baud_tick_cnt_reg == 23) begin
                        bit_cnt_next = 0;
                        baud_tick_cnt_next = 0;
                        next_state = DATA;
                    end else begin
                        baud_tick_cnt_next = baud_tick_cnt_reg + 1;
                    end
                end
            end

            DATA: begin
                if (i_baud_tick) begin
                    if (baud_tick_cnt_reg == 0) begin
                        rx_buf_next[7] = i_rx;
                    end
                    if (baud_tick_cnt_reg == 15) begin
                        if (bit_cnt_reg == 7) begin
                            next_state = STOP;
                        end else begin
                            baud_tick_cnt_next = 0;
                            bit_cnt_next    = bit_cnt_reg + 1;
                            rx_buf_next = rx_buf_reg >> 1;
                        end
                    end else begin
                        baud_tick_cnt_next = baud_tick_cnt_reg + 1;
                    end
                end
            end

            STOP: begin
                if (i_baud_tick) begin
                    rx_done_next = 1'b1;
                    next_state   = IDLE;
                end
            end
        endcase
    end
endmodule
