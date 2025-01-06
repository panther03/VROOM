`default_nettype none
module SimpleMemSlave #(
    parameter [31: 0] base_addr = 32'hDEADBEEF,
    parameter mem_size = 512,
    parameter string loadfile = "none"
) (
    input wire clk_i,
    input wire rst_i,

    // Slave Input
    input wire [4:0] bus_burstcount,
    input wire [31:0] bus_writedata,
    input wire [29:0] bus_address,
    input wire bus_write,
    input wire bus_read,
    input wire [3:0] bus_byteenable,

    // Slave output
    output wire s_waitrequest,
    output wire [31:0] s_readdata,
    output wire s_readdatavalid
);

localparam integer mem_bits = $clog2(mem_size) - 1;
localparam [29:0] base_addr_mask = ~((1 << mem_bits) - 1);
localparam [29:0] base_addr_trunc = base_addr[31:2];

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
reg [ 4:0] burstcount_r = 0;
reg [ 3:0] byteenable_r = 0;

// control signals
wire [mem_bits:0] mem_calc_addr = {(bus_address - base_addr_trunc)}[mem_bits:0];
wire [31:0] byteenable_mask = {{8{byteenable_r[3]}},
    {8{byteenable_r[2]}},
    {8{byteenable_r[1]}},
    {8{byteenable_r[0]}}};
wire is_my_transaction = ((bus_address ^ base_addr_trunc) & base_addr_mask) == 0; 
wire start_transaction = (bus_read || bus_write) && ~go_r;

always @(posedge clk_i) begin
    if (rst_i) begin
        mem_addr_r   <= 0;
        go_r         <= 0;
        rd_n_wr_r    <= 0;
        burstcount_r <= 0;
        byteenable_r <= 0;
    end else begin 
        mem_addr_r   <= go_r ? mem_addr_r+1 : (start_transaction ? mem_calc_addr : 0);
        go_r         <= start_transaction ? is_my_transaction : (burstcount_r == 0 ? 1'b0 : go_r);
        burstcount_r <= (start_transaction ? bus_burstcount : burstcount_r) - 1;
        byteenable_r <= start_transaction ? bus_byteenable : byteenable_r;
        rd_n_wr_r    <= start_transaction ? bus_read : rd_n_wr_r;
        if (go_r & ~rd_n_wr_r) begin
            mem[mem_addr_r] <= (mem[mem_addr_r] & ~byteenable_mask) | (bus_writedata & byteenable_mask);
        end
    end
end

assign s_readdata = (go_r & rd_n_wr_r) ? (byteenable_mask & mem[mem_addr_r]) : 0;
assign s_readdatavalid = go_r;
assign s_waitrequest = is_my_transaction ? ~go_r : 1'b0;
endmodule