// 50mhz clock
`default_nettype none
module tb_harness ( input wire clk, input wire rst );

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

    CoreWrapper #(
        .SIMULATION(0)   
    )iCORE(
        .clk(clk), 
        .rst(rst),
        .irqs(64'h0),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        .av_waitrequest(bus_waitrequest),
        .av_readdata(bus_readdata),
        .av_readdatavalid(bus_readdatavalid),
        .av_writeresponsevalid(bus_writeresponsevalid),
        .av_response(bus_response),
        .av_burstcount(cpu_m_burstcount),
        .av_writedata(cpu_m_writedata),
        .av_address(cpu_m_address),
        .av_write(cpu_m_write),
        .av_read(cpu_m_read),
        .av_byteenable(cpu_m_byteenable)
    );

    ////////////////////////
    // Main memory slave //
    //////////////////////
    wire [31:0] mainmem_s_readdata;
    wire mainmem_s_readdatavalid;
    wire mainmem_s_waitrequest;
    wire mainmem_s_writeresponsevalid;
    wire [1:0] mainmem_s_response;

    SimpleMemSlave #(
        .base_addr(32'h0),
        .mem_size(4096)
    ) iMAINMEM (
        .clk_i(clk),
        .rst_i(rst),
        .bus_burstcount(cpu_m_burstcount),
        .bus_writedata(cpu_m_writedata),
        .bus_address(cpu_m_address[31:2]),
        .bus_write(cpu_m_write),
        .bus_read(cpu_m_read),
        .bus_byteenable(cpu_m_byteenable),
        .s_readdata(mainmem_s_readdata),
        .s_readdatavalid(mainmem_s_readdatavalid),
        .s_waitrequest(mainmem_s_waitrequest),
        .s_writeresponsevalid(mainmem_s_writeresponsevalid),
        .s_response(mainmem_s_response)
    );

    ////////////////
    // ROM slave //
    //////////////
    wire [31:0] rom_s_readdata;
    wire rom_s_readdatavalid;
    wire rom_s_waitrequest;
    wire rom_s_writeresponsevalid;
    wire [1:0] rom_s_response;

    SimpleMemSlave #(
        .base_addr(32'hFFFE0000),
        .mem_size(16384),
        .loadfile("rom.hex")
    ) iROM (
        .clk_i(clk),
        .rst_i(rst),
        .bus_burstcount(cpu_m_burstcount),
        .bus_writedata(cpu_m_writedata),
        .bus_address(cpu_m_address[31:2]),
        .bus_write(cpu_m_write),
        .bus_read(cpu_m_read),
        .bus_byteenable(cpu_m_byteenable),
        .s_readdata(rom_s_readdata),
        .s_readdatavalid(rom_s_readdatavalid),
        .s_waitrequest(rom_s_waitrequest),
        .s_writeresponsevalid(rom_s_writeresponsevalid),
        .s_response(rom_s_response)
    );

    /////////////////////////////
    // instantiate uart model //
    ///////////////////////////
    uartdpi #(
        .BAUD(115200),
        .FREQ(25_000_000)
    ) iUART (
        .clk_i(clk),
        .rst_ni(~rst),
        .active(1'b1),
        .tx_o(uart_rx),
        .rx_i(uart_tx)
    );

    //////////////////
    // Connect Bus //
    ////////////////
    assign bus_readdata = mainmem_s_readdata | rom_s_readdata;
    assign bus_readdatavalid = mainmem_s_readdatavalid | rom_s_readdatavalid;
    assign bus_waitrequest = mainmem_s_waitrequest | rom_s_waitrequest;
    assign bus_writeresponsevalid = mainmem_s_writeresponsevalid | rom_s_writeresponsevalid;
    assign bus_response = mainmem_s_response | rom_s_response;

initial begin
    if ($test$plusargs("trace") != 0) begin
        $display("[%0t] Tracing to logs/vlt_dump.vcd...\n", $time);
        $dumpfile("logs/vlt_dump.vcd");
        $dumpvars(0, tb_harness);
    end
end
endmodule
`default_nettype wire