`timescale 1ns / 1ps

module VGA_Decoder (
    input  logic       clk,
    input  logic       reset,
    output logic       pclk,        // 25MHz enable 신호 (4클럭당 1틱)
    output logic       h_sync,
    output logic       v_sync,
    output logic       DE,
    output logic [9:0] x_pixel,
    output logic [9:0] y_pixel
);
    logic [9:0] h_counter;
    logic [9:0] v_counter;

    pixel_clk_gen U_Pixel_Clk_Gen (
        .clk(clk),
        .reset(reset),
        .pclk(pclk)
    );
    
    pixel_counter U_Pixel_Counter (
        .clk(clk),
        .reset(reset),
        .pclk(pclk),
        .h_counter(h_counter),
        .v_counter(v_counter)
    );
    
    vgaDecoder U_VGA_Decoder (
        .h_counter(h_counter),
        .v_counter(v_counter),
        .h_sync(h_sync),
        .v_sync(v_sync),
        .DE(DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel)
    );

endmodule

//=============================================================================
// 25MHz enable 신호 생성 (100MHz / 4 = 25MHz)
//=============================================================================
module pixel_clk_gen (
    input  logic clk,
    input  logic reset,
    output logic pclk
);
    logic [1:0] p_counter;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            p_counter <= 0;
            pclk      <= 1'b0;
        end else begin
            if (p_counter == 3) begin
                p_counter <= 0;
                pclk      <= 1'b1;
            end else begin
                p_counter <= p_counter + 1;
                pclk      <= 1'b0;
            end
        end
    end
endmodule

//=============================================================================
// Pixel Counter - 100MHz 클럭, pclk enable 사용
//=============================================================================
module pixel_counter (
    input  logic       clk,
    input  logic       reset,
    input  logic       pclk,        // enable 신호
    output logic [9:0] h_counter,
    output logic [9:0] v_counter
);
    localparam H_MAX = 800, V_MAX = 525;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            h_counter <= 0;
        end else if (pclk) begin
            if (h_counter == H_MAX - 1)
                h_counter <= 0;
            else
                h_counter <= h_counter + 1;
        end
    end

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            v_counter <= 0;
        end else if (pclk) begin
            if (h_counter == H_MAX - 1) begin
                if (v_counter == V_MAX - 1)
                    v_counter <= 0;
                else
                    v_counter <= v_counter + 1;
            end
        end
    end
endmodule

module vgaDecoder (
    input  logic [9:0] h_counter,
    input  logic [9:0] v_counter,
    output logic       h_sync,
    output logic       v_sync,
    output logic       DE,
    output logic [9:0] x_pixel,
    output logic [9:0] y_pixel
);
    localparam H_Visible_area = 640;
    localparam H_Front_porch = 16;
    localparam H_Sync_pulse = 96;
    localparam H_Back_porch = 48;

    localparam V_Visible_area = 480;
    localparam V_Front_porch = 10;
    localparam V_Sync_pulse = 2;
    localparam V_Back_porch = 33;

    assign h_sync = !((h_counter >= H_Visible_area + H_Front_porch) && 
                      (h_counter < H_Visible_area + H_Front_porch + H_Sync_pulse));
    assign v_sync = !((v_counter >= V_Visible_area + V_Front_porch) && 
                      (v_counter < V_Visible_area + V_Front_porch + V_Sync_pulse));
    assign DE = (h_counter < H_Visible_area) && (v_counter < V_Visible_area);
    assign x_pixel = h_counter;
    assign y_pixel = v_counter;
endmodule
