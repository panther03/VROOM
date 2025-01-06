// 50mhz clock
`default_nettype none
module tb_harness ( input wire clk, input wire rst );
    integer STDERR = 32'h8000_0002;

    //////////////////////
    // Bus slave wires //
    ////////////////////
    wire bus_waitrequest;
    wire [31:0] bus_readdata;
    wire bus_readdatavalid;

    ////////////////////////
    // CPU instantiation //
    //////////////////////
    wire [4:0] cpu_m_burstcount;
    wire [31:0] cpu_m_writedata;
    wire [29:0] cpu_m_address;
    wire cpu_m_write;
    wire cpu_m_read;
    wire [3:0] cpu_m_byteenable;

    CoreWrapper iCORE(
        .clk(clk), 
        .rst(rst),
//        .uart_tx(uart_tx),
//        .uart_rx(uart_rx),
        .bus_waitrequest(bus_waitrequest),
        .bus_readdata(bus_readdata),
        .bus_readdatavalid(bus_readdatavalid),
        .m_burstcount(cpu_m_burstcount),
        .m_writedata(cpu_m_writedata),
        .m_address(cpu_m_address),
        .m_write(cpu_m_write),
        .m_read(cpu_m_read),
        .m_byteenable(cpu_m_byteenable)
    );

    ////////////////////////
    // Main memory slave //
    //////////////////////
    wire [31:0] mainmem_s_readdata;
    wire mainmem_s_readdatavalid;
    wire mainmem_s_waitrequest;

    SimpleMemSlave #(
        .base_addr(32'h0),
        .mem_size(4096)
    ) iMAINMEM (
        .clk_i(clk),
        .rst_i(rst),
        .bus_burstcount(cpu_m_burstcount),
        .bus_writedata(cpu_m_writedata),
        .bus_address(cpu_m_address),
        .bus_write(cpu_m_write),
        .bus_read(cpu_m_read),
        .bus_byteenable(cpu_m_byteenable),
        .s_readdata(mainmem_s_readdata),
        .s_readdatavalid(mainmem_s_readdatavalid),
        .s_waitrequest(mainmem_s_waitrequest)
    );

    ////////////////
    // ROM slave //
    //////////////
    wire [31:0] rom_s_readdata;
    wire rom_s_readdatavalid;
    wire rom_s_waitrequest;

    SimpleMemSlave #(
        .base_addr(32'hFFFE0000),
        .mem_size(4096),
        .loadfile("rom.mem")
    ) iROM (
        .clk_i(clk),
        .rst_i(rst),
        .bus_burstcount(cpu_m_burstcount),
        .bus_writedata(cpu_m_writedata),
        .bus_address(cpu_m_address),
        .bus_write(cpu_m_write),
        .bus_read(cpu_m_read),
        .bus_byteenable(cpu_m_byteenable),
        .s_readdata(rom_s_readdata),
        .s_readdatavalid(rom_s_readdatavalid),
        .s_waitrequest(rom_s_waitrequest)
    );

    /////////////////////////////
    // instantiate uart model //
    ///////////////////////////
    //uartdpi #(
    //    .BAUD(115200),
    //    .FREQ(50_000_000)
    //) iUART (
    //    .clk_i(clk),
    //    .rst_ni(~rst),
    //    .active(1'b1),
    //    .tx_o(uart_rx),
    //    .rx_i(uart_tx)
    //);

    //////////////////
    // Connect Bus //
    ////////////////
    assign bus_readdata = mainmem_s_readdata | rom_s_readdata;
    assign bus_readdatavalid = mainmem_s_readdatavalid | rom_s_readdatavalid;
    assign bus_waitrequest = mainmem_s_waitrequest | rom_s_waitrequest;

initial begin
    if ($test$plusargs("trace") != 0) begin
        $display("[%0t] Tracing to logs/vlt_dump.vcd...\n", $time);
        $dumpfile("logs/vlt_dump.vcd");
        $dumpvars();
    end
end
    always @* begin
       if (cpu_m_write && ({cpu_m_address,2'h0} == {32'he000_fff8})) begin
        if (cpu_m_writedata == 0) begin
            $fdisplay(STDERR, "  [0;32mPASS first thread [0m");
        end else begin
            $fdisplay(STDERR, "  [0;31mFAIL first thread[0m (%0d)", {cpu_m_writedata[7:0], cpu_m_writedata[15:8], cpu_m_writedata[23:16], cpu_m_writedata[31:24]});
        end
        $finish;
       end
    end
endmodule
`default_nettype wire