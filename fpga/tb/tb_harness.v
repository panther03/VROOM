// 50mhz clock
`default_nettype none
module tb_harness ( input wire clk, input wire rst );

    ////////////////////////
    // wire declarations //
    //////////////////////
    wire uart_rx;
    wire uart_tx;
    wire ext_s_waitrequest;
    wire ext_s_readdata;
    wire ext_s_readdatavalid;
    wire ext_s_burstcount;
    wire ext_s_writedata;
    wire ext_s_address;
    wire ext_s_write;
    wire ext_s_read;
    wire ext_s_byteenable;

    CoreWrapper iCORE(
        .clk(clk), 
        .rst(rst),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        .ext_s_waitrequest(ext_s_waitrequest),
        .ext_s_readdata(ext_s_readdata),
        .ext_s_readdatavalid(ext_s_readdatavalid),
        .ext_s_burstcount(ext_s_burstcount),
        .ext_s_writedata(ext_s_writedata),
        .ext_s_address(ext_s_address),
        .ext_s_write(ext_s_write),
        .ext_s_read(ext_s_read),
        .ext_s_byteenable(ext_s_byteenable)
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
        $dumpvars();
    end
end
    always @* begin
        if (finished) $finish;
    end
endmodule
`default_nettype wire