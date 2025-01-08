`default_nettype none
module SimDebugSlave #(
    parameter ASSUMED_TRANSACTION=0
) (
    input wire clk_i,
    input wire rst_i,
    input wire uart_all_done,

    // Slave Input
    input wire [4:0] bus_burstcount,
    input wire [31:0] bus_writedata,
    input wire [31:0] bus_address,
    input wire bus_write,
    input wire bus_read,
    input wire [3:0] bus_byteenable,

    // Slave output
    output wire s_waitrequest,
    output wire [31:0] s_readdata,
    output wire s_readdatavalid,
    output wire s_writeresponsevalid,
    output wire [1:0] s_response
);
    integer STDERR = 32'h8000_0002;

    wire is_my_transaction;
    generate if (ASSUMED_TRANSACTION)
        assign is_my_transaction = 1'b1;
    else 
        assign is_my_transaction = bus_address[31:4] == 28'he000_fff; 
    endgenerate 

    reg pend_finish_r;
    reg [31:0] finish_code_r;
    reg pend_finish_rw;
    reg [31:0] finish_code_rw;

    always @(posedge clk_i) begin
        if (rst_i) begin
            pend_finish_r <= 0;
            finish_code_r <= 0;
        end else begin
            pend_finish_r <= pend_finish_rw;
            finish_code_r <= finish_code_rw;
        end
    end

    always @(posedge clk_i) begin
        if (bus_write && is_my_transaction && (bus_address[3:0] == 4'h0)) begin
            $fwrite(STDERR, "%c", bus_writedata[31:24]);
            $fflush(STDERR);
        end
    end

    always @* begin
        finish_code_rw = finish_code_r;
        pend_finish_rw = pend_finish_r;
        if (!rst_i && pend_finish_r && uart_all_done) begin
            if (finish_code_r == 0) begin
                $fdisplay(STDERR, "  [0;32mPASS first thread [0m");
            end else begin
                $fdisplay(STDERR, "  [0;31mFAIL first thread[0m (%0d)", finish_code_r);
            end
            $finish;
        end
        if (bus_write && is_my_transaction && (bus_address[3:0] == 4'h8)) begin
            pend_finish_rw = 1;
            finish_code_rw = {bus_writedata[7:0], bus_writedata[15:8], bus_writedata[23:16], bus_writedata[31:24]};
        end
    end

    assign s_waitrequest = 1'b0;
    assign s_readdata = 32'h0;
    assign s_readdatavalid = bus_read && is_my_transaction;
    assign s_writeresponsevalid = bus_write && is_my_transaction;
    assign s_response = 2'h0;
endmodule
