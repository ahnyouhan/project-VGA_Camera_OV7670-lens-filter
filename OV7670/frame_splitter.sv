`timescale 1ns / 1ps

module frame_splitter (
    input  logic clk,
    input  logic reset,
    input  logic start,
    output logic busy,

    // VGA state
    input  logic        de,
    // frame_buffer read port
    output logic [16:0] rd_addr,
    input  logic [15:0] rd_data,

    // UART TX interface
    input  logic       tx_fifo_full,
    output logic       tx_fifo_push,
    output logic [7:0] tx_fifo_data
);
    localparam N_PIXELS = 320 * 240;

    typedef enum logic [1:0] {
        IDLE,
        SEND_FRONT,
        SEND_BACK
    } state_t;
    state_t state;

    logic [16:0] addr;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state        <= IDLE;
            addr         <= 0;
            tx_fifo_push <= 0;
            tx_fifo_data <= 0;
        end else begin
            tx_fifo_push <= 0;
            tx_fifo_data <= 0;

            case (state)
                IDLE: begin
                    if (start) begin
                        addr  <= 0;
                        state <= SEND_FRONT;
                    end
                end

                SEND_FRONT: begin
                    if (!tx_fifo_full) begin
                        tx_fifo_data <= rd_data[15:8];
                        tx_fifo_push <= 1'b1;
                        state        <= SEND_BACK;
                    end
                end

                SEND_BACK: begin
                    if (!tx_fifo_full) begin
                        tx_fifo_data <= rd_data[7:0];
                        tx_fifo_push <= 1'b1;

                        if (addr == N_PIXELS - 1) begin
                            state <= IDLE;
                        end else begin
                            addr  <= addr + 1;
                            state <= SEND_FRONT;
                        end
                    end
                end
            endcase
        end
    end

    assign rd_addr = addr;
    assign busy    = (state != IDLE);
endmodule
