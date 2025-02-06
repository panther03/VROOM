`timescale 1ns / 1ps
`default_nettype none
module CoreWrapper #(
	parameter SIMULATION = 0	
)(
	input  wire clk,
	input  wire rst,
	input  wire cpu_irq,

	output wire        m_axi_awvalid,
	input  wire        m_axi_awready,
	output wire [31:0] m_axi_awaddr,
	output wire [ 7:0] m_axi_awlen,
	output wire [ 2:0] m_axi_awsize,
	output wire [ 1:0] m_axi_awburst,

	output wire 	   m_axi_wvalid,
	input  wire        m_axi_wready,
	output wire 	   m_axi_wlast,
	output wire [31:0] m_axi_wdata,
	output wire [ 3:0] m_axi_wstrb,

	input  wire  	   m_axi_bvalid,
	output wire        m_axi_bready,
	input wire  [ 1:0] m_axi_bresp,

	output wire        m_axi_arvalid,
	input  wire        m_axi_arready,
	output wire [31:0] m_axi_araddr,
	output wire [ 7:0] m_axi_arlen,
	output wire [ 2:0] m_axi_arsize,
	output wire [ 1:0] m_axi_arburst,

	input  wire 	   m_axi_rvalid,
	output wire        m_axi_rready,
	input  wire [31:0] m_axi_rdata,
	input  wire [ 1:0] m_axi_rresp
);
	wire        busErrorValid;
	wire        busErrorReady;
	wire [31:0] busError;

	///////////////////
	// Bluespec CPU //
	/////////////////
	wire 		 reqValid;
	wire 		 reqReady;
	wire [3:0]   reqByteStrobe;
	wire 		 reqLineEn;
	wire [29:0]  reqAddr;
	wire [511:0] reqData;

	wire [511:0] respData;
	wire         respHasError;
	wire 		 respValid;
	wire 		 respReady;

	mkVROOM iCORE (
		.CLK(clk),
		.RST_N(~rst),
		.EN_getBusReq(reqReady),
		.getBusReq({reqByteStrobe, reqLineEn, reqAddr, reqData}),
		.RDY_getBusReq(reqValid),

		.putBusError_busError(busError),
		.EN_putBusError(busErrorValid),
		.RDY_putBusError(busErrorReady),
		
		.putBusResp_r({respHasError, respData}),
		.EN_putBusResp(respValid),
		.RDY_putBusResp(respReady),
		.putIrq_irq(cpu_irq)
	);

	/////////////////////
	// CPU bus master //
	///////////////////

	CpuBusMaster iCPU_MASTER (
		.clk(clk),
		.rst_n(~rst),
		.cpu_reqValid(reqValid),
		.cpu_reqReady(reqReady),
		.cpu_reqByteStrobe(reqByteStrobe),
		.cpu_reqLineEn(reqLineEn),
		.cpu_reqAddr(reqAddr),
		.cpu_reqData(reqData),
		.cpu_respData(respData),
		.cpu_respHasError(respHasError),
		.cpu_respValid(respValid),
		.cpu_respReady(respReady),
		.busError(busError),
		.busErrorValid(busErrorValid),
		.busErrorReady(busErrorReady),
		.m_axi_awvalid(m_axi_awvalid),
		.m_axi_awready(m_axi_awready),
		.m_axi_awaddr(m_axi_awaddr),
		.m_axi_awlen(m_axi_awlen),
		.m_axi_awsize(m_axi_awsize),
		.m_axi_awburst(m_axi_awburst),
		.m_axi_wvalid(m_axi_wvalid),
		.m_axi_wlast(m_axi_wlast),
		.m_axi_wready(m_axi_wready),
		.m_axi_wdata(m_axi_wdata),
		.m_axi_wstrb(m_axi_wstrb),
		.m_axi_bvalid(m_axi_bvalid),
		.m_axi_bready(m_axi_bready),
		.m_axi_bresp(m_axi_bresp),
		.m_axi_arvalid(m_axi_arvalid),
		.m_axi_arready(m_axi_arready),
		.m_axi_araddr(m_axi_araddr),
		.m_axi_arlen(m_axi_arlen),
		.m_axi_arsize(m_axi_arsize),
		.m_axi_arburst(m_axi_arburst),
		.m_axi_rvalid(m_axi_rvalid),
		.m_axi_rready(m_axi_rready),
		.m_axi_rdata(m_axi_rdata),
		.m_axi_rresp(m_axi_rresp)
	);

endmodule

module CpuBusMaster (
	input  wire clk,
	input  wire rst_n,

	input  wire 		cpu_reqValid,
	output wire 		cpu_reqReady,
	input  wire [  3:0] cpu_reqByteStrobe,
	input  wire 		cpu_reqLineEn,
	input  wire [ 29:0] cpu_reqAddr,
	input  wire [511:0] cpu_reqData,

	output wire 		cpu_respValid,
	input  wire			cpu_respReady,
	output wire [511:0] cpu_respData,
	output wire         cpu_respHasError,

	output wire [31:0] busError,
	output wire        busErrorValid,
	input  wire        busErrorReady,

	output wire        m_axi_awvalid,
	input  wire        m_axi_awready,
	output wire [31:0] m_axi_awaddr,
	output wire [ 7:0] m_axi_awlen,
	output wire [ 2:0] m_axi_awsize,
	output wire [ 1:0] m_axi_awburst,

	output wire 	   m_axi_wvalid,
	input  wire        m_axi_wready,
	output wire        m_axi_wlast,
	output wire [31:0] m_axi_wdata,
	output wire [ 3:0] m_axi_wstrb,

	input  wire  	   m_axi_bvalid,
	output wire        m_axi_bready,
	input wire  [ 1:0] m_axi_bresp,

	output wire        m_axi_arvalid,
	input  wire        m_axi_arready,
	output wire [31:0] m_axi_araddr,
	output wire [ 7:0] m_axi_arlen,
	output wire [ 2:0] m_axi_arsize,
	output wire [ 1:0] m_axi_arburst,

	input  wire 	   m_axi_rvalid,
	output wire        m_axi_rready,
	input  wire [31:0] m_axi_rdata,
	input  wire [ 1:0] m_axi_rresp

	//input  wire 	   bus_m_waitrequest,
	//input  wire [31:0] bus_m_readdata,
	//input  wire 	   bus_m_readdatavalid,
	//input  wire [ 1:0] bus_m_response,
	//input  wire        bus_m_writeresponsevalid,
	//output wire [ 4:0] bus_m_burstcount,
	//output wire [31:0] bus_m_writedata,
	//output wire [29:0] bus_m_address,
	//output wire 	   bus_m_write,
	//output wire 	   bus_m_read,
	//output wire [3:0]  bus_m_byteenable
);

	localparam [2:0] IDLE       = 3'h0;
	localparam [2:0] RADDR      = 3'h1;
	localparam [2:0] WADDR      = 3'h2;
	localparam [2:0] RDATA      = 3'h3;
	localparam [2:0] WDATA      = 3'h4;
	localparam [2:0] RRESP      = 3'h5;
	localparam [2:0] WRESP      = 3'h6;

	reg [2:0] state_r;
	reg [2:0] state_rw;

	reg [511:0] data_r;
	reg [511:0] data_rw;

	reg cpu_reqWe_r;
	reg cpu_reqWe_rw;

	reg reqReady_rw;
	reg respValid_rw;
	reg respValid_r;

	reg badAddrValid_r;
	reg badAddrValid_rw;

	reg [4:0] outstanding_responses_r;
	reg [4:0] outstanding_responses_rw;

	reg        m_axi_awvalid_r;
	reg        m_axi_awvalid_rw;
	reg        m_axi_arvalid_r;
	reg        m_axi_arvalid_rw;
	reg [31:0] m_axi_aaddr_r;
	reg [31:0] m_axi_aaddr_rw;
	reg [ 7:0] m_axi_alen_r;
	reg [ 7:0] m_axi_alen_rw;

	reg 	   m_axi_wvalid_r;
	reg 	   m_axi_wvalid_rw;
	reg 	   m_axi_wlast_r;
	reg 	   m_axi_wlast_rw;
	reg [ 3:0] m_axi_wstrb_r;
	reg [ 3:0] m_axi_wstrb_rw;

	reg m_axi_bready_r;
	reg m_axi_bready_rw;
	reg m_axi_rready_r;
	reg m_axi_rready_rw;

	always @(posedge clk) begin
		if (!rst_n) begin
			state_r <= IDLE;
			data_r <= 0;
			cpu_reqWe_r <= 0;
			respValid_r <= 0;
			badAddrValid_r <= 0;
		end else begin
			state_r <= state_rw;
			data_r <= data_rw;
			cpu_reqWe_r <= cpu_reqWe_rw;
			respValid_r <= respValid_rw;
			badAddrValid_r <= badAddrValid_rw;
		end
	end

	wire cpu_reqWe_w;
	assign cpu_reqWe_w = |cpu_reqByteStrobe;

	wire read_handshake_w = (m_axi_rvalid && m_axi_rready_r);
	wire write_handshake_w = (m_axi_wvalid_r && m_axi_wready);
	wire beat_handshake_w = read_handshake_w || write_handshake_w;
	wire [31:0] read_error_mask_w = {32{~m_axi_rresp[1]}};

	always @(*) begin
		state_rw = state_r;
		data_rw = data_r;
		cpu_reqWe_rw = cpu_reqWe_r;
		respValid_rw = 0;
		reqReady_rw = 0;

		m_axi_awvalid_rw = m_axi_awvalid_r;
		m_axi_arvalid_rw = m_axi_arvalid_r;
		m_axi_aaddr_rw = m_axi_aaddr_r;
		m_axi_alen_rw = beat_handshake_w ? (m_axi_alen_r - 1) : m_axi_alen_r;

		m_axi_wvalid_rw = m_axi_wvalid_r;
		m_axi_wstrb_rw = m_axi_wstrb_r;
		m_axi_wlast_rw = m_axi_wlast_r;

		m_axi_bready_rw = m_axi_bready_r;
		m_axi_rready_rw = m_axi_rready_r;

		// Has the CPU acknowledged our bus error (valid & rdy)? Reset it.
		// Otherwise we listen for any errors (bus_m_response != 0) and use that as an enable signal.
		badAddrValid_rw = (badAddrValid_r & busErrorReady) ? 1'h0 : (badAddrValid_r | 
		((read_handshake_w && m_axi_rresp[1]) | 
		(m_axi_bvalid && m_axi_bready_r && m_axi_bresp[1])));

		data_rw = beat_handshake_w ? {m_axi_rdata & read_error_mask_w, data_r[511:32]} : data_r;

		case (state_r)
			IDLE: begin
				// 1. There is a request from the CPU
				// 2. Any errors in the previous transaction have been acknowledged by the LSIC.
				if (cpu_reqValid & ~badAddrValid_r) begin
					reqReady_rw = 1;
					data_rw = cpu_reqData;
					cpu_reqWe_rw = cpu_reqWe_w;
					m_axi_alen_rw = cpu_reqLineEn ? 8'hF : 8'h0;
					m_axi_aaddr_rw = {cpu_reqAddr, 2'h0};
					m_axi_awvalid_rw = cpu_reqWe_w;
					m_axi_arvalid_rw = ~cpu_reqWe_w;
					m_axi_wstrb_rw = cpu_reqByteStrobe;
					// dumb hack for write to reset register
					state_rw = (m_axi_aaddr_rw == 32'hF8800000) ? IDLE
						: cpu_reqWe_w ? WADDR : RADDR;
				end
			end
			RADDR: begin
				if (m_axi_arvalid_r && m_axi_arready) begin
					m_axi_arvalid_rw = 1'b0;
					m_axi_rready_rw = 1'b1;
					state_rw = RDATA;
				end else begin
					state_rw = RADDR;
				end
			end
			RDATA: begin
				if (read_handshake_w && (m_axi_alen_r == 0)) begin
					m_axi_rready_rw = 1'b0;
					state_rw = RRESP;
				end else begin
					state_rw = RDATA;
				end
			end
			RRESP: begin
				respValid_rw = cpu_respReady;
				state_rw = cpu_respReady ? IDLE : RRESP;
			end
			WADDR: begin
				if (m_axi_awvalid_r && m_axi_awready) begin
					m_axi_awvalid_rw = 1'b0;
					m_axi_wvalid_rw = 1'b1;
					m_axi_wlast_rw = (m_axi_alen_r == 0);
					state_rw = WDATA;
				end else begin
					state_rw = WADDR;
				end
			end
			WDATA: begin
				m_axi_wlast_rw = write_handshake_w && (m_axi_alen_r == 1);
				if (write_handshake_w && (m_axi_alen_r == 0)) begin
					m_axi_wvalid_rw = 1'b0;
					m_axi_wlast_rw = 1'b0;
					m_axi_bready_rw = 1'b1;
					state_rw = WRESP;
				end else begin
					state_rw = WDATA;
				end
			end
			WRESP: begin
				if (m_axi_bready_r && m_axi_bvalid) begin
					m_axi_bready_rw = 1'b0;
					state_rw = IDLE;
				end else begin
					state_rw = WRESP;
				end
			end
		endcase
	end

	always @(posedge clk) begin
		if (!rst_n) begin
			m_axi_awvalid_r <= 0;
			m_axi_arvalid_r <= 0;
			m_axi_aaddr_r <= 0;
			m_axi_alen_r <= 0;
			m_axi_wvalid_r <= 0;
			m_axi_wlast_r <= 0;
			m_axi_wstrb_r <= 0;
			m_axi_bready_r <= 0;
			m_axi_rready_r <= 0;
		end else begin
			m_axi_awvalid_r <= m_axi_awvalid_rw;
			m_axi_arvalid_r <= m_axi_arvalid_rw;
			m_axi_aaddr_r <= m_axi_aaddr_rw;
			m_axi_alen_r <= m_axi_alen_rw;
			m_axi_wvalid_r <= m_axi_wvalid_rw;
			m_axi_wlast_r <= m_axi_wlast_rw;
			m_axi_wstrb_r <= m_axi_wstrb_rw;
			m_axi_bready_r <= m_axi_bready_rw;
			m_axi_rready_r <= m_axi_rready_rw;
		end
	end

	// bluespec takes these signals as an enable signal, 
	// so there is no handshake. if we keep them on all the 
	// time it will spam the rule, which we do not want.
	assign cpu_reqReady = reqReady_rw;
	assign cpu_respData = data_r;
	assign cpu_respHasError = badAddrValid_r;
	assign cpu_respValid = respValid_rw;

	// same case here. guard valid signal.
	assign busError = m_axi_aaddr_r;
	assign busErrorValid = badAddrValid_r & busErrorReady;

	
	assign m_axi_awvalid = m_axi_awvalid_r;
	assign m_axi_awaddr = m_axi_aaddr_r;
	assign m_axi_awlen = m_axi_alen_r;
	assign m_axi_awsize = 3'b010; // 4 bytes per transfer
	assign m_axi_awburst = 2'b01; // fixed burst

	assign m_axi_wlast = m_axi_wlast_r;
	assign m_axi_wvalid = m_axi_wvalid_r;
	assign m_axi_wdata = data_r[31:0];
	assign m_axi_wstrb = m_axi_wstrb_r;

	assign m_axi_bready = m_axi_bready_r;

	assign m_axi_arvalid = m_axi_arvalid_r;
	assign m_axi_araddr = m_axi_aaddr_r;
	assign m_axi_arlen = m_axi_alen_r;
	assign m_axi_arsize = 3'b010; // 4 bytes per transfer
	assign m_axi_arburst = 2'b01; // fixed burst

	assign m_axi_rready = m_axi_rready_r;	

endmodule