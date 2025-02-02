`default_nettype none
module SimDebug (
    input wire clk_i,
    input wire rst_i,
    input wire uart_all_done,

    // Citron Bus connection
    input  wire [ 7:0] citron_addr,
    input  wire        citron_rdy,
    input  wire        citron_wr,
    input  wire [31:0] citron_writedata,
    output wire [31:0] citron_readdata,
    output wire        citron_stall,
    output wire        citron_match
);
    integer STDERR = 32'h8000_0002;

    wire is_my_transaction = {citron_addr[7:1],1'b0} == 8'hfe; 

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
        if (citron_rdy && citron_wr && is_my_transaction && citron_addr[0]) begin
            $fwrite(STDERR, "%c", citron_writedata[31:24]);
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
        if (citron_rdy && citron_wr && is_my_transaction && !citron_addr[0]) begin
            pend_finish_rw = 1;
            finish_code_rw = {citron_writedata[7:0], citron_writedata[15:8], citron_writedata[23:16], citron_writedata[31:24]};
        end
    end

    assign citron_readdata = 32'h0;
    assign citron_stall = 0;
    assign citron_match = is_my_transaction;
endmodule
`default_nettype wire