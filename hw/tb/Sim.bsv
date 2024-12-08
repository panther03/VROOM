import MemTypes::*;
import VROOM::*;
import BRAM::*;
import FIFO::*;
import DelayLine::*;

//typedef enum {
//    DRAM,
//    ROM,
//    MMIO
//} BusRespSource deriving (Bits, Eq);

interface MainMem;
    method Action put(BusReq req);
    method ActionValue#(BusResp) get();
endinterface

module mkMainMem(MainMem);
    BRAM_Configure cfg = defaultValue();
    
    BRAM1Port#(Bit#(24), BusResp) bram <- mkBRAM1Server(cfg);  // spoilers!

    DelayLine#(10, BusResp) dl <- mkDL(); // Delay by 20 cycles

    rule deq;
        let r <- bram.portA.response.get();
        dl.put(r);
        // $display("GOT FROM MM TO DL1 ",fshow(r));
    endrule    


    method Action put(BusReq req);
        bram.portA.request.put(BRAMRequest{
                    write: req.byte_strobe != 0,
                    responseOnWrite: False,
                    address: req.addr[27:4],
                    datain: req.data});
        // $display("SENT TO MM1 WITH ",fshow(req));
    endmethod

    method ActionValue#(BusResp) get();
        let r <- dl.get();
        //$display("GOT FROM DL1 TO CACHE ",fshow(r));
        return r;
    endmethod

endmodule


module mkSim(Empty);
    VROOMIfc vroom <- mkVROOM();
    MainMem mem <- mkMainMem();
    Reg#(Bit#(32)) cycle_count <- mkReg(0);

    BRAM_Configure cfg = defaultValue();
    cfg.loadFormat = tagged Hex "rom.mem";
    BRAM1Port#(Bit#(14), Word) rom <- mkBRAM1Server(cfg);

/* 
    System memory map:

    |--------------|  0x0
    |              |
    |     DRAM     |
    |              |
    |--------------|  0x4000_0000 (1GB)
    |              |
    |    empty     |
    |              |
    |--------------|  0x8000_0000
    |              |
    |    empty     |
    |              |
    |--------------|  0xC000_0000 - start uncached region
    |              |
    |--------------|  0xE000_0000 
    |     MMIO     |
    |--------------|  0xFFFE_0000 
    |   BOOTROM    |
    |--------------|  0xFFFF_FFFF (4GB)
*/

    rule tic;
        cycle_count <= cycle_count + 1;
    endrule

    function Action handleMMIOReq(BusReq req);
    action
        // Read MMIO
        if (req.byte_strobe == 'h0) begin
            // nothing here atm
        end else begin
            let addr32 = {req.addr, 2'h0};
            
            // putchar()
            if (addr32 == 32'he000_fff0) begin
                $fwrite(stderr, "%c", req.data[7:0]);
                $fflush(stderr);
            // exit()
            end else if (addr32 == 32'he000_fff8) begin
                $display("RAN CYCLES", cycle_count);
                if (req.data == 0) begin
                    $fdisplay(stderr, "  [0;32mPASS first thread [0m");
                end else begin
                    $fdisplay(stderr, "  [0;31mFAIL first thread[0m (%0d)", req.data);
                end
                $fflush(stderr);
                $finish;
            end else begin
                $fdisplay(stderr, "Unrecognized MMIO access: %08x", addr32);
            end
        end
    endaction
    endfunction

    rule handleBusReq;
        let req <- vroom.getBusReq();

        // Line requests need to go to DRAM
        if (unpack(req.line_en)) begin
            if (req.addr[29:28] != 2'b00) begin
                $fdisplay(stderr, "DRAM (line) request outside of cached region: %08x", {req.addr, 2'h0});
                $error;
            end 
            mem.put(req);
        end else begin
            // go to BOOTROM
            if (req.addr[29:14] == 16'hFFFE) begin
                if (req.byte_strobe != 4'h0) begin
                    $fdisplay(stderr, "Attempt to write to ROM.. %08x", {req.addr, 2'h0});
                    $error;
                end
                rom.portA.request.put(BRAMRequest {
                    write: False,
                    responseOnWrite: ?,
                    address: req.addr[15:2],
                    datain: ?
                });
            end else if (req.addr[29:26] == 4'hE) begin
                handleMMIOReq(req);
            end else begin
                $fdisplay(stderr, "Illegal word request to uncached region: %08x", {req.addr, 2'h0});
                $error;
            end
        end
    endrule

    (* descending_urgency = "handleROMResp, handleDRAMResp" *)
    rule handleROMResp;
        let resp <- rom.portA.response.get();
        vroom.putBusResp({480'h0, resp});
        endrule
        
    rule handleDRAMResp;
        let resp <- mem.get();
        vroom.putBusResp(resp);
    endrule
    
    // MMIO doesnt generate responses for the time being
endmodule
