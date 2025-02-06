`timescale 1ns / 1ps
`default_nettype none
module VROOMSoC #(
	parameter SIMULATION = 0
)(
	input  wire clk,
	input  wire rst,
	
	output wire        rom_m_axi_arvalid,
	input  wire        rom_m_axi_arready,
	output wire [31:0] rom_m_axi_araddr,
	output wire [ 7:0] rom_m_axi_arlen,
	output wire [ 2:0] rom_m_axi_arsize,
	output wire [ 1:0] rom_m_axi_arburst,
	input  wire 	   rom_m_axi_rvalid,
	output wire        rom_m_axi_rready,
	input  wire        rom_m_axi_rlast,
	input  wire [31:0] rom_m_axi_rdata,
	input  wire [ 1:0] rom_m_axi_rresp,

	output wire        ram_m_axi_awvalid,
	input  wire        ram_m_axi_awready,
	output wire [31:0] ram_m_axi_awaddr,
	output wire [ 7:0] ram_m_axi_awlen,
	output wire [ 2:0] ram_m_axi_awsize,
	output wire [ 1:0] ram_m_axi_awburst,
	output wire 	   ram_m_axi_wvalid,
	input  wire        ram_m_axi_wready,
	output wire [31:0] ram_m_axi_wdata,
	output wire        ram_m_axi_wlast,
	output wire [ 3:0] ram_m_axi_wstrb,
	input  wire  	   ram_m_axi_bvalid,
	output wire        ram_m_axi_bready,
	input  wire [ 1:0] ram_m_axi_bresp,
	output wire        ram_m_axi_arvalid,
	input  wire        ram_m_axi_arready,
	output wire [31:0] ram_m_axi_araddr,
	output wire [ 7:0] ram_m_axi_arlen,
	output wire [ 2:0] ram_m_axi_arsize,
	output wire [ 1:0] ram_m_axi_arburst,
	input  wire 	   ram_m_axi_rvalid,
	output wire        ram_m_axi_rready,
	input  wire        ram_m_axi_rlast,
	input  wire [31:0] ram_m_axi_rdata,
	input  wire [ 1:0] ram_m_axi_rresp,

	output wire 	   uart_tx,
	input  wire 	   uart_rx
);
	reg bus_waitrequest_local;
	reg [31:0] bus_readdata_local;
	reg bus_readdatavalid_local;
	reg [1:0] bus_response_local;
	reg bus_writeresponsevalid_local;

	wire [31:0] lsic_badAddr;
	wire lsic_badAddrAck = 1'b0;
	wire lsic_badAddrValid;

	/////////////////////////
    // Core instantiation //
    ///////////////////////
	wire        cpu_m_axi_awvalid;
	wire        cpu_m_axi_awready;
	wire [31:0] cpu_m_axi_awaddr;
	wire [ 7:0] cpu_m_axi_awlen;
	wire [ 2:0] cpu_m_axi_awsize;
	wire [ 1:0] cpu_m_axi_awburst;
	wire 	    cpu_m_axi_wvalid;
	wire        cpu_m_axi_wready;
	wire        cpu_m_axi_wlast;
	wire [31:0] cpu_m_axi_wdata;
	wire [ 3:0] cpu_m_axi_wstrb;
	wire  	    cpu_m_axi_bvalid;
	wire        cpu_m_axi_bready;
	wire [ 1:0] cpu_m_axi_bresp;
	wire        cpu_m_axi_arvalid;
	wire        cpu_m_axi_arready;
	wire [31:0] cpu_m_axi_araddr;
	wire [ 7:0] cpu_m_axi_arlen;
	wire [ 2:0] cpu_m_axi_arsize;
	wire [ 1:0] cpu_m_axi_arburst;
	wire 	    cpu_m_axi_rvalid;
	wire        cpu_m_axi_rready;
	wire [31:0] cpu_m_axi_rdata;
	wire [ 1:0] cpu_m_axi_rresp;

	wire cpu_irq = 1'b0;

    CoreWrapper #(
        .SIMULATION(0)   
    ) iCORE (
        .clk(clk), 
        .rst(rst),
		.cpu_irq(cpu_irq),
        .m_axi_awvalid(cpu_m_axi_awvalid),
		.m_axi_awready(cpu_m_axi_awready),
		.m_axi_awaddr(cpu_m_axi_awaddr),
		.m_axi_awlen(cpu_m_axi_awlen),
		.m_axi_awsize(cpu_m_axi_awsize),
		.m_axi_awburst(cpu_m_axi_awburst),
		.m_axi_wvalid(cpu_m_axi_wvalid),
		.m_axi_wlast(cpu_m_axi_wlast),
		.m_axi_wready(cpu_m_axi_wready),
		.m_axi_wdata(cpu_m_axi_wdata),
		.m_axi_wstrb(cpu_m_axi_wstrb),
		.m_axi_bvalid(cpu_m_axi_bvalid),
		.m_axi_bready(cpu_m_axi_bready),
		.m_axi_bresp(cpu_m_axi_bresp),
		.m_axi_arvalid(cpu_m_axi_arvalid),
		.m_axi_arready(cpu_m_axi_arready),
		.m_axi_araddr(cpu_m_axi_araddr),
		.m_axi_arlen(cpu_m_axi_arlen),
		.m_axi_arsize(cpu_m_axi_arsize),
		.m_axi_arburst(cpu_m_axi_arburst),
		.m_axi_rvalid(cpu_m_axi_rvalid),
		.m_axi_rready(cpu_m_axi_rready),
		.m_axi_rdata(cpu_m_axi_rdata),
		.m_axi_rresp(cpu_m_axi_rresp)
    );

	/////////////////
	// LSIC slave //
	///////////////
	/*
	wire        lsic_s_axi_awvalid;
	wire        lsic_s_axi_awready;
	wire [31:0] lsic_s_axi_awaddr;
	wire [ 7:0] lsic_s_axi_awlen;
	wire [ 2:0] lsic_s_axi_awsize;
	wire [ 1:0] lsic_s_axi_awburst;
	wire 	    lsic_s_axi_wvalid;
	wire        lsic_s_axi_wready;
	wire [31:0] lsic_s_axi_wdata;
	wire [ 3:0] lsic_s_axi_wstrb;
	wire  	    lsic_s_axi_bvalid;
	wire        lsic_s_axi_bready;
	wire [ 1:0] lsic_s_axi_bresp;
	wire        lsic_s_axi_arvalid;
	wire        lsic_s_axi_arready;
	wire [31:0] lsic_s_axi_araddr;
	wire [ 7:0] lsic_s_axi_arlen;
	wire [ 2:0] lsic_s_axi_arsize;
	wire [ 1:0] lsic_s_axi_arburst;
	wire 	    lsic_s_axi_rvalid;
	wire        lsic_s_axi_rready;
	wire [31:0] lsic_s_axi_rdata;
	wire [ 1:0] lsic_s_axi_rresp;

	LSIC iLSIC (
		.clk(clk),
		.rst_n(~rst),
		.irqs(irqs),
		.cpu_irq(cpu_irq),
		.cpu_buserror(cpu_buserror),
		.s_waitrequest(lsic_s_waitrequest),
		.s_readdata(lsic_s_readdata),
		.s_readdatavalid(lsic_s_readdatavalid),
		.s_response(lsic_s_response),
		.s_writeresponsevalid(lsic_s_writeresponsevalid),
		.bus_burstcount(cpu_burstcount),
		.bus_writedata(cpu_writedata),
		.bus_address(cpu_address),
		.bus_write(cpu_write),
		.bus_read(cpu_read),
		.bus_byteenable(cpu_byteenable)
	);*/

	///////////////////////
	// Citron Subsystem //
	/////////////////////
	wire        citron_s_axi_awvalid;
	wire        citron_s_axi_awready;
	wire [31:0] citron_s_axi_awaddr;
	wire 	    citron_s_axi_wvalid;
	wire        citron_s_axi_wready;
	wire [31:0] citron_s_axi_wdata;
	wire [ 3:0] citron_s_axi_wstrb;
	wire  	    citron_s_axi_bvalid;
	wire        citron_s_axi_bready;
	wire [ 1:0] citron_s_axi_bresp;
	wire        citron_s_axi_arvalid;
	wire        citron_s_axi_arready;
	wire [31:0] citron_s_axi_araddr;
	wire 	    citron_s_axi_rvalid;
	wire        citron_s_axi_rready;
	wire        citron_s_axi_rlast;
	wire [31:0] citron_s_axi_rdata;
	wire [ 1:0] citron_s_axi_rresp;

	CitronSubsystem #(
		.SIMULATION(SIMULATION)
	) iCITRON (
		.clk_i(clk),
		.rst_i(rst),
		.s_axi_awvalid(citron_s_axi_awvalid),
		.s_axi_awready(citron_s_axi_awready),
		.s_axi_awaddr(citron_s_axi_awaddr),
		.s_axi_wvalid(citron_s_axi_wvalid),
		.s_axi_wready(citron_s_axi_wready),
		.s_axi_wdata(citron_s_axi_wdata),
		.s_axi_wstrb(citron_s_axi_wstrb),
		.s_axi_bvalid(citron_s_axi_bvalid),
		.s_axi_bready(citron_s_axi_bready),
		.s_axi_bresp(citron_s_axi_bresp),
		.s_axi_arvalid(citron_s_axi_arvalid),
		.s_axi_arready(citron_s_axi_arready),
		.s_axi_araddr(citron_s_axi_araddr),
		.s_axi_rvalid(citron_s_axi_rvalid),
		.s_axi_rready(citron_s_axi_rready),
		.s_axi_rlast(citron_s_axi_rlast),
		.s_axi_rdata(citron_s_axi_rdata),
		.s_axi_rresp(citron_s_axi_rresp),
		.uart_tx(uart_tx),
		.uart_rx(uart_rx)
	);

	
    ///////////////////
	// AXI Crossbar //
    /////////////////

    axi_interconnect_wrap_1x3 #(
		.M00_BASE_ADDR(0),
		.M00_ADDR_WIDTH(32'd14),
		.M01_BASE_ADDR(32'hFFFE0000),
		.M01_ADDR_WIDTH(32'd16),
		.M01_CONNECT_WRITE(1'b0),
		.M02_BASE_ADDR(32'hF8000000),
		.M02_ADDR_WIDTH(32'd12) // should be 10, but it won't let me put that..
    ) iINTERCONNECT (
        .clk(clk),
        .rst(rst),
        .s00_axi_awid(8'h0),
        .s00_axi_awaddr(cpu_m_axi_awaddr),
		.s00_axi_awlen(cpu_m_axi_awlen),
		.s00_axi_awsize(cpu_m_axi_awsize),
		.s00_axi_awburst(cpu_m_axi_awburst),
		.s00_axi_awlock(1'b0),
		.s00_axi_awcache(4'h0),
		.s00_axi_awprot(3'h0),
		.s00_axi_awqos(4'h0),
		.s00_axi_awuser(0),
		.s00_axi_awvalid(cpu_m_axi_awvalid),
		.s00_axi_awready(cpu_m_axi_awready),
		.s00_axi_wdata(cpu_m_axi_wdata),
		.s00_axi_wstrb(cpu_m_axi_wstrb),
		.s00_axi_wlast(cpu_m_axi_wlast),
		.s00_axi_wvalid(cpu_m_axi_wvalid),
		.s00_axi_wuser(0),
		.s00_axi_wready(cpu_m_axi_wready),
		.s00_axi_bresp(cpu_m_axi_bresp),
		.s00_axi_bvalid(cpu_m_axi_bvalid),
		.s00_axi_bready(cpu_m_axi_bready),
		.s00_axi_araddr(cpu_m_axi_araddr),
		.s00_axi_arlen(cpu_m_axi_arlen),
		.s00_axi_arsize(cpu_m_axi_arsize),
		.s00_axi_arburst(cpu_m_axi_arburst),
		.s00_axi_arlock(1'b0),
		.s00_axi_arcache(4'h0),
		.s00_axi_arprot(3'h0),
		.s00_axi_arqos(4'h0),
		.s00_axi_aruser(0),
		.s00_axi_arvalid(cpu_m_axi_arvalid),
		.s00_axi_arready(cpu_m_axi_arready),
		.s00_axi_rdata(cpu_m_axi_rdata),
		.s00_axi_rresp(cpu_m_axi_rresp),
		.s00_axi_rvalid(cpu_m_axi_rvalid),
		.s00_axi_rready(cpu_m_axi_rready),

		// RAM
		.m00_axi_awaddr(ram_m_axi_awaddr),
		.m00_axi_awlen(ram_m_axi_awlen),
		.m00_axi_awsize(ram_m_axi_awsize),
		.m00_axi_awburst(ram_m_axi_awburst),
		.m00_axi_awvalid(ram_m_axi_awvalid),
		.m00_axi_awready(ram_m_axi_awready),
		.m00_axi_wdata(ram_m_axi_wdata),
		.m00_axi_wstrb(ram_m_axi_wstrb),
		.m00_axi_wlast(ram_m_axi_wlast),
		.m00_axi_wvalid(ram_m_axi_wvalid),
		.m00_axi_wready(ram_m_axi_wready),
		.m00_axi_bresp(ram_m_axi_bresp),
		.m00_axi_bvalid(ram_m_axi_bvalid),
		.m00_axi_bready(ram_m_axi_bready),
		.m00_axi_araddr(ram_m_axi_araddr),
		.m00_axi_arlen(ram_m_axi_arlen),
		.m00_axi_arsize(ram_m_axi_arsize),
		.m00_axi_arburst(ram_m_axi_arburst),
		.m00_axi_arvalid(ram_m_axi_arvalid),
		.m00_axi_arready(ram_m_axi_arready),
		.m00_axi_rdata(ram_m_axi_rdata),
		.m00_axi_rlast(ram_m_axi_rlast),
		.m00_axi_rresp(ram_m_axi_rresp),
		.m00_axi_rvalid(ram_m_axi_rvalid),
		.m00_axi_rready(ram_m_axi_rready),

		// ROM
		// write channel unconnected
		.m01_axi_araddr(rom_m_axi_araddr),
		.m01_axi_arlen(rom_m_axi_arlen),
		.m01_axi_arsize(rom_m_axi_arsize),
		.m01_axi_arburst(rom_m_axi_arburst),
		.m01_axi_arvalid(rom_m_axi_arvalid),
		.m01_axi_arready(rom_m_axi_arready),
		.m01_axi_rdata(rom_m_axi_rdata),
		.m01_axi_rlast(rom_m_axi_rlast),
		.m01_axi_rresp(rom_m_axi_rresp),
		.m01_axi_rvalid(rom_m_axi_rvalid),
		.m01_axi_rready(rom_m_axi_rready),

		// Citron subsystem
		.m02_axi_awaddr(citron_s_axi_awaddr),
		.m02_axi_awvalid(citron_s_axi_awvalid),
		.m02_axi_awready(citron_s_axi_awready),
		.m02_axi_wdata(citron_s_axi_wdata),
		.m02_axi_wstrb(citron_s_axi_wstrb),
		.m02_axi_wvalid(citron_s_axi_wvalid),
		.m02_axi_wready(citron_s_axi_wready),
		.m02_axi_bresp(citron_s_axi_bresp),
		.m02_axi_bvalid(citron_s_axi_bvalid),
		.m02_axi_bready(citron_s_axi_bready),
		.m02_axi_araddr(citron_s_axi_araddr),
		.m02_axi_arvalid(citron_s_axi_arvalid),
		.m02_axi_arready(citron_s_axi_arready),
		.m02_axi_rdata(citron_s_axi_rdata),
		.m02_axi_rresp(citron_s_axi_rresp),
		.m02_axi_rlast(citron_s_axi_rlast),
		.m02_axi_rvalid(citron_s_axi_rvalid),
		.m02_axi_rready(citron_s_axi_rready)
    );
endmodule
`default_nettype wire
