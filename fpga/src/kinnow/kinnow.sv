`timescale 1ns / 1ps
`default_nettype none

module kinnow (
    input wire clk,
    input wire rst,
    input wire pix_clk,
    input wire pix_rst,

    output wire        m_axi_arvalid,
	input  wire        m_axi_arready,
	output wire [31:0] m_axi_araddr,
	output wire [ 7:0] m_axi_arlen,
	output wire [ 2:0] m_axi_arsize,
	output wire [ 1:0] m_axi_arburst,

	input  wire 	   m_axi_rvalid,
	output wire        m_axi_rready,
	input  wire [31:0] m_axi_rdata,
	input  wire [ 1:0] m_axi_rresp,

    output wire       hs,               
    output wire       vs,               
    output wire       de,               
    output wire [7:0] red,
    output wire [7:0] green,
    output wire [7:0] blue
);
    localparam REQ_TIMER = 8'd30;
    wire req_empty_n;
    wire req_full_n;
    wire [19:0] req_dout;

    wire req_deq; 

    ////////////////////////
    // Address generator //
    //////////////////////
    reg [19:0] screen_ptr = 0;
    // increment 64 bytes at a time, since we ask for (4bytes/word) * (16 burst len)
    wire [19:0] screen_ptr_next = screen_ptr + 20'd64;

    always_ff @(posedge clk) begin
        if (rst) screen_ptr <= 0;
        // dont increment if full, or if we already have responses (so we dont just consume the entire bus)
        else screen_ptr <= (~req_full_n) ? screen_ptr : ((screen_ptr_next == 20'hc0000) ? 0 : screen_ptr_next);
    end
    
    reg [7:0] timer_r = REQ_TIMER;

    always_ff @(posedge clk) begin
        if (rst) timer_r <= 0;
        else timer_r <= req_deq ? 0 : (timer_r == REQ_TIMER ? REQ_TIMER : timer_r + 1);
    end

    /////////////////
    // AXI master //
    ///////////////    

    assign req_deq = m_axi_arready & req_empty_n & (timer_r == REQ_TIMER);
    SizedFIFO #(
        .p1width(20),
        .p2depth(4),
        .p3cntr_width(2)
    ) iREQS (
        .CLK(clk),
        .RST(~rst),
        .D_IN(screen_ptr),
        .ENQ(req_full_n),
        .DEQ(req_deq),
        .FULL_N(req_full_n),
        .EMPTY_N(req_empty_n),
        .D_OUT(req_dout),
        .CLR(1'b0)
    );

    wire resp_empty_n;
    wire resp_full_n;
    wire [31:0] resp_dout;
    wire resp_deq;

    SyncFIFO #(
        .dataWidth(32),
        .depth(32),
        .indxWidth(5)
    ) iRESPS (
        .sCLK(clk),
        .sRST(~rst),
        .dCLK(pix_clk),
        .sENQ(m_axi_rvalid & resp_full_n),
        .sD_IN(m_axi_rdata),
        .sFULL_N(resp_full_n),
        .dDEQ(resp_deq),
        .dD_OUT(resp_dout),
        .dEMPTY_N(resp_empty_n)
    );

    //////////////
    // display //
    ////////////

    display iDISPLAY (
        .pix_clk(pix_clk),
        .rst(pix_rst),
        .pixel_empty_n(resp_empty_n),
        .pixel_word(resp_dout),
        .pixel_deq(resp_deq),
        .hs(hs),
        .vs(vs),
        .de(de),
        .red(red),
        .green(green),
        .blue(blue)
    );

    assign m_axi_arvalid = req_empty_n;
    assign m_axi_araddr = {12'hC01, req_dout};
    assign m_axi_arlen = 8'hF; // idk
    assign m_axi_arsize = 3'b010;
    assign m_axi_arburst = 2'b01;
    assign m_axi_rready = resp_full_n;
endmodule

`default_nettype wire