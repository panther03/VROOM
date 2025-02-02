// SINGLE CORE ASSOIATED CACHE -- stores words

import BRAM::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import MemTypes::*;
import Ehr::*;
import Vector::*;
import SrReg::*;

Bool debug = False;

typedef struct {
    L1LineTag tag;
    Bool valid;
} FlushInfo deriving (Bits);

interface L1CAU;
    method ActionValue#(HitMissType) req(DMemReq c);
    method ActionValue#(L1TaggedLine) resp;
    method ActionValue#(Bool) lookup(Bit#(5) line);
    method Action update(L1LineIndex index, LineData data, L1LineTag tag, Bool dirty);
    method Action clearValid();
endinterface

module mkL1CAU(L1CAU);
    Vector#(TExp#(5), Reg#(L1LineTag)) tagStore <- replicateM(mkReg(0));
    Reg#(Vector#(TExp#(5), Bool)) validStore <- mkReg(replicate(False));
    BRAM_Configure cfg = defaultValue();
    cfg.latency = 2;
    BRAM1PortBE#(Bit#(5), LineData, 64) dataStore <- mkBRAM1ServerBE(cfg);
    BRAM1Port#(Bit#(5), Bool) dirtyStore <- mkBRAM1Server(cfg);
    FIFO#(L1LineTag) tagFifo <- mkFIFO;
    
    method ActionValue#(HitMissType) req(DMemReq c);
        let pa = parseL1Address(c.addr);
        let tag = tagStore[pa.index];
        let valid = validStore[pa.index];
        if (debug) $display("ind: %d, wb: %d valid: ", pa.index, c.word_byte, fshow(valid));
        let hit = tag == pa.tag && valid;
        if (hit) begin
            if (c.word_byte == 0) begin // load hit
                tagFifo.enq(tag);
                dataStore.portA.request.put(BRAMRequestBE{
                    writeen: 64'h0,
                    responseOnWrite: False,
                    address: pa.index,
                    datain: ?
                });
                // we don't care if it's dirty or not, but we do this
                // just so we can dequeue from both in resp
                dirtyStore.portA.request.put(BRAMRequest{
                    write: False,
                    responseOnWrite: False,
                    address: pa.index,
                    datain: ?
                });
                return LdHit;
            end else begin // store hit
                dirtyStore.portA.request.put(BRAMRequest{
                    write: True,
                    responseOnWrite: False,
                    address: pa.index,
                    datain: True
                });
                Bit#(512) cd_64  = zeroExtend(c.data);
                Bit#(64) we = calcBE(pa, c);
                Bit#(64) data_ofs = zeroExtend(pa.offset) << 5;
                dataStore.portA.request.put(BRAMRequestBE{
                    writeen: we,
                    responseOnWrite: False,
                    address: pa.index,
                    datain: cd_64 << data_ofs
                });
                return StHit;
            end
        end else begin
            tagFifo.enq(tag);
            dirtyStore.portA.request.put(BRAMRequest{
                write: False,
                responseOnWrite: False,
                address: pa.index,
                datain: ?
            });
            dataStore.portA.request.put(BRAMRequestBE{
                writeen: 64'h0,
                responseOnWrite: False,
                address: pa.index,
                datain: ?
            });
            return Miss;
        end
    endmethod

    method ActionValue#(Bool) lookup(Bit#(5) line);
        let tag = tagStore[line];
        let valid = validStore[line];
        if (valid) begin
            dirtyStore.portA.request.put(BRAMRequest{
                write: False,
                responseOnWrite: False,
                address: line,
                datain: ?
            });
            dataStore.portA.request.put(BRAMRequestBE{
                writeen: 64'h0,
                responseOnWrite: False,
                address: line,
                datain: ?
            });
            tagFifo.enq(tag);
        end
        return valid;
    endmethod

    method ActionValue#(L1TaggedLine) resp;
        let isDirty <- dirtyStore.portA.response.get();
        let data <- dataStore.portA.response.get();
        tagFifo.deq(); 
        let tag = tagFifo.first();
        return L1TaggedLine { data: data, isDirty: isDirty, tag: tag };
    endmethod

    // TODO: do update() and req() need to be called in the same cycle?
    // if so, how will we manage the read-after write behavior?
    // does a 1-port BRAM even have a separate port for reading and writing?
    method Action update(L1LineIndex index, LineData data, L1LineTag tag, Bool dirty);
        tagStore[index] <= tag;
        validStore[index] <= True;
        if (debug) $display("Updating line @ %d", index, fshow(data));
        dirtyStore.portA.request.put(BRAMRequest{
            write: True,
            responseOnWrite: False,
            address: index,
            datain: dirty
        });
        dataStore.portA.request.put(BRAMRequestBE{
            writeen: 64'hFFFFFFFFFFFFFFFF,
            responseOnWrite: False,
            address: index,
            datain: data
        });
    endmethod

    method Action clearValid();
        validStore <= replicate(False);
    endmethod
endmodule

typedef struct {
    DMemReq req;
    Bool hit;
} HitMissDMemReq deriving (Eq, FShow, Bits, Bounded);

// Notice the asymmetry in this interface, as mentioned in lecture.
// The processor thinks in 32 bits, but the other side thinks in 512 bits.
interface Cache32;
    method Action putFromProc(DMemReq e, Bool passthrough);
    method ActionValue#(Word) getToProc();
    method ActionValue#(BusReq) getToMem();
    method Action putFromMem(BusResp e);
    method Action invalidateLines();
    method Action putFlushRequest();
    method Action blockTillFlushDone();
endinterface

(* synthesize *)
module mkCache32(Cache32);

    L1CAU cau <- mkL1CAU();

    FIFO#(Word) hitQ <- mkBypassFIFO;
    FIFO#(HitMissDMemReq) currReqQ <- mkPipelineFIFO;
    FIFO#(BusReq) lineReqQ <- mkFIFO;
    FIFO#(BusResp) lineRespQ <- mkFIFO;
    FIFO#(Bit#(5)) flushIndexQ <- mkFIFO;

    Reg#(CacheState) state <- mkReg(WaitCAUResp);
    Reg#(Bit#(32)) cyc <- mkReg(0);

    Reg#(Bool) doPassthrough <- mkReg(False);
    
    SrReg doInvalidate <- mkSrReg(True);
    SrReg doFlush <- mkSrReg(True);
    
    Reg#(Bit#(6)) flushCounter <- mkReg(0);

    rule cyc_count_debug if (debug);
        cyc <= cyc + 1;
    endrule

    rule handleInvalidate if (state == WaitCAUResp && !doFlush.read() && doInvalidate.read());
        cau.clearValid();
        doInvalidate.reset();
    endrule

    (* descending_urgency = "flushOutResponses, flushThroughCache" *)
    rule flushOutResponses if (state == WaitCAUResp && doFlush.read());
        let index = flushIndexQ.first; flushIndexQ.deq();
        let resp <- cau.resp();
        if (resp.isDirty) begin
            // TODO: we should also store that it is no longer dirty in the cache, but this is just an optimization
            if (debug) $display("Dirty line: %08x", {resp.tag, index, 6'h0});
            lineReqQ.enq(BusReq {
                byte_strobe: 4'hF,
                line_en: 1,
                addr: {resp.tag, index, 4'h0},
                data: resp.data
            });
        end
    endrule

    // TODO really scuffed state machine logic using the counter to detect when we are done flushing through
    // just add more states
    rule flushThroughCache if (state == WaitCAUResp && doFlush.read() && !(unpack(flushCounter[5]) && unpack(flushCounter[0])));
        // finished flushing cache
        if (unpack(flushCounter[5])) begin
            // send a read request to an arbitrary address, say 0 so we get something back from the bus
            // once we know it's seen everything else we wrote
            lineReqQ.enq(BusReq {
                byte_strobe: 4'h0,
                line_en: 1,
                addr: (32'h00000800)[31:2],
                data: ?
            });
        end else begin
            let valid <- cau.lookup(flushCounter[4:0]);
            if (valid) begin 
                if (debug) $display("Flush %02x", flushCounter[5:0]);
                flushIndexQ.enq(flushCounter[4:0]);
            end 
        end
        flushCounter <= flushCounter + 1;
    endrule

    // lol
    rule startPassthrough if (state == WaitCAUResp && doPassthrough && !doFlush.read() && !doInvalidate.read());
        let currReq = currReqQ.first(); currReqQ.deq();
        lineReqQ.enq(BusReq {
            byte_strobe: currReq.req.word_byte,
            line_en: 0,
            addr: currReq.req.addr,
            data: {480'h0, currReq.req.data}
        });
        doPassthrough <= False;
        // dont need to wait for response on write
        state <= (currReq.req.word_byte == 0) ? BusPassthrough : WaitCAUResp;
    endrule

    rule handleBusPassthrough if (state == BusPassthrough);
        let lineResp = lineRespQ.first; lineRespQ.deq();
        Vector#(16, Word) lineRespWords = unpack(lineResp);
        hitQ.enq(lineRespWords[15]);
        state <= WaitCAUResp;
    endrule

    rule handleCAUResponse if (state == WaitCAUResp && !doFlush.read() && !doInvalidate.read() && !doPassthrough);
        let currReq = currReqQ.first();
        let pa = parseL1Address(currReq.req.addr);
        if (currReq.hit) begin 
            if (currReq.req.word_byte == 0) begin
                let x <- cau.resp();
                Vector#(16, Word) line = unpack(x.data);
                Word word = line[pa.offset];
                if (debug) begin 
                    $display("(cyc=%d) [Load Hit 2] Tag=%d Index=%d Offset=%d Data=%d", cyc, pa.tag, pa.index, pa.offset, word);
                end
                hitQ.enq(word);
            end 
            // If it's not a load, word value is a dont care, we just do this so CPU gets result
            currReqQ.deq();
        end else begin
            let x <- cau.resp();
            if (x.isDirty) begin
                // dirty line, need to evict and write to LLC
                lineReqQ.enq(BusReq {
                    byte_strobe: 4'hF,
                    line_en: 1,
                    addr: {x.tag, pa.index, 4'h0},
                    data: x.data
                });
                state <= SendReq;
                if (debug) begin 
                    $display("(cyc=%d) [Dirty Miss] Tag=%d Index=%d Offset=%d (Replace Tag)=%d", cyc, pa.tag, pa.index, pa.offset, x.tag);
                end
            end else begin
                lineReqQ.enq(BusReq {
                    byte_strobe: 4'h0,
                    line_en: 1,
                    // make sure we ask for the real line
                    addr: {currReq.req.addr[29:4], 4'h0},
                    data: ?
                });
                if (debug) begin 
                    $display("(cyc=%d) [Clean Miss] Tag=%d Index=%d Offset=%d", cyc, pa.tag, pa.index, pa.offset);
                end
                state <= WaitDramResp;
            end
        end
    endrule

    rule handleWriteback if (state == SendReq);
        let currReq = currReqQ.first();
        let pa = parseL1Address(currReq.req.addr);
        if (debug) begin
            $display("(cyc=%d) [WB->DRAM]", cyc);
        end
        if (currReq.hit) begin
            $display("Sanity check failed, handling writeback for a hit request?");
        end
        lineReqQ.enq(BusReq {
            byte_strobe: 4'h0,
            addr: {currReq.req.addr[29:4], 4'h0},
            line_en: 1,
            data: ?
        });
        state <= WaitDramResp;
    endrule

    rule handleDramResponse if (state == WaitDramResp);
        // Grab response from memory and the request we have been handling.
        let line = lineRespQ.first(); lineRespQ.deq();
        let currReq = currReqQ.first(); currReqQ.deq();
        let pa = parseL1Address(currReq.req.addr);

        if (debug) begin
            $display("(cyc=%d) [DRAM->CACHE]", cyc);
        end

        Vector#(16, Word) line_vec = unpack(line);
        let word = line_vec[pa.offset];
        let wb = currReq.req.word_byte;
        let dirty = False;
        // Always enqueue the word. If it's a store, we don't
        // actually care about the result, just that we got one.
        if (currReq.req.word_byte != 0) begin
            // If it's a store we have to update the line with the 
            // appropriate mask before we write it back.

            // Repeat each bit of wb 8 times to form the mask
            // this is easy to do in verilog so it is probably easy to do
            // here as well, but this is what I came up with
            Vector#(8, Bit#(1)) wb0 = replicate(wb[0]);
            Vector#(8, Bit#(1)) wb1 = replicate(wb[1]);
            Vector#(8, Bit#(1)) wb2 = replicate(wb[2]);
            Vector#(8, Bit#(1)) wb3 = replicate(wb[3]);
            let mask = {pack(wb3), pack(wb2), pack(wb1), pack(wb0)};
            line_vec[pa.offset] = (word & ~mask) | (currReq.req.data & mask);
            dirty = True;
        end else begin
            hitQ.enq(word);
        end
        // Update line in CAU
        cau.update(pa.index, pack(line_vec), pa.tag, dirty);
        state <= WaitCAUResp;
    endrule

    method Action putFromProc(DMemReq e, Bool passthrough) if (!doFlush.read() && !doPassthrough);
        if (passthrough) begin
            currReqQ.enq(HitMissDMemReq{req: e, hit: False});
            doPassthrough <= True;
        end else begin
            let hitMissResult <- cau.req(e);
            let pa = parseL1Address(e.addr);
            case (hitMissResult)
                LdHit: begin
                    if (debug) $display("(cyc=%d) [Load Hit  ] Tag=%d Index=%d Offset=%d", cyc, pa.tag, pa.index, pa.offset);
                    currReqQ.enq(HitMissDMemReq{req: e, hit: True});
                end
                // StHit don't need to do anything
                StHit: begin
                    if (debug) $display("(cyc=%d) [St Hit    ] Tag=%d Index=%d Offset=%d WB=%d Data=%d", cyc, pa.tag, pa.index, pa.offset, e.word_byte, e.data);
                    currReqQ.enq(HitMissDMemReq{req: e, hit: True});
                end
                Miss: begin
                    if (debug) begin 
                        if (e.word_byte == 0) $display("(cyc=%d) [Load Miss ] Tag=%d Index=%d Offset=%d", cyc, pa.tag, pa.index, pa.offset);
                        else $display("(cyc=%d) [St Miss   ] Tag=%d Index=%d Offset=%d WB=%d Data=%d", cyc, pa.tag, pa.index, pa.offset, e.word_byte, e.data);
                    end
                    currReqQ.enq(HitMissDMemReq{req: e, hit: False});
                end
            endcase
        end
    endmethod

    method Action invalidateLines();
        doInvalidate.set();
    endmethod

    method Action putFlushRequest();
        doFlush.set();
    endmethod

    method Action blockTillFlushDone() if (state == WaitCAUResp && doFlush.read() && (unpack(flushCounter[5]) && unpack(flushCounter[0])));
        lineRespQ.deq();
        flushCounter <= 0;
        doFlush.reset();
    endmethod
        
    method ActionValue#(Word) getToProc();
        hitQ.deq(); return hitQ.first();
    endmethod
        
    method ActionValue#(BusReq) getToMem();
        lineReqQ.deq(); return lineReqQ.first();
    endmethod
        
    method Action putFromMem(BusResp e);
        lineRespQ.enq(e);
    endmethod
endmodule
