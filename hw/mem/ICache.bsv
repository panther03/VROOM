// TODO: ICache on XR architecture is not writable - make adjustments accordingly

import BRAM::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Ehr::*;
import Vector::*;
import MemTypes::*;

Bool debug = False;

interface L1ICAU;
    method ActionValue#(HitMissType) req(IMemReq c);
    method ActionValue#(L1TaggedLine) resp;
    method Action update(L1LineIndex index, LineData data, L1LineTag tag, Bool dirty);
    method Action clearValid();
endinterface

module mkL1ICAU(L1ICAU); 
    Vector#(TExp#(5), Reg#(L1LineTag)) tagStore <- replicateM(mkReg(0));
    Reg#(Vector#(TExp#(5), Bool)) validStore <- mkReg(replicate(False));
    BRAM_Configure cfg = defaultValue();
    cfg.latency = 2;
    BRAM1Port#(Bit#(5), LineData) dataStore <- mkBRAM1Server(cfg);
    BRAM1Port#(Bit#(5), Bool) dirtyStore <- mkBRAM1Server(cfg);
    FIFO#(L1LineTag) tagFifo <- mkFIFO;
    
    method ActionValue#(HitMissType) req(IMemReq c);
        let pa = parseL1IAddress(c.addr[29:2]);
        let tag = tagStore[pa.index];
        let valid = validStore[pa.index];
        if (debug) $display("ind: %d, valid: ", pa.index, fshow(valid));
        let hit = tag == pa.tag && valid;
        if (hit) begin
            tagFifo.enq(tag);
            dataStore.portA.request.put(BRAMRequest{
                write: False,
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
        end else begin
            tagFifo.enq(tag);
            dirtyStore.portA.request.put(BRAMRequest{
                write: False,
                responseOnWrite: False,
                address: pa.index,
                datain: ?
            });
            dataStore.portA.request.put(BRAMRequest{
                write: False,
                responseOnWrite: False,
                address: pa.index,
                datain: ?
            });
            return Miss;
        end
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
        dataStore.portA.request.put(BRAMRequest{
            write: True,
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
    IMemReq req;
    Bool hit;
} HitMissCacheReq deriving (Eq, FShow, Bits, Bounded);

// Notice the asymmetry in this interface, as mentioned in lecture.
// The processor thinks in 32 bits, but the other side thinks in 512 bits.
interface ICache;
    method Action putFromProc(IMemReq e, Bool passthrough);
    method ActionValue#(IMemResp) getToProc();
    method ActionValue#(BusReq) getToMem();
    method Action putFromMem(BusResp e);
    method Action invalidateLines();
endinterface

(* synthesize *)
module mkICache(ICache);

    //L1ICAU cau <- mkL1ICAU();

    FIFO#(IMemResp) hitQ <- mkBypassFIFO;
    FIFO#(HitMissCacheReq) currReqQ <- mkPipelineFIFO;
    FIFO#(BusReq) lineReqQ <- mkFIFO;
    FIFO#(BusResp) lineRespQ <- mkFIFO;

    Reg#(Bool) doPassthrough <- mkReg(False);

    Reg#(CacheState) state <- mkReg(WaitCAUResp);
    Reg#(Bit#(32)) cyc <- mkReg(0);
    Reg#(Bool) doInvalidate <- mkReg(False);
    PulseWire setInvalidate <- mkPulseWire;
    PulseWire clearInvalidate <- mkPulseWire;

    rule updateInvalidate;
        if (setInvalidate) doInvalidate <= True;
        else if (clearInvalidate) doInvalidate <= False;
    endrule

    rule handleInvalidate if (state == WaitCAUResp && doInvalidate);
        //cau.clearValid();
        clearInvalidate.send();
    endrule

    rule cyc_count_debug if (debug);
        cyc <= cyc + 1;
    endrule

    // lol
    rule startPassthrough if (state == WaitCAUResp && doPassthrough && !doInvalidate);
        let currReq = currReqQ.first(); currReqQ.deq();
        lineReqQ.enq(BusReq {
            byte_strobe: 4'h0,
            line_en: 0,
            addr: currReq.req.addr,
            data: ?
        });
        doPassthrough <= False;
        state <= BusPassthrough;
    endrule

    rule handleBusPassthrough if (state == BusPassthrough);
        let lineResp = lineRespQ.first; lineRespQ.deq();
        // TODO: should propagate back to the core that there was an error
        // if a bus error happened here
        Vector#(16, Word) lineRespWords = unpack(lineResp.data);
        hitQ.enq({96'h0, lineRespWords[15]});
        state <= WaitCAUResp;
    endrule

    rule handleCAUResponse if (state == WaitCAUResp && !doInvalidate && !doPassthrough);
        let currReq = currReqQ.first();
        let pa = parseL1IAddress(currReq.req.addr[29:2]);
        if (currReq.hit) begin 
            IMemResp word = unpack(0);
            L1TaggedLine x = ?;
            //let x <- cau.resp();
            Vector#(4, IMemResp) line = unpack(x.data);
            word = line[pa.offset];
            if (debug) begin 
                $display("(cyc=%d) [Load Hit 2] Tag=%d Index=%d Offset=%d Data=%d", cyc, pa.tag, pa.index, pa.offset, word);
            end
            // If it's not a load, word value is a dont care, we just do this so CPU gets result
            currReqQ.deq();
            hitQ.enq(word);
        end else begin
            L1TaggedLine x = ?;
            //let x <- cau.resp();
            if (x.isDirty) begin
                // dirty line, need to evict and write to LLC
                lineReqQ.enq(BusReq {
                    byte_strobe: 4'hF,
                    addr: {x.tag, pa.index, 4'h0},
                    data: x.data,
                    line_en: 1'b1
                });
                state <= SendReq;
                if (debug) begin 
                    $display("(cyc=%d) [Dirty Miss] Tag=%d Index=%d Offset=%d (Replace Tag)=%d", cyc, pa.tag, pa.index, pa.offset, x.tag);
                end
            end else begin
                lineReqQ.enq(BusReq {
                    byte_strobe: 4'h0,
                    addr: {currReq.req.addr[29:4], 4'h0},
                    data: ?,
                    line_en: 1'b1
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
        let pa = parseL1IAddress(currReq.req.addr[29:2]);
        if (debug) begin
            $display("(cyc=%d) [WB->DRAM]", cyc);
        end
        if (currReq.hit) begin
            $display("Sanity check failed, handling writeback for a hit request?");
        end
        lineReqQ.enq(BusReq {
            byte_strobe: 4'h0,
            addr: {currReq.req.addr[29:4], 4'h0},
            data: ?,
            line_en: 1'b1
        });
        state <= WaitDramResp;
    endrule

    rule handleDramResponse if (state == WaitDramResp);
        // Grab response from memory and the request we have been handling.
        let line = lineRespQ.first(); lineRespQ.deq();
        let currReq = currReqQ.first(); currReqQ.deq();
        let pa = parseL1IAddress(currReq.req.addr[29:2]);

        if (debug) begin
            $display("(cyc=%d) [DRAM->CACHE]", cyc);
        end

        Vector#(4, IMemResp) line_vec = unpack(line.data);
        let word = line_vec[pa.offset];
        let dirty = False;
        // Always enqueue the word. If it's a store, we don't
        // actually care about the result, just that we got one.
        hitQ.enq(word);
        // Update line in CAU
        //if (!line.err) begin
        //    cau.update(pa.index, pack(line_vec), pa.tag, dirty);
        //end
        state <= WaitCAUResp;
    endrule

    method Action putFromProc(IMemReq e, Bool passthrough) if (!doPassthrough);
        if (True) begin
            currReqQ.enq(HitMissCacheReq{req: e, hit: False});
            doPassthrough <= True;
        end else begin
            HitMissType hitMissResult = ?;
            //let hitMissResult <- cau.req(e);
            let pa = parseL1IAddress(e.addr[29:2]);
            case (hitMissResult)
                LdHit: begin
                    if (debug) $display("(cyc=%d) [Load Hit  ] Tag=%d Index=%d Offset=%d", cyc, pa.tag, pa.index, pa.offset);
                    currReqQ.enq(HitMissCacheReq{req: e, hit: True});
                end
                // StHit don't need to do anything
                StHit: begin
                    if (debug) $display("(cyc=%d) [St Hit    ] Tag=%d Index=%d Offset=%d WB=%d", cyc, pa.tag, pa.index, pa.offset);
                    currReqQ.enq(HitMissCacheReq{req: e, hit: True});
                end
                Miss: begin
                    if (debug) begin 
                        $display("(cyc=%d) [Load Miss ] Tag=%d Index=%d Offset=%d", cyc, pa.tag, pa.index, pa.offset);
                    end
                    currReqQ.enq(HitMissCacheReq{req: e, hit: False});
                end
            endcase
            end
    endmethod

    method Action invalidateLines() if (!doInvalidate);
        setInvalidate.send();
    endmethod
        
    method ActionValue#(IMemResp) getToProc();
        hitQ.deq(); return hitQ.first();
    endmethod
        
    method ActionValue#(BusReq) getToMem();
        lineReqQ.deq(); return lineReqQ.first();
    endmethod
        
    method Action putFromMem(BusResp e);
        lineRespQ.enq(e);
    endmethod
endmodule
