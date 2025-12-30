`timescale 1ns / 1ps

module uart_tx (
    input        clk,
    input        reset,
    input        i_start_trigger,
    input  [7:0] i_tx_data,
    input        i_baud_tick,
    output       o_tx,
    output       o_tx_busy
);

    // fsm state
    localparam [2:0] IDLE = 3'h0, WAIT = 3'h1, START = 3'h2, DATA = 3'h3, STOP = 3'h4;

    // state 
    reg [2:0] current_state, next_state;
    // bit control reg
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    // b_tick count
    reg [3:0] baud_tick_cnt_reg, baud_tick_cnt_next;
    // tx internal buffer 
    reg [7:0] data_reg, data_next;
    reg tx_busy_reg, tx_busy_next;

    // output
    reg tx_reg, tx_next;
    // output tx
    assign o_tx = tx_reg;
    assign o_tx_busy = tx_busy_reg;

    // state register
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_state     <= IDLE;
            tx_reg            <= 1'b1;  // idle output is high 
            baud_tick_cnt_reg <= 0;
            bit_cnt_reg       <= 0;
            data_reg          <= 0;
            tx_busy_reg       <= 0;
        end else begin
            current_state     <= next_state;
            tx_reg            <= tx_next;
            baud_tick_cnt_reg <= baud_tick_cnt_next;
            bit_cnt_reg       <= bit_cnt_next;
            data_reg          <= data_next;
            tx_busy_reg       <= tx_busy_next;
        end
    end

    // next combinational logic
    always @(*) begin
        // to remove latch
        next_state         = current_state;
        tx_next            = tx_reg;
        baud_tick_cnt_next = baud_tick_cnt_reg;
        bit_cnt_next       = bit_cnt_reg;
        data_next          = data_reg;
        tx_busy_next       = tx_busy_reg;
        case (current_state)
            IDLE: begin
                //output tx
                tx_next      = 1'b1;
                tx_busy_next = 1'b0;
                if (i_start_trigger == 1'b1) begin
                    tx_busy_next = 1'b1;
                    data_next    = i_tx_data;
                    next_state   = WAIT;
                end
            end

            WAIT: begin
                if (i_baud_tick) begin
                    baud_tick_cnt_next = 0;
                    next_state = START;
                end
            end

            START: begin
                //output tx
                tx_next = 1'b0;
                if (i_baud_tick) begin
                    if (baud_tick_cnt_reg == 15) begin
                        baud_tick_cnt_next = 0;
                        bit_cnt_next       = 0;
                        next_state         = DATA;
                    end else begin
                        baud_tick_cnt_next = baud_tick_cnt_reg + 1;
                    end

                end
            end

            DATA: begin
                // output tx <= tx_data[0]
                tx_next = data_reg[0];
                if (i_baud_tick) begin
                    if (baud_tick_cnt_reg == 15) begin
                        baud_tick_cnt_next = 0;
                        if (bit_cnt_reg == 7) begin
                            next_state = STOP;
                        end else begin

                            bit_cnt_next = bit_cnt_reg + 1;
                            // next = DATA; whatever it's okay 
                            data_next = data_reg >> 1;
                        end
                    end else begin
                        baud_tick_cnt_next = baud_tick_cnt_reg + 1;
                    end
                end
            end

            STOP: begin
                tx_next = 1'b1;
                if (i_baud_tick) begin
                    if (baud_tick_cnt_reg == 15) begin
                        tx_busy_next = 1'b0;
                        next_state   = IDLE;
                    end else begin
                        baud_tick_cnt_next = baud_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule
