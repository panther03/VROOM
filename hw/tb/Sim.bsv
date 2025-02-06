import MemTypes::*;
import VROOM::*;
import BRAM::*;
import FIFO::*;
import DelayLine::*;
import XRUtil::*;
import Vector::*;

typedef enum {
    DRAM,
    ROM,
    OTHER
} BusRespSource deriving (Bits, Eq);

interface MainMem;
    method Action put(BusReq req);
    method ActionValue#(Bit#(512)) get();
endinterface

module mkMainMem(MainMem);
    BRAM_Configure cfg = defaultValue();
    
    BRAM1Port#(Bit#(12), Bit#(512)) bram <- mkBRAM1Server(cfg);  // spoilers!

    DelayLine#(10, Bit#(512)) dl <- mkDL(); // Delay by 20 cycles

    rule deq;
        let r <- bram.portA.response.get();
        dl.put(r);
        // $display("GOT FROM MM TO DL1 ",fshow(r));
    endrule    


    method Action put(BusReq req);
        bram.portA.request.put(BRAMRequest{
                    write: req.byte_strobe != 0,
                    responseOnWrite: False,
                    address: req.addr[15:4],
                    datain: req.data});
        //$display("SENT TO MM1 WITH ",fshow(req));
    endmethod

    method ActionValue#(Bit#(512)) get();
        let r <- dl.get();
        //$display("GOT FROM DL1 TO CACHE ",fshow(r));
        return r;
    endmethod

endmodule


module mkSim(Empty);
    VROOMIfc vroom <- mkVROOM();
    MainMem mem <- mkMainMem();
    FIFO#(BusRespSource) respTracker <- mkFIFO;
    FIFO#(Maybe#(Bit#(4))) lineOffset <- mkFIFO;
    Reg#(Bit#(32)) cycle_count <- mkReg(0);
    FIFO#(Maybe#(Bit#(32))) otherResps <- mkFIFO;

    BRAM_Configure cfg = defaultValue();
    cfg.loadFormat = tagged Hex "rom.hex";
    BRAM1Port#(Bit#(14), Word) rom <- mkBRAM1Server(cfg);

    BRAM_Configure scfg = defaultValue();
    scfg.loadFormat = tagged Hex "stim.hex";
    BRAM1Port#(Bit#(8), Bit#(8)) serialStim <- mkBRAM1Server(scfg);
    Reg#(Bit#(8)) serialStimAddr <- mkReg(0);
    Reg#(Bool) stimValid <- mkReg(True);

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
            respTracker.enq(OTHER);
            if (addr32 == 32'hf800_0040) begin
                otherResps.enq(tagged Valid(0));
            end else if (addr32 == 32'hf800_0044) begin
                if (stimValid) begin
                    serialStim.portA.request.put(BRAMRequest {
                        write: False,
                        responseOnWrite: ?,
                        address: serialStimAddr,
                        datain: ?
                    });
                    serialStimAddr <= serialStimAddr + 1;
                end else begin
                    otherResps.enq(tagged Valid({16'hFFFF, 16'h0000}));        
                end
            end else if (addr32[31:16] == 16'hF803 && addr32[15:5] == 0) begin
                otherResps.enq(tagged Valid({32'h0}));
            end else if (addr32 == 32'hf800_0064 || addr32 == 32'hf800_0068 || addr32 == 32'hf800_006c) begin
                // disk
                otherResps.enq(tagged Valid({32'h0}));
            end else if (addr32[31:12] == 20'hF8001) begin
                $display("NVRAM read");
                otherResps.enq(tagged Valid({32'h0}));
            end else if (addr32[31:4] == 28'hf800_00c) begin                
                $display("amtsu read");
                otherResps.enq(tagged Valid({16'hFFFF, 16'h0000}));
            end else begin
                vroom.putBusError(BusError {
                    badAddr: {req.addr, 2'h0}
                });
                otherResps.enq(tagged Invalid);
            end            
            //$fdisplay(stderr, "Unrecognized MMIO read: %08x", addr32);
        end else begin
            // putchar() OR serial on citron bus
            if (addr32 == 32'hf800_03fc || addr32 == 32'hf800_0044) begin
                $fwrite(stderr, "%c", req.data[31:24]);
                $fflush(stderr);
            // exit()
            end else if (addr32 == 32'hf800_03f8) begin
                $display("RAN CYCLES", cycle_count);
                if (req.data == 0) begin
                    $fdisplay(stderr, "  [0;32mPASS first thread [0m");
                end else begin
                    $fdisplay(stderr, "  [0;31mFAIL first thread[0m (%0d)", swap32(req.data[31:0]));
                end
                $fflush(stderr);
                $finish;
            end else if (addr32[31:12] == 20'hF8001) begin
                $display("NVRAM write");
            end else if (addr32[31:16] == 16'hF803 && addr32[15:5] == 0) begin
                $display("local LSIC write");
            end else if (addr32 == 32'hf800_0064 || addr32 == 32'hf800_0068 || addr32 == 32'hf800_006c) begin
                $display("disk write");
            end else if (addr32[31:4] == 28'hf800_00c) begin                
                $display("amtsu write");
            end else if (addr32 == 32'hF8800000) begin
                $display("Reset EBUS");
            end else begin
                vroom.putBusError(BusError {
                    badAddr: {req.addr, 2'h0}
                });
            end
        end
    endaction
    endfunction

    rule handleSerialStimResp;
        let resp <- serialStim.portA.response.get();
        if (resp == 0) stimValid <= False;
        otherResps.enq(tagged Valid({resp, 24'h0}));
    endrule

    rule handleBusReq;
        let req <- vroom.getBusReq();

        // is it a non-mmio access
        if (req.addr[29:28] != 2'b11) begin 
            if (req.addr[29:14] != 16'h0) begin
                $fdisplay(stderr, "DRAM (line) request outside of cached region: %08x", {req.addr, 2'h0});
                vroom.putBusError(BusError {
                    badAddr: {req.addr, 2'h0}
                });
                if (req.byte_strobe == 4'h0) begin
                    otherResps.enq(tagged Invalid);
                    respTracker.enq(OTHER);
                end
            end else begin
                mem.put(req);
                if (req.byte_strobe == 4'h0) begin
                    lineOffset.enq(unpack(req.line_en) ? tagged Invalid : tagged Valid(req.addr[3:0]));
                    respTracker.enq(DRAM);
                end
            end
        end else begin
            // no burst in MMIO
            if (unpack(req.line_en)) begin
                $fdisplay(stderr, "Attempt to burst in MMIO region");
                $finish;
            end
            // go to BOOTROM
            if (req.addr[29:14] == 16'hFFFE) begin
                if (req.byte_strobe != 4'h0) begin
                    $fdisplay(stderr, "Attempt to write to ROM.. %08x", {req.addr, 2'h0});
                    vroom.putBusError(BusError {
                        badAddr: {req.addr, 2'h0}
                    });
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
        let err = False;
        case (respSource)
            DRAM: begin
                resp <- mem.get();
                let offset = lineOffset.first; lineOffset.deq();
                if (isValid(offset)) begin
                    Vector#(16, Word) lineRespWords = unpack(resp);
                    resp = {lineRespWords[fromMaybe(?, offset)], 480'h0};
                end
            end
            ROM: begin
                Bit#(32) romWord <- rom.portA.response.get();
                resp = {romWord, 480'h0};
            end
            OTHER: begin
                otherResps.deq();
                if (isValid(otherResps.first)) begin
                    resp = {fromMaybe(?, otherResps.first), 480'h0};
                end else begin
                    err = True;
                end                
            end
        endcase
        vroom.putBusResp(BusResp { data: resp, err: err });
    endrule

    rule irqDefault;
        vroom.putIrq(False);
    endrule
endmodule
