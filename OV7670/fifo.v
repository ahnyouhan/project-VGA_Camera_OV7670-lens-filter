`timescale 1ns / 1ps

module fifo #(
    parameter BIT_WIDTH = 8,
    WORD_DEPTH = 4,
    WORD_DEPTH_BIT = 2
) (
    input                  clk,
    input                  reset,
    input  [BIT_WIDTH-1:0] i_push_data,
    input                  i_push,
    input                  i_pop,
    output [BIT_WIDTH-1:0] o_pop_data,
    output                 o_full,
    output                 o_empty
);

    wire [WORD_DEPTH_BIT-1:0] w_wptr, w_rptr;

    register_file #(
        .BIT_WIDTH(BIT_WIDTH),
        .WORD_DEPTH(WORD_DEPTH),
        .WORD_DEPTH_BIT(WORD_DEPTH_BIT)
    ) U_REG_FILE (
        .clk(clk),
        .i_wptr(w_wptr),
        .i_rptr(w_rptr),
        .i_push_data(i_push_data),
        .i_wr(~o_full & i_push),
        .o_pop_data(o_pop_data)
    );

    fifo_cu #(
        .BIT_WIDTH(BIT_WIDTH),
        .WORD_DEPTH(WORD_DEPTH),
        .WORD_DEPTH_BIT(WORD_DEPTH_BIT)
    ) U_FIFO_CU (
        .clk(clk),
        .reset(reset),
        .i_push(i_push),
        .i_pop(i_pop),
        .o_wptr(w_wptr),
        .o_rptr(w_rptr),
        .o_full(o_full),
        .o_empty(o_empty)
    );

endmodule

module register_file #(
    parameter BIT_WIDTH = 8,
    WORD_DEPTH = 4,
    WORD_DEPTH_BIT = 2
) (
    input                       clk,
    input  [WORD_DEPTH_BIT-1:0] i_wptr,
    input  [WORD_DEPTH_BIT-1:0] i_rptr,
    input  [               7:0] i_push_data,
    input                       i_wr,
    output [               7:0] o_pop_data
);

    reg [BIT_WIDTH-1:0] ram[0:WORD_DEPTH-1];
    reg [BIT_WIDTH-1:0] rdata_reg;
    // output CL
    assign o_pop_data = rdata_reg;

    always @(posedge clk) begin
        if (i_wr) begin
            ram[i_wptr] <= i_push_data;
        end
        rdata_reg <= ram[i_rptr];
    end

endmodule

module fifo_cu #(
    parameter BIT_WIDTH = 8,
    WORD_DEPTH = 4,
    WORD_DEPTH_BIT = 2
) (
    input                       clk,
    input                       reset,
    input                       i_push,
    input                       i_pop,
    output [WORD_DEPTH_BIT-1:0] o_wptr,
    output [WORD_DEPTH_BIT-1:0] o_rptr,
    output                      o_full,
    output                      o_empty
);

    // output
    reg [WORD_DEPTH_BIT-1:0] wptr_reg, wptr_next;
    reg [WORD_DEPTH_BIT-1:0] rptr_reg, rptr_next;
    reg full_reg, full_next;
    reg empty_reg, empty_next;

    assign o_wptr  = wptr_reg;
    assign o_rptr  = rptr_reg;
    assign o_full  = full_reg;
    assign o_empty = empty_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            wptr_reg  <= 0;
            rptr_reg  <= 0;
            full_reg  <= 0;
            empty_reg <= 1'b1;
        end else begin
            wptr_reg  <= wptr_next;
            rptr_reg  <= rptr_next;
            full_reg  <= full_next;
            empty_reg <= empty_next;
        end
    end

    always @(*) begin
        wptr_next  = wptr_reg;
        rptr_next  = rptr_reg;
        full_next  = full_reg;
        empty_next = empty_reg;
        case ({
            i_push, i_pop
        })
            2'b01: begin
                //pop
                full_next = 1'b0;
                if (!empty_reg) begin
                    rptr_next = rptr_reg + 1;
                    if (wptr_reg == rptr_next) begin
                        empty_next = 1'b1;
                    end
                end
            end
            2'b10: begin
                // push
                empty_next = 1'b0;
                if (!full_reg) begin
                    wptr_next = wptr_reg + 1;
                    if (wptr_next == rptr_reg) begin
                        full_next = 1'b1;
                    end
                end
            end
            2'b11: begin
                // push&pop
                if (empty_reg == 1'b1) begin
                    wptr_next  = wptr_reg + 1;
                    empty_next = 1'b0;
                end else if (full_reg == 1'b1) begin
                    rptr_next = rptr_reg + 1;
                    full_next = 1'b0;
                end else begin
                    // not be full, empty
                    wptr_next = wptr_reg + 1;
                    rptr_next = rptr_reg + 1;
                end
            end
        endcase
    end

endmodule
