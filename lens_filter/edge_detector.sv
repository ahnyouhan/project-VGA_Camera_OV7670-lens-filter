`timescale 1ns / 1ps

module edge_detector (
    input  logic clk,
    input  logic reset,
    input  logic signal,
    output logic rising_edge,
    output logic falling_edge
);
    logic signal_d;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            signal_d <= 1'b0;
        end else begin
            signal_d <= signal;
        end
    end

    assign rising_edge  = signal & ~signal_d;
    assign falling_edge = ~signal & signal_d;

endmodule
