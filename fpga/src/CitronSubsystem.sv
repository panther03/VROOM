`default_nettype none
module CitronSubsystem #(
    parameter SIMULATION = 0	
) (
    input wire clk_i,
    input wire rst_i,

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
	output wire [ 1:0] s_axi_rresp,

    // Device external connections
    output wire        uart_tx,
    input  wire        uart_rx
);

wire [31:0] bus_citron_readdata;
wire bus_citron_stall;
wire bus_citron_match;

////////////////////////
// AXI Slave Control //
//////////////////////
typedef enum reg [1:0] { READY, RD, WDATA, WRESP } axi_slv_state_t;
axi_slv_state_t state_r, state_rw = READY;
reg rd_n_wr_r, rd_n_wr_rw;

reg s_axi_awready_r, s_axi_awready_rw;
reg s_axi_arready_r, s_axi_arready_rw;
reg s_axi_wready_r, s_axi_wready_rw;
reg s_axi_rvalid_r, s_axi_rvalid_rw;
reg [1:0] s_axi_rresp_r, s_axi_rresp_rw;
reg s_axi_bvalid_r, s_axi_bvalid_rw;

reg [31:0] s_axi_rdata_r, s_axi_rdata_rw;

reg [7:0] bus_citron_addr_r, bus_citron_addr_rw;
reg bus_citron_rdy_rw;
reg bus_citron_wr_r, bus_citron_wr_rw;

always_ff @(posedge clk_i) begin
    if (rst_i) begin
        state_r <= READY;
        rd_n_wr_r <= 0;

        bus_citron_addr_r <= 0;
        bus_citron_wr_r <= 0;

        s_axi_awready_r <= 0;
        s_axi_arready_r <= 0;
        s_axi_wready_r <= 0;
        s_axi_rvalid_r <= 0;
        s_axi_rresp_r <= 0;
        s_axi_bvalid_r <= 0;
        s_axi_rdata_r <= 0;
    end else begin
        state_r <= state_rw;
        rd_n_wr_r <= rd_n_wr_rw;

        bus_citron_addr_r <= bus_citron_addr_rw;
        bus_citron_wr_r <= bus_citron_wr_rw;

        s_axi_awready_r <= s_axi_awready_rw;
        s_axi_arready_r <= s_axi_arready_rw;
        s_axi_wready_r <= s_axi_wready_rw;
        s_axi_rvalid_r <= s_axi_rvalid_rw;
        s_axi_rresp_r <= s_axi_rresp_rw;
        s_axi_bvalid_r <= s_axi_bvalid_rw;
        s_axi_rdata_r <= s_axi_rdata_rw;
    end
end

wire [31:0] req_addr = rd_n_wr_rw ? s_axi_araddr : s_axi_awaddr;
wire is_my_transaction = req_addr[31:10] == 22'h3e0000; 
wire aw_handshake = s_axi_awvalid && s_axi_awready_r;
wire ar_handshake = s_axi_arvalid && s_axi_arready_r;

always_comb begin
    state_rw = state_r;
    rd_n_wr_rw = rd_n_wr_r;
    
    bus_citron_rdy_rw = 0;
    bus_citron_addr_rw = bus_citron_addr_r;
    bus_citron_wr_rw = bus_citron_wr_r;

    s_axi_awready_rw = s_axi_awready_r;
    s_axi_arready_rw = s_axi_arready_r;
    s_axi_wready_rw = s_axi_wready_r;
    s_axi_rvalid_rw = s_axi_rvalid_r;
    s_axi_bvalid_rw = s_axi_bvalid_r;
    s_axi_rresp_rw = {2{~bus_citron_match}};
    s_axi_rdata_rw = s_axi_rdata_r;

    case (state_r) 
        READY: begin
            s_axi_awready_rw = 1;
            s_axi_arready_rw = 1;
            if (is_my_transaction && (aw_handshake || ar_handshake)) begin
                rd_n_wr_rw = s_axi_arvalid;
                bus_citron_addr_rw = req_addr[9:2];
                bus_citron_rdy_rw = rd_n_wr_rw;
                bus_citron_wr_rw = ~rd_n_wr_rw;
                s_axi_wready_rw = ~rd_n_wr_rw;
                s_axi_awready_rw = 0;
                s_axi_arready_rw = 0;
                state_rw = rd_n_wr_rw ? RD: WDATA;
            end
        end
        RD: begin
            s_axi_rvalid_rw = s_axi_rvalid_r | ~bus_citron_stall;
            s_axi_rdata_rw = s_axi_rvalid_r ? s_axi_rdata_r : bus_citron_readdata;
            if (s_axi_rvalid_r && s_axi_rready) begin
                s_axi_rvalid_rw = 0;
                state_rw = READY;
            end
        end
        WDATA: begin
            s_axi_wready_rw = 1;
            if (s_axi_wready_r && s_axi_wvalid) begin
                // stalls dont happen on write
                bus_citron_rdy_rw = 1;
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

/////////////////////
// Citron Devices //
///////////////////

wire [ 7:0] bus_citron_addr = bus_citron_addr_rw;
wire        bus_citron_rdy = bus_citron_rdy_rw;
wire        bus_citron_wr = bus_citron_wr_rw;
wire [31:0] bus_citron_writedata = s_axi_wdata;


// UART
wire [31:0] uart_citron_readdata;
wire        uart_citron_stall;
wire        uart_citron_match;

wire        uart_all_done;

spart iSPART (
    .clk(clk_i),
    .rst_n(~rst_i),
    .citron_addr(bus_citron_addr),
    .citron_rdy(bus_citron_rdy),
    .citron_wr(bus_citron_wr),
    .citron_readdata(uart_citron_readdata),
    .citron_writedata(bus_citron_writedata),
    .citron_stall(uart_citron_stall),
    .citron_match(uart_citron_match),
    .all_done(uart_all_done),
    .TX(uart_tx),
    .RX(uart_rx)
);

// Simulation module
wire [31:0] simdebug_citron_readdata;
wire        simdebug_citron_stall;
wire        simdebug_citron_match;

generate if (SIMULATION) begin
    SimDebug iDEBUG (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .uart_all_done(uart_all_done),
        .citron_addr(bus_citron_addr),
        .citron_rdy(bus_citron_rdy),
        .citron_wr(bus_citron_wr),
        .citron_readdata(simdebug_citron_readdata),
        .citron_writedata(bus_citron_writedata),
        .citron_stall(simdebug_citron_stall),
        .citron_match(simdebug_citron_match)
    );
end else begin
    assign simdebug_citron_readdata = 32'h0;
    assign simdebug_citron_stall = 0;
    assign simdebug_citron_match = 0;
end endgenerate

////////////////////////
// OR Citron Signals //
//////////////////////
assign bus_citron_readdata = uart_citron_readdata | simdebug_citron_readdata;
assign bus_citron_stall = uart_citron_stall | simdebug_citron_stall;
assign bus_citron_match = uart_citron_match | simdebug_citron_match;

/////////////////////
// Assign Outputs //
///////////////////

assign s_axi_awready = s_axi_awready_r;
assign s_axi_arready = s_axi_arready_r;
assign s_axi_wready = s_axi_wready_r;
assign s_axi_bvalid = s_axi_bvalid_r;
assign s_axi_bresp = 2'b00;
assign s_axi_rlast = 1'b1; // does not do bursts
assign s_axi_rvalid = s_axi_rvalid_r;
assign s_axi_rdata = s_axi_rdata_r;
assign s_axi_rresp = s_axi_rresp_r;

endmodule