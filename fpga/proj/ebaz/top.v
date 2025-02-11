module top(
	input   clk,
	input   rst,
	
	output         rom_m_axi_arvalid,
	input          rom_m_axi_arready,
	output  [31:0] rom_m_axi_araddr,
	output  [ 7:0] rom_m_axi_arlen,
	output  [ 2:0] rom_m_axi_arsize,
	output  [ 1:0] rom_m_axi_arburst,
	input          rom_m_axi_rvalid,
	output         rom_m_axi_rready,
	input          rom_m_axi_rlast,
	input   [31:0] rom_m_axi_rdata,
	input   [ 1:0] rom_m_axi_rresp,

	output         ram_m_axi_awvalid,
	input          ram_m_axi_awready,
	output  [31:0] ram_m_axi_awaddr,
	output  [ 7:0] ram_m_axi_awlen,
	output  [ 2:0] ram_m_axi_awsize,
	output  [ 1:0] ram_m_axi_awburst,
	output         ram_m_axi_wvalid,
	input          ram_m_axi_wready,
	output  [31:0] ram_m_axi_wdata,
	output         ram_m_axi_wlast,
	output  [ 3:0] ram_m_axi_wstrb,
	input          ram_m_axi_bvalid,
	output         ram_m_axi_bready,
	input   [ 1:0] ram_m_axi_bresp,
	output         ram_m_axi_arvalid,
	input          ram_m_axi_arready,
	output  [31:0] ram_m_axi_araddr,
	output  [ 7:0] ram_m_axi_arlen,
	output  [ 2:0] ram_m_axi_arsize,
	output  [ 1:0] ram_m_axi_arburst,
	input          ram_m_axi_rvalid,
	output         ram_m_axi_rready,
	input          ram_m_axi_rlast,
	input   [31:0] ram_m_axi_rdata,
	input   [ 1:0] ram_m_axi_rresp,

	output        frmbuf_m_axi_awvalid,
	input         frmbuf_m_axi_awready,
	output [31:0] frmbuf_m_axi_awaddr,
	output [ 3:0] frmbuf_m_axi_awlen,
	output [ 2:0] frmbuf_m_axi_awsize,
	output [ 1:0] frmbuf_m_axi_awburst,
	output 	   frmbuf_m_axi_wvalid,
	input         frmbuf_m_axi_wready,
	output [31:0] frmbuf_m_axi_wdata,
	output        frmbuf_m_axi_wlast,
	output [ 3:0] frmbuf_m_axi_wstrb,
	input   	   frmbuf_m_axi_bvalid,
	output        frmbuf_m_axi_bready,
	input  [ 1:0] frmbuf_m_axi_bresp,
	output        frmbuf_m_axi_arvalid,
	input         frmbuf_m_axi_arready,
	output [31:0] frmbuf_m_axi_araddr,
	output [ 3:0] frmbuf_m_axi_arlen,
	output [ 2:0] frmbuf_m_axi_arsize,
	output [ 1:0] frmbuf_m_axi_arburst,
	input  	   frmbuf_m_axi_rvalid,
	output        frmbuf_m_axi_rready,
	input         frmbuf_m_axi_rlast,
	input  [31:0] frmbuf_m_axi_rdata,
	input  [ 1:0] frmbuf_m_axi_rresp,

	output  	   uart_tx,
	input   	   uart_rx
);
wire [31:0] local_frmbuf_m_axi_awaddr;
wire [31:0] local_frmbuf_m_axi_araddr;

wire [7:0] local_frmbuf_m_axi_arlen;
wire [7:0] local_frmbuf_m_axi_awlen;

VROOMSoC #(
	.SIMULATION(0)
) iSOC (
	.clk(clk),
	.rst(rst),
	.rom_m_axi_arvalid(rom_m_axi_arvalid),
	.rom_m_axi_arready(rom_m_axi_arready),
	.rom_m_axi_araddr(rom_m_axi_araddr),
	.rom_m_axi_arlen(rom_m_axi_arlen),
	.rom_m_axi_arsize(rom_m_axi_arsize),
	.rom_m_axi_arburst(rom_m_axi_arburst),
	.rom_m_axi_rvalid(rom_m_axi_rvalid),
	.rom_m_axi_rready(rom_m_axi_rready),
	.rom_m_axi_rlast(rom_m_axi_rlast),
	.rom_m_axi_rdata(rom_m_axi_rdata),
	.rom_m_axi_rresp(rom_m_axi_rresp),
	.ram_m_axi_awvalid(ram_m_axi_awvalid),
	.ram_m_axi_awready(ram_m_axi_awready),
	.ram_m_axi_awaddr(ram_m_axi_awaddr),
	.ram_m_axi_awlen(ram_m_axi_awlen),
	.ram_m_axi_awsize(ram_m_axi_awsize),
	.ram_m_axi_awburst(ram_m_axi_awburst),
	.ram_m_axi_wvalid(ram_m_axi_wvalid),
	.ram_m_axi_wready(ram_m_axi_wready),
	.ram_m_axi_wlast(ram_m_axi_wlast),
	.ram_m_axi_wdata(ram_m_axi_wdata),
	.ram_m_axi_wstrb(ram_m_axi_wstrb),
	.ram_m_axi_bvalid(ram_m_axi_bvalid),
	.ram_m_axi_bready(ram_m_axi_bready),
	.ram_m_axi_bresp(ram_m_axi_bresp),
	.ram_m_axi_arvalid(ram_m_axi_arvalid),
	.ram_m_axi_arready(ram_m_axi_arready),
	.ram_m_axi_araddr(ram_m_axi_araddr),
	.ram_m_axi_arlen(ram_m_axi_arlen),
	.ram_m_axi_arsize(ram_m_axi_arsize),
	.ram_m_axi_arburst(ram_m_axi_arburst),
	.ram_m_axi_rvalid(ram_m_axi_rvalid),
	.ram_m_axi_rready(ram_m_axi_rready),
	.ram_m_axi_rlast(ram_m_axi_rlast),
	.ram_m_axi_rdata(ram_m_axi_rdata),
	.ram_m_axi_rresp(ram_m_axi_rresp),
	.frmbuf_m_axi_awvalid(frmbuf_m_axi_awvalid),
	.frmbuf_m_axi_awready(frmbuf_m_axi_awready),
	.frmbuf_m_axi_awaddr(frmbuf_m_axi_awaddr),
	.frmbuf_m_axi_awlen(local_frmbuf_m_axi_arlen),
	.frmbuf_m_axi_awsize(frmbuf_m_axi_awsize),
	.frmbuf_m_axi_awburst(frmbuf_m_axi_awburst),
	.frmbuf_m_axi_wvalid(frmbuf_m_axi_wvalid),
	.frmbuf_m_axi_wlast(frmbuf_m_axi_wlast),
	.frmbuf_m_axi_wready(frmbuf_m_axi_wready),
	.frmbuf_m_axi_wdata(frmbuf_m_axi_wdata),
	.frmbuf_m_axi_wstrb(frmbuf_m_axi_wstrb),
	.frmbuf_m_axi_bvalid(frmbuf_m_axi_bvalid),
	.frmbuf_m_axi_bready(frmbuf_m_axi_bready),
	.frmbuf_m_axi_bresp(frmbuf_m_axi_bresp),
	.frmbuf_m_axi_arvalid(frmbuf_m_axi_arvalid),
	.frmbuf_m_axi_arready(frmbuf_m_axi_arready),
	.frmbuf_m_axi_araddr(frmbuf_m_axi_araddr),
	.frmbuf_m_axi_arlen(local_frmbuf_m_axi_arlen),
	.frmbuf_m_axi_arsize(frmbuf_m_axi_arsize),
	.frmbuf_m_axi_arburst(frmbuf_m_axi_arburst),
	.frmbuf_m_axi_rvalid(frmbuf_m_axi_rvalid),
	.frmbuf_m_axi_rready(frmbuf_m_axi_rready),
	.frmbuf_m_axi_rlast(frmbuf_m_axi_rlast),
	.frmbuf_m_axi_rdata(frmbuf_m_axi_rdata),
	.frmbuf_m_axi_rresp(frmbuf_m_axi_rresp),
	.uart_tx(uart_tx),
	.uart_rx(uart_rx)
);

// convert to addresses in DDR
assign frmbuf_m_axi_awaddr = {8'h0F, 3'h7, local_frmbuf_m_axi_awaddr[20:0]};
assign frmbuf_m_axi_araddr = {8'h0F, 3'h7, local_frmbuf_m_axi_araddr[20:0]};
assign frmbuf_m_axi_awlen = local_frmbuf_m_axi_awlen[3:0];
assign frmbuf_m_axi_arlen = local_frmbuf_m_axi_arlen[3:0];
endmodule
