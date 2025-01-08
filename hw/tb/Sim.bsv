import MemTypes::*;
import VROOM::*;
import BRAM::*;
import FIFO::*;
import DelayLine::*;
import XRUtil::*;

typedef enum {
    DRAM,
    ROM,
    MMIO
} BusRespSource deriving (Bits, Eq);

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
    FIFO#(BusRespSource) respTracker <- mkFIFO;
    Reg#(Bit#(32)) cycle_count <- mkReg(0);
    FIFO#(Bit#(32)) mmioResps <- mkFIFO;

    BRAM_Configure cfg = defaultValue();
    cfg.loadFormat = tagged Hex "rom.hex";
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
        let addr32 = {req.addr, 2'h0};
        // Read MMIO
        if (req.byte_strobe == 'h0) begin
            // nothing here atm
            // hack to get serial input (or lack thereof) working
            mmioResps.enq(addr32 == 32'hf800_0044 ? {16'hFFFF, 16'h0000} : 32'h0);
            respTracker.enq(MMIO);
            //$fdisplay(stderr, "Unrecognized MMIO read: %08x", addr32);
        end else begin
            // putchar() OR serial on citron bus
            if (addr32 == 32'he000_fff0 || addr32 == 32'hf800_0044) begin
                $fwrite(stderr, "%c", req.data[31:24]);
                $fflush(stderr);
            // exit()
            end else if (addr32 == 32'he000_fff8) begin
                $display("RAN CYCLES", cycle_count);
                if (req.data == 0) begin
                    $fdisplay(stderr, "  [0;32mPASS first thread [0m");
                end else begin
                    $fdisplay(stderr, "  [0;31mFAIL first thread[0m (%0d)", swap32(req.data[31:0]));
                end
                $fflush(stderr);
                $finish;
            end else if (addr32[31:12] == 20'hF8001) begin
                $display("NVRAM write..");
                //$finish;
            end else begin
                //$fdisplay(stderr, "Unrecognized MMIO write: %08x", addr32);
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
                $finish;
            end 
            mem.put(req);
            if (req.byte_strobe == 4'h0)
                respTracker.enq(DRAM);
        end else begin
            // go to BOOTROM
            if (req.addr[29:14] == 16'hFFFE) begin
                if (req.byte_strobe != 4'h0) begin
                    $fdisplay(stderr, "Attempt to write to ROM.. %08x", {req.addr, 2'h0});
                    $finish;
                end
                rom.portA.request.put(BRAMRequest {
                    write: False,
                    responseOnWrite: ?,
                    address: req.addr[13:0],
                    datain: ?
                });
                respTracker.enq(ROM);
            end else begin
            // if (req.addr[29:26] == 4'hE)
                handleMMIOReq(req);
            //end else begin
            //    $fdisplay(stderr, "Illegal word request to uncached region: %08x", {req.addr, 2'h0});
            //    $finish;
            end
        end
    endrule

    rule handleBusResp;
        let respSource = respTracker.first; respTracker.deq();
        let resp = 512'h0;
        case (respSource)
            DRAM: resp <- mem.get();
            ROM: begin
                Bit#(32) romWord <- rom.portA.response.get();
                resp = {romWord, 480'h0};
            end
            MMIO: begin
                resp = {mmioResps.first, 480'h0}; mmioResps.deq();
            end
        endcase
        vroom.putBusResp(resp);
    endrule

    rule irqDefault;
        vroom.putIrq(False);
        vroom.putBusError(False);
    endrule
endmodule
