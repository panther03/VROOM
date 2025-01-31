`default_nettype none
module SimpleMemSlave #(
    parameter [31: 0] base_addr = 32'hDEADBEEF,
    parameter mem_size = 512,
    parameter string loadfile = "none"
) (
    input wire clk_i,
    input wire rst_i,

    input  wire        s_axi_awvalid,
	output wire        s_axi_awready,
	input  wire [31:0] s_axi_awaddr,
	input  wire [ 7:0] s_axi_awlen,
	input  wire [ 2:0] s_axi_awsize,
	input  wire [ 1:0] s_axi_awburst,

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
	input  wire [ 7:0] s_axi_arlen,
	input  wire [ 2:0] s_axi_arsize,
	input  wire [ 1:0] s_axi_arburst,

	output wire 	   s_axi_rvalid,
	input  wire        s_axi_rready,
    output wire        s_axi_rlast,
    output wire [31:0] s_axi_rdata,
	output wire [ 1:0] s_axi_rresp
);

localparam integer mem_bits = $clog2(mem_size);
localparam [31:0] base_addr_mask = ~((1 << (mem_bits+2)) - 1);

// instantiate memory
reg [31:0] mem [mem_size-1:0];
integer i;
initial begin
    if (loadfile == "none") begin
        for (i = 0; i < mem_size; i = i + 1) begin
            mem[i] = 0;
        end
    end else begin
        $readmemh(loadfile, mem);
    end
end

// tracking signals
reg [mem_bits:0] mem_addr_r = 0;
reg        go_r = 0;
reg        rd_n_wr_r = 0;
reg        bvalid_r = 0;
reg [ 7:0] burstcount_r = 0;
reg [ 3:0] byteenable_r = 0;


// control signals
wire start_transaction = (s_axi_awvalid || s_axi_arvalid) && ~go_r;
wire rd_n_wr_w = start_transaction ? s_axi_arvalid : rd_n_wr_r;
wire [31:0] request_addr_w = rd_n_wr_w ? s_axi_araddr : s_axi_awaddr;

wire [mem_bits:0] mem_calc_addr = {(request_addr_w - base_addr)}[mem_bits+2:2];
wire [31:0] byteenable_mask = {{8{byteenable_r[3]}},
    {8{byteenable_r[2]}},
    {8{byteenable_r[1]}},
    {8{byteenable_r[0]}}};
wire is_my_transaction = ((request_addr_w ^ base_addr) & base_addr_mask) == 0; 

wire handshake_w = go_r && (s_axi_wvalid || s_axi_rready);

always @(posedge clk_i) begin
    if (rst_i) begin
        mem_addr_r   <= 0;
        go_r         <= 0;
        rd_n_wr_r    <= 0;
        burstcount_r <= 0;
        byteenable_r <= 0;
    end else begin 
        mem_addr_r   <= go_r ? mem_addr_r+1 : (start_transaction ? mem_calc_addr : 0);
        go_r         <= start_transaction ? is_my_transaction
            : (burstcount_r == 0 && (s_axi_rready || (bvalid_r && s_axi_bready)) ? 1'b0 : go_r);
        burstcount_r <= start_transaction 
            ? (rd_n_wr_w ? s_axi_arlen : s_axi_awlen)
            : ((burstcount_r == 0) ? 0
            : (handshake_w ? (burstcount_r - 1) : burstcount_r));
        bvalid_r <= go_r && ~rd_n_wr_r && (burstcount_r == 0);
        byteenable_r <= start_transaction ? s_axi_wstrb : byteenable_r;
        rd_n_wr_r    <= rd_n_wr_w;
        if (go_r & ~rd_n_wr_r & s_axi_wvalid) begin
            mem[mem_addr_r] <= (mem[mem_addr_r] & ~byteenable_mask) | (s_axi_wdata & byteenable_mask);
        end
    end
end

assign s_axi_awready = ~go_r;
assign s_axi_arready = ~go_r;
assign s_axi_wready = go_r;
assign s_axi_bvalid = bvalid_r;
assign s_axi_bresp = 2'b00;
assign s_axi_rvalid = go_r & ~bvalid_r;
assign s_axi_rlast = go_r & (burstcount_r == 0);
assign s_axi_rdata = mem[mem_addr_r];
assign s_axi_rresp = 2'b00;

endmodule