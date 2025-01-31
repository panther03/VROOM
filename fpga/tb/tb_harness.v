// 50mhz clock
`default_nettype none
module tb_harness ( input wire clk, input wire rst );
    wire        rom_s_axi_awvalid;
    wire        rom_s_axi_awready;
    wire [31:0] rom_s_axi_awaddr;
    wire [ 7:0] rom_s_axi_awlen;
    wire [ 2:0] rom_s_axi_awsize;
    wire [ 1:0] rom_s_axi_awburst;
    wire 	    rom_s_axi_wvalid;
    wire        rom_s_axi_wready;
    wire [31:0] rom_s_axi_wdata;
    wire [ 3:0] rom_s_axi_wstrb;
    wire  	    rom_s_axi_bvalid;
    wire        rom_s_axi_bready;
    wire [ 1:0] rom_s_axi_bresp;
    wire        rom_s_axi_arvalid;
    wire        rom_s_axi_arready;
    wire [31:0] rom_s_axi_araddr;
    wire [ 7:0] rom_s_axi_arlen;
    wire [ 2:0] rom_s_axi_arsize;
    wire [ 1:0] rom_s_axi_arburst;
    wire 	    rom_s_axi_rvalid;
    wire        rom_s_axi_rready;
    wire        rom_s_axi_rlast;
    wire [31:0] rom_s_axi_rdata;
    wire [ 1:0] rom_s_axi_rresp;

    wire        ram_s_axi_awvalid;
    wire        ram_s_axi_awready;
    wire [31:0] ram_s_axi_awaddr;
    wire [ 7:0] ram_s_axi_awlen;
    wire [ 2:0] ram_s_axi_awsize;
    wire [ 1:0] ram_s_axi_awburst;
    wire 	    ram_s_axi_wvalid;
    wire        ram_s_axi_wready;
    wire [31:0] ram_s_axi_wdata;
    wire [ 3:0] ram_s_axi_wstrb;
    wire  	    ram_s_axi_bvalid;
    wire        ram_s_axi_bready;
    wire [ 1:0] ram_s_axi_bresp;
    wire        ram_s_axi_arvalid;
    wire        ram_s_axi_arready;
    wire [31:0] ram_s_axi_araddr;
    wire [ 7:0] ram_s_axi_arlen;
    wire [ 2:0] ram_s_axi_arsize;
    wire [ 1:0] ram_s_axi_arburst;
    wire 	    ram_s_axi_rvalid;
    wire        ram_s_axi_rready;
    wire        ram_s_axi_rlast;
    wire [31:0] ram_s_axi_rdata;
    wire [ 1:0] ram_s_axi_rresp;


    //////////////////////
    // Bus slave wires //
    ////////////////////
    wire bus_waitrequest;
    wire [31:0] bus_readdata;
    wire bus_readdatavalid;
    wire [1:0] bus_response;
    wire bus_writeresponsevalid;


    ////////////////////////
    // CPU instantiation //
    //////////////////////
    wire [4:0] cpu_m_burstcount;
    wire [31:0] cpu_m_writedata;
    wire [31:0] cpu_m_address;
    wire cpu_m_write;
    wire cpu_m_read;
    wire [3:0] cpu_m_byteenable;
    wire uart_tx;
    wire uart_rx;

    VROOMSoC #(
        .SIMULATION(1)   
    ) iSOC (
        .clk(clk), 
        .rst(rst),

        .rom_m_axi_awvalid(rom_s_axi_awvalid),
        .rom_m_axi_awready(rom_s_axi_awready),
        .rom_m_axi_awaddr(rom_s_axi_awaddr),
        .rom_m_axi_awlen(rom_s_axi_awlen),
        .rom_m_axi_awsize(rom_s_axi_awsize),
        .rom_m_axi_awburst(rom_s_axi_awburst),
        .rom_m_axi_wvalid(rom_s_axi_wvalid),
        .rom_m_axi_wready(rom_s_axi_wready),
        .rom_m_axi_wdata(rom_s_axi_wdata),
        .rom_m_axi_wstrb(rom_s_axi_wstrb),
        .rom_m_axi_bvalid(rom_s_axi_bvalid),
        .rom_m_axi_bready(rom_s_axi_bready),
        .rom_m_axi_bresp(rom_s_axi_bresp),
        .rom_m_axi_arvalid(rom_s_axi_arvalid),
        .rom_m_axi_arready(rom_s_axi_arready),
        .rom_m_axi_araddr(rom_s_axi_araddr),
        .rom_m_axi_arlen(rom_s_axi_arlen),
        .rom_m_axi_arsize(rom_s_axi_arsize),
        .rom_m_axi_arburst(rom_s_axi_arburst),
        .rom_m_axi_rvalid(rom_s_axi_rvalid),
        .rom_m_axi_rready(rom_s_axi_rready),
        .rom_m_axi_rlast(rom_s_axi_rlast),
        .rom_m_axi_rdata(rom_s_axi_rdata),
        .rom_m_axi_rresp(rom_s_axi_rresp),

        .ram_m_axi_awvalid(ram_s_axi_awvalid),
        .ram_m_axi_awready(ram_s_axi_awready),
        .ram_m_axi_awaddr(ram_s_axi_awaddr),
        .ram_m_axi_awlen(ram_s_axi_awlen),
        .ram_m_axi_awsize(ram_s_axi_awsize),
        .ram_m_axi_awburst(ram_s_axi_awburst),
        .ram_m_axi_wvalid(ram_s_axi_wvalid),
        .ram_m_axi_wready(ram_s_axi_wready),
        .ram_m_axi_wdata(ram_s_axi_wdata),
        .ram_m_axi_wstrb(ram_s_axi_wstrb),
        .ram_m_axi_bvalid(ram_s_axi_bvalid),
        .ram_m_axi_bready(ram_s_axi_bready),
        .ram_m_axi_bresp(ram_s_axi_bresp),
        .ram_m_axi_arvalid(ram_s_axi_arvalid),
        .ram_m_axi_arready(ram_s_axi_arready),
        .ram_m_axi_araddr(ram_s_axi_araddr),
        .ram_m_axi_arlen(ram_s_axi_arlen),
        .ram_m_axi_arsize(ram_s_axi_arsize),
        .ram_m_axi_arburst(ram_s_axi_arburst),
        .ram_m_axi_rvalid(ram_s_axi_rvalid),
        .ram_m_axi_rready(ram_s_axi_rready),
        .ram_m_axi_rlast(ram_s_axi_rlast),
        .ram_m_axi_rdata(ram_s_axi_rdata),
        .ram_m_axi_rresp(ram_s_axi_rresp),

        .uart_tx(uart_tx),
        .uart_rx(uart_rx)
    );

    ////////////////////////
    // Main memory slave //
    //////////////////////

    SimpleMemSlave #(
        .base_addr(32'h0),
        .mem_size(4096)
    ) iMAINMEM (
        .clk_i(clk),
        .rst_i(rst),
        .s_axi_awvalid(ram_s_axi_awvalid),
        .s_axi_awready(ram_s_axi_awready),
        .s_axi_awaddr(ram_s_axi_awaddr),
        .s_axi_awlen(ram_s_axi_awlen),
        .s_axi_awsize(ram_s_axi_awsize),
        .s_axi_awburst(ram_s_axi_awburst),
        .s_axi_wvalid(ram_s_axi_wvalid),
        .s_axi_wready(ram_s_axi_wready),
        .s_axi_wdata(ram_s_axi_wdata),
        .s_axi_wstrb(ram_s_axi_wstrb),
        .s_axi_bvalid(ram_s_axi_bvalid),
        .s_axi_bready(ram_s_axi_bready),
        .s_axi_bresp(ram_s_axi_bresp),
        .s_axi_arvalid(ram_s_axi_arvalid),
        .s_axi_arready(ram_s_axi_arready),
        .s_axi_araddr(ram_s_axi_araddr),
        .s_axi_arlen(ram_s_axi_arlen),
        .s_axi_arsize(ram_s_axi_arsize),
        .s_axi_arburst(ram_s_axi_arburst),
        .s_axi_rvalid(ram_s_axi_rvalid),
        .s_axi_rready(ram_s_axi_rready),
        .s_axi_rlast(ram_s_axi_rlast),
        .s_axi_rdata(ram_s_axi_rdata),
        .s_axi_rresp(ram_s_axi_rresp)
    );

    ////////////////
    // ROM slave //
    //////////////

    SimpleMemSlave #(
        .base_addr(32'hFFFE0000),
        .mem_size(16384),
        .loadfile("rom.hex")
    ) iROM (
        .clk_i(clk),
        .rst_i(rst),
        .s_axi_awvalid(rom_s_axi_awvalid),
        .s_axi_awready(rom_s_axi_awready),
        .s_axi_awaddr(rom_s_axi_awaddr),
        .s_axi_awlen(rom_s_axi_awlen),
        .s_axi_awsize(rom_s_axi_awsize),
        .s_axi_awburst(rom_s_axi_awburst),
        .s_axi_wvalid(rom_s_axi_wvalid),
        .s_axi_wready(rom_s_axi_wready),
        .s_axi_wdata(rom_s_axi_wdata),
        .s_axi_wstrb(rom_s_axi_wstrb),
        .s_axi_bvalid(rom_s_axi_bvalid),
        .s_axi_bready(rom_s_axi_bready),
        .s_axi_bresp(rom_s_axi_bresp),
        .s_axi_arvalid(rom_s_axi_arvalid),
        .s_axi_arready(rom_s_axi_arready),
        .s_axi_araddr(rom_s_axi_araddr),
        .s_axi_arlen(rom_s_axi_arlen),
        .s_axi_arsize(rom_s_axi_arsize),
        .s_axi_arburst(rom_s_axi_arburst),
        .s_axi_rvalid(rom_s_axi_rvalid),
        .s_axi_rready(rom_s_axi_rready),
        .s_axi_rlast(rom_s_axi_rlast),
        .s_axi_rdata(rom_s_axi_rdata),
        .s_axi_rresp(rom_s_axi_rresp)
    );

    /////////////////////////////
    // instantiate uart model //
    ///////////////////////////
    uartdpi #(
        .BAUD(115200),
        .FREQ(50_000_000)
    ) iUART (
        .clk_i(clk),
        .rst_ni(~rst),
        .active(1'b1),
        .tx_o(uart_rx),
        .rx_i(uart_tx)
    );

initial begin
    if ($test$plusargs("trace") != 0) begin
        $display("[%0t] Tracing to logs/vlt_dump.vcd...\n", $time);
        $dumpfile("logs/vlt_dump.vcd");
        $dumpvars(0, tb_harness);
    end
end
endmodule
`default_nettype wire