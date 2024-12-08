`define KONATA_ENABLE
//`define DEBUG_ENABLE
`include "Logging.bsv"

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import RegFile::*;
import ConfigReg::*;
import Vector::*;
`ifdef KONATA_ENABLE
import KonataHelper::*;
`endif
import Printf::*;
import Ehr::*;
//import BranchUnit::*;
//import Alu::*;
//import MemUnit::*;
import MemTypes::*;
import RegFile::*;
import Scoreboard::*;
import VROOMTypes::*;
import VROOMFsm::*;
import ControlRegs::*;
import Fetch::*;
import Decode::*; 
import Execute::*; 
import Commit::*; 
import Alu::*;
import BranchUnit::*;
import MemUnit::*;

import Cache32::*;
import ICache::*;


interface VROOMIfc;
    method ActionValue#(BusReq) getBusReq();
    method Action putBusResp(BusResp r);
endinterface

/////////////////////
// Implementation //
///////////////////
typedef enum {L1I, L1D, IUNC, DUNC} BusAccOrigin deriving (Bits, Eq);

typedef struct {
    BusAccOrigin origin;
    Bit#(4) addr_low;
} BusBusiness deriving (Bits);

(* synthesize *)
module mkVROOM (VROOMIfc);
    ///////////////////////
    // Global CPU state //
    /////////////////////
    VROOMFsm fsm <- mkVROOMFsm();
    ControlRegs crs <- mkCRS;


    ////////////////////////////////
    // Stages + Functional Units //
    //////////////////////////////
    FetchIntf fetch;
    DecodeIntf decode;
    ExecuteIntf execute;
    CommitIntf commit;

    Alu alu;
    BranchUnit bu;
    MemUnit mu;


    //////////////////
    // Stage FIFOs //
    ////////////////
    FIFO#(F2D) f2d <- mkFIFO;
    FIFO#(D2E) d2e <- mkFIFO;
    FIFO#(E2W) e2w <- mkSizedFIFO(4);

    
    /////////////////////////
    // Interface with bus //
    ///////////////////////
    FIFO#(BusReq) toBus <- mkFIFO;
    FIFO#(BusResp) fromBus <- mkFIFO;

    FIFO#(BusBusiness) busTracker <- mkFIFO;
    FIFO#(IMemResp) fromImem <- mkBypassFIFO;
    FIFO#(DMemResp) fromDmem <- mkBypassFIFO;


    /////////////////
    // Caches/TLB //
    ///////////////
    ICache iCache <- mkICache;
    Cache32 dCache <- mkCache32;


    ////////////////////
    // General rules //
    //////////////////
    rule init if (fsm.getState() == Starting);
        fsm.trs_Start();
    endrule
    

    ///////////////////////////////
    // Memory/Cache Interfacing //
    /////////////////////////////

    // Interface seen by CPU
    // TODO: these should probably be their own rules.
    // This way, we can make the scheduling of different 
    // bus requestors explicit using annotations.
    // Right now, the performance (i.e. prioritizing data over fetch) is at
    // the whim of BSC.
    
    function Action putIMemReq(IMemReq r);
    action
        // Not using paging and in upper 3GB
        if (!crs.getCurrMode().m && r.addr[27:26] == 2'b11) begin
            toBus.enq(BusReq {
                byte_strobe: 4'h0,
                line_en: 1,
                addr: {r.addr, 2'h0},
                data: ?
            });
            busTracker.enq(BusBusiness {
                origin: IUNC,
                addr_low: {r.addr[1:0], 2'b00}
            });
        end else begin
            iCache.putFromProc(r);
        end
    endaction
    endfunction

    function Action putDMemReq(DMemReq r);
    action
        // Not using paging and in upper 3GB
        if (!crs.getCurrMode().m && r.addr[29:28] == 2'b11) begin
            toBus.enq(BusReq {
                byte_strobe: r.word_byte,
                line_en: 0,
                addr: r.addr,
                data: {480'h0, r.data}
            });
            busTracker.enq(BusBusiness {
                origin: DUNC,
                addr_low: {r.addr[3:0]}
            });
        end else begin
            dCache.putFromProc(r);
        end
    endaction
    endfunction

    function ActionValue#(IMemResp) getIMemResp;
    actionvalue
        fromImem.deq();
        return fromImem.first;
    endactionvalue
    endfunction

    function ActionValue#(DMemResp) getDMemResp;
    actionvalue
        fromDmem.deq();
        return fromDmem.first;
    endactionvalue
    endfunction

    // Bus <-> Cache
    (* descending_urgency = "handleBusResp, handleICacheResponse, handleDCacheResponse" *)
    rule handleBusResp;
        fromBus.deq(); let busResp = fromBus.first;
        busTracker.deq(); let busBusiness = busTracker.first;
        case (busBusiness.origin)
            L1I: iCache.putFromMem(busResp);
            L1D: dCache.putFromMem(busResp);
            IUNC: begin
                Vector#(4, IMemResp) iMemResps = unpack(busResp);
                fromImem.enq(iMemResps[busBusiness.addr_low[3:2]]);
            end
            DUNC: begin
                Vector#(16, DMemResp) dMemResps = unpack(busResp);
                fromDmem.enq(dMemResps[busBusiness.addr_low[3:0]]);
            end
        endcase
    endrule

    rule handleICacheResponse;
        let cacheResp <- iCache.getToProc();
        fromImem.enq(cacheResp);
    endrule

    rule handleDCacheResponse;
        let cacheResp <- dCache.getToProc();
        fromDmem.enq(cacheResp);
    endrule

    (* descending_urgency = "handleICacheRequest, handleDCacheRequest" *)
    rule handleICacheRequest;
        let cacheReq <- iCache.getToMem();
        toBus.enq(cacheReq);
    endrule

    rule handleDCacheRequest;
        let cacheReq <- dCache.getToMem();
        toBus.enq(cacheReq);
    endrule

    /////////////////////////
    // Connect everything //
    ///////////////////////
   
    fetch <- mkFetch(
        fsm,
        f2d,
        putIMemReq
    );
    alu <- mkAlu(
        crs
    );
    bu <- mkBranchUnit(
        fetch.redirect,
        fetch.currentEpoch
    );
    mu <- mkMemUnit(
        putDMemReq,
        getDMemResp
    );
    decode <- mkDecode(
        fsm,
        f2d,
        d2e,
        fromImem,
        crs.getCurrMode
    );
    execute <- mkExecute(
        fsm,
        d2e,
        e2w,
        fetch.currentEpoch,
        mu,
        bu,
        alu,
        crs
    );
    commit <- mkCommit(
        fsm,
        e2w,
        decode.freeRegister,
        decode.writeRf,
        mu,
        bu,
        alu
    );

    //////////////////
    // Bus Methods //
    ////////////////

    method ActionValue#(BusReq) getBusReq();
		toBus.deq();
		return toBus.first();
    endmethod

    method Action putBusResp(BusResp r);
		fromBus.enq(r);
    endmethod
endmodule