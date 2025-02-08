`timescale 1ns / 1ps
`default_nettype none
module LSIC (
    input wire clk,
    input wire rst_n,

    input wire [63:0] irqs,

    output wire cpu_irq,

     // AXI bus interface
    input  wire        s_axi_awvalid,
	output wire        s_axi_awready,
	input  wire [31:0] s_axi_awaddr,

	input  wire 	   s_axi_wvalid,
	output wire        s_axi_wready,
	input  wire [31:0] s_axi_wdata,
	input  wire [ 3:0] s_axi_wstrb,

	output wire  	   s_axi_bvalid,
	input  wire        s_axi_bready,
	output wire [ 1:0] s_axi_bresp,

	input  wire        s_axi_arvalid,
	output wire        s_axi_arready,
	input  wire [31:0] s_axi_araddr,

	output wire 	   s_axi_rvalid,
    output wire 	   s_axi_rlast,
	input  wire        s_axi_rready,
    output wire [31:0] s_axi_rdata,
	output wire [ 1:0] s_axi_rresp
);

    reg [63:0] disa_r;
    reg [63:0] disa_rw;

    reg [63:0] pend_r;
    reg [63:0] pend_rw_pre;
    reg [63:0] pend_rw;

    reg [5:0] ipl_r;
    reg [5:0] ipl_rw;

    // TODO: i am not sure what the consequences of registering the IRQ line are.
    // The ISR will clear the interrupt lines on the device. How soon after it returns from
    // the ISR and re-enables interrupts is not known but seems relevant because if there is enough
    // latency, it will erroneously pick up the same interrupt.
    reg [6:0] claim_rw;
    reg [6:0] claim_ff1_r;
    reg [6:0] claim_ff2_r;

    always @(posedge clk) begin
        if (!rst_n) begin 
            disa_r <= 0;
            pend_r <= 0;
            ipl_r <= 0;
            claim_ff1_r <= 0;
            claim_ff2_r <= 0;
        end else begin
            disa_r <= disa_rw;
            pend_r <= pend_rw;
            ipl_r <= ipl_rw;
            claim_ff1_r <= claim_rw;
            claim_ff2_r <= claim_ff1_r;
        end
    end

    // Generate mask from ipl
    wire [64:0] ipl_mask_w = ~({1'b1, 64'h0} >> ({1'b0,~ipl_r} + 1)); 
    wire [63:0] pend_masked_w = pend_r & ipl_mask_w[63:0];

    // Interrupt resolution logic
    always @* begin
        claim_rw = 0;
        for (bit [6:0] i = 0; i < 64; i = i + 1) begin
            // 6th bit stores whether there is an interrupt already
            if (!claim_rw[6] && pend_masked_w[i[5:0]] && !disa_r[i[5:0]])
                claim_rw = {1'b1, i[5:0]};
        end
    end

    ////////////////////////
    // AXI Slave Control //
    //////////////////////
    typedef enum reg [1:0] { READY, RD, WDATA, WRESP } axi_slv_state_t;
    axi_slv_state_t state_r, state_rw;
    reg rd_n_wr_r, rd_n_wr_rw;

    reg s_axi_awready_r, s_axi_awready_rw;
    reg s_axi_arready_r, s_axi_arready_rw;
    reg s_axi_wready_r, s_axi_wready_rw;
    reg s_axi_rvalid_r, s_axi_rvalid_rw;
    reg s_axi_bvalid_r, s_axi_bvalid_rw;

    reg [31:0] s_axi_rdata_r, s_axi_rdata_rw;

    reg [5:0] lsic_regaddr_r, lsic_regaddr_rw;
    reg all_err_r, all_err_rw;
    reg w_err_rw;
    reg r_err_rw;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state_r <= READY;
            rd_n_wr_r <= 0;

            s_axi_awready_r <= 0;
            s_axi_arready_r <= 0;
            s_axi_wready_r <= 0;
            s_axi_rvalid_r <= 0;
            s_axi_bvalid_r <= 0;
            s_axi_rdata_r <= 0;

            lsic_regaddr_r <= 0;
            all_err_r <= 0;
        end else begin
            state_r <= state_rw;
            rd_n_wr_r <= rd_n_wr_rw;

            s_axi_awready_r <= s_axi_awready_rw;
            s_axi_arready_r <= s_axi_arready_rw;
            s_axi_wready_r <= s_axi_wready_rw;
            s_axi_rvalid_r <= s_axi_rvalid_rw;
            s_axi_bvalid_r <= s_axi_bvalid_rw;
            s_axi_rdata_r <= s_axi_rdata_rw;

            lsic_regaddr_r <= lsic_regaddr_rw;
            all_err_r <= all_err_rw;
        end
    end

    wire [31:0] req_addr = s_axi_arvalid ? s_axi_araddr : s_axi_awaddr;
    // Bottom 3 bits should be 0, we only care about the first LSIC
    wire is_actually_my_transaction = req_addr[31:5] == {24'hf80300, 3'h0};
    // what the interconnect expects
    wire is_my_transaction = req_addr[31:12] == 20'hf8030;
    wire aw_handshake = s_axi_awvalid && s_axi_awready_r;
    wire ar_handshake = s_axi_arvalid && s_axi_arready_r;
    
    always_comb begin
        r_err_rw = 1'b0;
        case (lsic_regaddr_r)
            6'h00: s_axi_rdata_rw = disa_r[31:0];
            6'h01: s_axi_rdata_rw = disa_r[63:32];
            6'h02: s_axi_rdata_rw = pend_r[31:0];
            6'h03: s_axi_rdata_rw = pend_r[63:32];
            6'h04: s_axi_rdata_rw = {26'h0, claim_ff2_r[5:0]};
            6'h05: s_axi_rdata_rw = {26'h0, ipl_r};
            default: begin 
                r_err_rw = 1;
                s_axi_rdata_rw = 32'h?;
            end
        endcase
    end

    always_comb begin
        w_err_rw = 1'b0;
        disa_rw = disa_r;
        pend_rw_pre = pend_r;
        pend_rw = pend_rw_pre | irqs;
        ipl_rw = ipl_r;
        if (~all_err_r && s_axi_wready_r && s_axi_wvalid) case (lsic_regaddr_r) 
            6'h00: disa_rw = {disa_r[63:32], s_axi_wdata};
            6'h01: disa_rw = {s_axi_wdata, disa_r[31:0]};
            6'h02: pend_rw_pre = {pend_r[63:32], (s_axi_wdata == 0) ? 32'h0 : (s_axi_wdata | pend_r[31:0])};
            6'h03: pend_rw_pre = {(s_axi_wdata == 0) ? 32'h0 : (s_axi_wdata | pend_r[63:32]), pend_r[31:0]};
            6'h04: pend_rw_pre = pend_r & ~(1<<s_axi_wdata[5:0]);
            6'h05: ipl_rw = s_axi_wdata[5:0];
            default: w_err_rw = 1;
        endcase       
    end

    always_comb begin
        state_rw = state_r;
        rd_n_wr_rw = rd_n_wr_r;

        s_axi_awready_rw = s_axi_awready_r;
        s_axi_arready_rw = s_axi_arready_r;
        s_axi_wready_rw = s_axi_wready_r;
        s_axi_rvalid_rw = s_axi_rvalid_r;
        s_axi_bvalid_rw = s_axi_bvalid_r;

        all_err_rw = all_err_r;

        case (state_r) 
            READY: begin
                all_err_rw = ~is_actually_my_transaction;
                s_axi_awready_rw = 1;
                s_axi_arready_rw = 1;
                rd_n_wr_rw = s_axi_arvalid;
                if (is_my_transaction && (aw_handshake || ar_handshake)) begin
                    lsic_regaddr_rw = req_addr[7:2];
                    s_axi_wready_rw = ~rd_n_wr_rw;
                    s_axi_awready_rw = 0;
                    s_axi_arready_rw = 0;
                    state_rw = rd_n_wr_rw ? RD: WDATA;
                end
            end
            RD: begin
                s_axi_rvalid_rw = 1'b1;
                all_err_rw = all_err_r | r_err_rw;
                if (s_axi_rvalid_r && s_axi_rready) begin
                    s_axi_rvalid_rw = 0;
                    state_rw = READY;
                end
            end
            WDATA: begin
                s_axi_wready_rw = 1;
                all_err_rw = all_err_r | w_err_rw;
                if (s_axi_wready_r && s_axi_wvalid) begin
                    s_axi_bvalid_rw = 1;
                    s_axi_wready_rw = 0;
                    state_rw = WRESP;
                end
            end
            WRESP: begin
                s_axi_bvalid_rw = 1;
                if (s_axi_bvalid_r && s_axi_bready) begin
                    s_axi_bvalid_rw = 0;
                    state_rw = READY;
                end
            end
        endcase
    end

    // never busy
    assign s_axi_awready = s_axi_awready_r;
    assign s_axi_arready = s_axi_arready_r;
    assign s_axi_wready = s_axi_wready_r;
    assign s_axi_bvalid = s_axi_bvalid_r;
    assign s_axi_bresp = {2{all_err_r}};
    assign s_axi_rlast = 1'b1; // does not do bursts
    assign s_axi_rvalid = s_axi_rvalid_r;
    assign s_axi_rdata = s_axi_rdata_r;
    assign s_axi_rresp = {2{all_err_r}};

    assign cpu_irq = claim_ff2_r[6];

endmodule

`default_nettype wire