// SINGLE CORE CACHE INTERFACE WITH NO PPP
import MainMem::*;
import MemTypes::*;
import Cache32::*;
import ICache::*;
import Cache512::*;
import FIFO::*;

typedef enum {I, D} L2ReqSource deriving (Eq, Bits, FShow);

interface CacheInterface;
    method Action sendReqData(CacheReq req);
    method ActionValue#(Word) getRespData();
    method Action sendReqInstr(ICacheReq req);
    method ActionValue#(IWord) getRespInstr();
endinterface


module mkCacheInterface(CacheInterface);
    let verbose = True;
    MainMem mainMem <- mkMainMem(); 
    Cache512 cacheL2 <- mkCache;
    ICache cacheI <- mkICache;
    Cache32 cacheD <- mkCache32;
    FIFO#(L2ReqSource) l2ReqFifo <- mkFIFO;

(* descending_urgency = "connectCacheL1IL2, connectCacheL1DL2" *)
    rule connectCacheL1IL2;
        let lineReq <- cacheI.getToMem();
        //$display("Putting L1I req: ", fshow(lineReq));
        //assert(lineReq.write == 1'b0);
        l2ReqFifo.enq(I);
        cacheL2.putFromProc(lineReq);
    endrule

    rule connectCacheL1DL2;
        let lineReq <- cacheD.getToMem();
        // $display("Putting L1D req: ", fshow(lineReq));
        if (lineReq.write == 1'b0) begin
            l2ReqFifo.enq(D);
        end
        cacheL2.putFromProc(lineReq);
    endrule

    rule connectL2L1DICache;
        let resp <- cacheL2.getToProc();
        l2ReqFifo.deq(); let req = l2ReqFifo.first();
        if (req == D) cacheD.putFromMem(resp);
        else cacheI.putFromMem(resp);
    endrule

    rule connectCacheDram;
        let lineReq <- cacheL2.getToMem();
        //$display("Putting L2 req: ", fshow(lineReq));
        mainMem.put(lineReq);
    endrule

    rule connectDramCache;
        let resp <- mainMem.get;
        cacheL2.putFromMem(resp);
    endrule

    method Action sendReqData(CacheReq req);
        // $display("Putting req: ", fshow(req));
        cacheD.putFromProc(req);
    endmethod

    method ActionValue#(Word) getRespData();
        let word <- cacheD.getToProc();
        return word;
    endmethod

    method Action sendReqInstr(ICacheReq req);
        cacheI.putFromProc(req);
    endmethod

    method ActionValue#(IWord) getRespInstr();
        let word <- cacheI.getToProc();
        return word;
    endmethod
endmodule
