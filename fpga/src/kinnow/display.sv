`timescale 1ns / 1ps
`default_nettype none

// Project F: Display Timings
// (C)2019 Will Green, Open Source Hardware released under the MIT License
// Learn more at https://projectf.io

// Defaults to 640x480 at 60 Hz

module display #(
    H_RES=1024,                      // horizontal resolution (pixels)
    V_RES=768,                      // vertical resolution (lines)
    H_FP=48,                        // horizontal front porch
    H_SYNC=104,                      // horizontal sync
    H_BP=152,                        // horizontal back porch
    V_FP=3,                        // vertical front porch
    V_SYNC=4,                       // vertical sync
    V_BP=23,                        // vertical back porch
    H_POL=1,                        // horizontal sync polarity (0:neg, 1:pos)
    V_POL=1                         // vertical sync polarity (0:neg, 1:pos)
    )
    (
    input  wire        pix_clk,          // pixel clock
    input  wire        rst,              // reset: restarts frame (active high)
    input  wire        pixel_empty_n,
    input  wire [31:0] pixel_word,
    output wire        pixel_deq,

    output wire hs,               // horizontal sync
    output wire vs,               // vertical sync
    output wire de,               // display enable: high during active video
    output wire [7:0] red,
    output wire [7:0] green,
    output wire [7:0] blue
    );

    // Horizontal: sync, active, and pixels
    localparam signed H_STA  = 0 - H_FP - H_SYNC - H_BP;    // horizontal start
    localparam signed HS_STA = H_STA + H_FP;                // sync start
    localparam signed HS_END = HS_STA + H_SYNC;             // sync end
    localparam signed HA_STA = 0;                           // active start
    localparam signed HA_END = H_RES - 1;                   // active end

    // Vertical: sync, active, and pixels
    localparam signed V_STA  = 0 - V_FP - V_SYNC - V_BP;    // vertical start
    localparam signed VS_STA = V_STA + V_FP;                // sync start
    localparam signed VS_END = VS_STA + V_SYNC;             // sync end
    localparam signed VA_STA = 0;                           // active start
    localparam signed VA_END = V_RES - 1;                   // active end

    /////////////////////////////
    // Display position logic //
    ///////////////////////////
    reg signed [15:0] posx_r, posy_r;
    always @ (posedge pix_clk)
    begin
        if (rst)  // reset to start of frame
        begin
            posx_r <= H_STA;
            posy_r <= V_STA;
        end
        else
        begin
            if (posx_r == HA_END)  // end of line
            begin
                posx_r <= H_STA;
                if (posy_r == VA_END)  // end of frame
                    posy_r <= V_STA;
                else
                    posy_r <= posy_r + 16'sh1;
            end
            else
                posx_r <= posx_r + 16'sh1;
        end
    end

    // display enable: high during active period
    wire de_w = (posx_r >= 0 && posy_r >= 0);

    ///////////////////////
    // Color generation //
    /////////////////////
    wire [1:0] word_idx = ~posx_r[1:0];
    wire [8:0] pal_out;
    palette iPALETTE (
        .clk(pix_clk),
        // TODO: endianness?
        .idx(pixel_word[8*word_idx +: 8]),
        .pal_out(pal_out)
    );

    /////////////////////
    // Output signals //
    ///////////////////

    reg hs_r, vs_r, de_r; 

    always_ff @(posedge pix_clk) begin 
        if (rst) begin
            hs_r <= 0;
            vs_r <= 0;
            de_r <= 0;
        end else begin
            hs_r <= ~H_POL ^ (posx_r > HS_STA && posx_r <= HS_END);
            vs_r <= ~V_POL ^ (posy_r > VS_STA && posy_r <= VS_END);
            de_r <= de_w;
        end
    end
    
    
    assign pixel_deq = &(posx_r[1:0]) & de_w & pixel_empty_n;

    assign hs    = hs_r;
    assign vs    = vs_r;
    assign de    = de_r;
    assign red   = {2{pal_out[8:6], 1'b0}};
    assign green = {2{pal_out[5:3], 1'b0}};
    assign blue  = {2{pal_out[2:0], 1'b0}};
endmodule

`default_nettype wire