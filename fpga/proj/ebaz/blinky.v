module blinky(
    input wire clk,
    input wire rst,
    output wire led_pulse,
    output wire led_high,
    output wire led_low
);


reg [25:0] led_cnt = 0;
always @(posedge clk) begin
    led_cnt <= rst ? 0 : led_cnt + 1;
end

assign led_pulse = led_cnt[25];
assign led_high = 1'b1;
assign led_low = 1'b0;
endmodule
