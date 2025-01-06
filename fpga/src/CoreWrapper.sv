	`timescale 1ns / 1ps
	`default_nettype none
	module CoreWrapper (
		input  wire clk,
		input  wire rst,
		input  wire 	   bus_waitrequest,
		input  wire [31:0] bus_readdata,
		input  wire 	   bus_readdatavalid,
		output wire [ 4:0] m_burstcount,
		output wire [31:0] m_writedata,
		output wire [29:0] m_address,
		output wire        m_write,
		output wire 	   m_read,
		output wire [ 3:0] m_byteenable
	);

		///////////////////
		// Bluespec CPU //
		/////////////////
		wire 		 reqValid;
		wire 		 reqReady;
		wire [3:0]   reqByteStrobe;
		wire 		 reqLineEn;
		wire [29:0]  reqAddr;
		wire [511:0] reqData;

		wire [511:0] respData;
		wire 		 respValid;
		wire 		 respReady;

		mkVROOM iCORE (
			.CLK(clk),
			.RST_N(~rst),
			.EN_getBusReq(reqReady),
			.getBusReq({reqByteStrobe, reqLineEn, reqAddr, reqData}),
			.RDY_getBusReq(reqValid),
			
			.putBusResp_r(respData),
			.EN_putBusResp(respValid),
			.RDY_putBusResp(respReady)
		);

		/////////////////////
		// CPU bus master //
		///////////////////
		

		CpuBusMaster iCPU_MASTER (
			.clk(clk),
			.rst_n(~rst),
			.cpu_reqValid(reqValid),
			.cpu_reqReady(reqReady),
			.cpu_reqByteStrobe(reqByteStrobe),
			.cpu_reqLineEn(reqLineEn),
			.cpu_reqAddr(reqAddr),
			.cpu_reqData(reqData),
			.cpu_respData(respData),
			.cpu_respValid(respValid),
			.cpu_respReady(respReady),
			.bus_m_waitrequest(bus_waitrequest),
			.bus_m_readdata(bus_readdata),
			.bus_m_readdatavalid(bus_readdatavalid),
			.bus_m_burstcount(m_burstcount),
			.bus_m_writedata(m_writedata),
			.bus_m_address(m_address),
			.bus_m_write(m_write),
			.bus_m_read(m_read),
			.bus_m_byteenable(m_byteenable)
		);
	endmodule

	module CpuBusMaster (
		input  wire clk,
		input  wire rst_n,

		input  wire 		cpu_reqValid,
		output wire 		cpu_reqReady,
		input  wire [  3:0] cpu_reqByteStrobe,
		input  wire 		cpu_reqLineEn,
		input  wire [ 29:0] cpu_reqAddr,
		input  wire [511:0] cpu_reqData,

		output wire 		cpu_respValid,
		input  wire			cpu_respReady,
		output wire [511:0] cpu_respData,

		input  wire 	   bus_m_waitrequest,
		input  wire [31:0] bus_m_readdata,
		input  wire 	   bus_m_readdatavalid,
		output wire [ 4:0] bus_m_burstcount,
		output wire [31:0] bus_m_writedata,
		output wire [29:0] bus_m_address,
		output wire 	   bus_m_write,
		output wire 	   bus_m_read,
		output wire [3:0]  bus_m_byteenable
	);

	localparam [1:0] IDLE       = 2'h0;
	localparam [1:0] REQ   		= 2'h1;
	localparam [1:0] TRX   		= 2'h2;
	localparam [1:0] READ_RESP  = 2'h3;

	reg [1:0] state_r;
	reg [1:0] state_rw;

	reg [511:0] data_r;
	reg [511:0] data_rw;

	reg reqReady_rw;
	reg respValid_rw;
	reg respValid_r;

	reg [4:0] bus_m_burstcount_r;
	reg [29:0] bus_m_address_r;
	reg bus_m_write_r;
	reg bus_m_read_r;
	reg [3:0] bus_m_byteenable_r;

	reg [4:0] bus_m_burstcount_rw;
	reg [29:0] bus_m_address_rw;
	reg bus_m_write_rw;
	reg bus_m_read_rw;
	reg [3:0] bus_m_byteenable_rw;

	reg cpu_reqWe_r;
	reg cpu_reqWe_rw;

	always @(posedge clk) begin
		if (!rst_n) begin
			state_r <= IDLE;
			data_r <= 0;
			cpu_reqWe_r <= 0;
			respValid_r <= 0;
		end else begin
			state_r <= state_rw;
			data_r <= data_rw;
			cpu_reqWe_r <= cpu_reqWe_rw;
			respValid_r <= respValid_rw;
		end
	end

	wire cpu_reqWe_w;
	assign cpu_reqWe_w = |cpu_reqByteStrobe;

	always @(*) begin
		state_rw = state_r;
		data_rw = data_r;
		cpu_reqWe_rw = cpu_reqWe_r;
		respValid_rw = 0;
		reqReady_rw = 0;

		bus_m_burstcount_rw = bus_m_burstcount_r;
		bus_m_address_rw = bus_m_address_r;
		bus_m_write_rw = bus_m_write_r;
		bus_m_read_rw = bus_m_read_r;
		bus_m_byteenable_rw = bus_m_byteenable_r;


		case (state_r)
			IDLE: begin
				bus_m_burstcount_rw = 0;
				bus_m_address_rw = 0;
				bus_m_write_rw = 0;
				bus_m_read_rw = 0;
				bus_m_byteenable_rw = 0;

				if (cpu_reqValid) begin
					reqReady_rw = 1;
					data_rw = cpu_reqData;
					bus_m_address_rw = cpu_reqAddr;
					cpu_reqWe_rw = cpu_reqWe_w;
					bus_m_byteenable_rw = ~cpu_reqWe_w ? 4'hF : cpu_reqByteStrobe;
					bus_m_burstcount_rw = cpu_reqLineEn ? 5'h10 : 5'h1;
					bus_m_read_rw = ~cpu_reqWe_w;	
					state_rw = cpu_reqWe_w ? REQ : TRX;
				end
			end
			REQ: begin
				// have to wait until now to assert the write since 
				// data was not ready last cycle
				bus_m_write_rw = cpu_reqWe_r;
				state_rw = TRX;
			end
			TRX: begin
				// stall everything if asserted
				if (!bus_m_waitrequest & (bus_m_write_r | bus_m_readdatavalid)) begin
					data_rw = {bus_m_readdata, data_r[511:32]};
					bus_m_burstcount_rw = bus_m_burstcount_r - 1;
					state_rw = |bus_m_burstcount_rw ? TRX : (bus_m_write_r ? IDLE : READ_RESP);
					// yikes
					if (~|bus_m_burstcount_rw) begin
						bus_m_address_rw = 0;
						bus_m_write_rw = 0;
						bus_m_read_rw = 0;
						bus_m_byteenable_rw = 0;
					end
				end
			end
			READ_RESP: begin
				bus_m_burstcount_rw = 0;
				bus_m_address_rw = 0;
				bus_m_write_rw = 0;
				bus_m_read_rw = 0;
				bus_m_byteenable_rw = 0;

				respValid_rw = cpu_respReady;
				state_rw = cpu_respReady ? IDLE : READ_RESP;
			end
		endcase
	end

	always @(posedge clk) begin
		bus_m_burstcount_r <= bus_m_burstcount_rw;
		bus_m_address_r <= bus_m_address_rw;
		bus_m_write_r <= bus_m_write_rw;
		bus_m_read_r <= bus_m_read_rw;
		bus_m_byteenable_r <= bus_m_byteenable_rw;
	end

	// bluespec takes these signals as an enable signal, 
	// so there is no handshake. if we keep them on all the 
	// time it will spam the rule, which we do not want.
	assign cpu_reqReady = reqReady_rw;
	assign cpu_respData = data_r;
	assign cpu_respValid = respValid_rw;

	// probably starts from other end?
	assign bus_m_writedata = data_r[31:0];
	assign bus_m_burstcount = bus_m_burstcount_r;
	assign bus_m_address = bus_m_address_r;
	assign bus_m_write = bus_m_write_r;
	assign bus_m_read = bus_m_read_r;
	assign bus_m_byteenable = bus_m_byteenable_r;

	endmodule

	`default_nettype wire
