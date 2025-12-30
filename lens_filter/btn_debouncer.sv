`timescale 1ns / 1ps

module btn_debouncer (
    input  logic clk,
    input  logic reset,
    input  logic btn_in,
    output logic btn_out
);
    localparam DEBOUNCE_COUNT = 1_000_000;  // 10ms @ 100MHz
    
    logic [19:0] counter;
    logic btn_sync_0, btn_sync_1;
    logic btn_stable;

    // 2-stage synchronizer
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            btn_sync_0 <= 1'b0;
            btn_sync_1 <= 1'b0;
        end else begin
            btn_sync_0 <= btn_in;
            btn_sync_1 <= btn_sync_0;
        end
    end

    // Debounce counter
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            counter <= 0;
            btn_stable <= 1'b0;
        end else begin
            if (btn_sync_1 != btn_stable) begin
                if (counter == DEBOUNCE_COUNT - 1) begin
                    counter <= 0;
                    btn_stable <= btn_sync_1;
                end else begin
                    counter <= counter + 1;
                end
            end else begin
                counter <= 0;
            end
        end
    end

    assign btn_out = btn_stable;

endmodule

module btn_debouncer_5 (
    input  logic clk,
    input  logic reset,
    input  logic [4:0] btn_in,
    output logic [4:0] btn_out
);
    genvar i;
    generate
        for (i = 0; i < 5; i++) begin : gen_debouncer
            btn_debouncer u_debouncer (
                .clk(clk),
                .reset(reset),
                .btn_in(btn_in[i]),
                .btn_out(btn_out[i])
            );
        end
    endgenerate
endmodule
