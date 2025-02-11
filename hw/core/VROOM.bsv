`include "BuildDefs.bsv"
`include "Logging.bsv"

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import RegFile::*;
import ConfigReg::*;
import Vector::*;
import KonataHelper::*;
import Printf::*;
import Ehr::*;
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
import Exceptions::*;
import MemUnit::*;
import MulDivUnit::*;
import SrReg::*;

import Cache32::*;
import ICache::*;


interface VROOMIfc;
    method ActionValue#(BusReq) getBusReq();
    method Action putBusResp(BusResp r);
    (* always_ready, always_enabled *)
    method Action putIrq((* port = "irq" *)Bool line);
    method Action putBusError((* port = "busError" *)BusError err);
endinterface
/////////////////////
// Implementation //
///////////////////
typedef enum {L1I, L1D} BusAccOrigin deriving (FShow, Bits, Eq);

typedef struct {
    BusAccOrigin origin;
    Bit#(4) addr_low;
} BusBusiness deriving (Bits, FShow);

typedef struct {
    Bit#(32) badAddr;
} BusError deriving (Bits, FShow);

(* synthesize *)
module mkVROOM (VROOMIfc);
    /////////////////
    // Caches/TLB //
    ///////////////
    ICache iCache <- mkICache;
    Cache32 dCache <- mkCache32;

    // crappy hack
    SrReg globalFlushStall <- mkSrReg(True);

    ///////////////////////
    // Global CPU state //
    /////////////////////
    VROOMFsm fsm <- mkVROOMFsm();
    ControlRegs crs <- mkCRS(
        iCache.invalidateLines(),
        dCache.invalidateLines()
    );

    // Architectural fetch state (next pc, epoch)
    // This is where we resume to when an exception happens.
    Ehr#(2, Bit#(32)) npc <- mkEhr(32'hFFFE1000);
    Ehr#(2, Epoch) epoch <- mkEhr(2'h0);

    Wire#(Bool) irq <- mkWire;
    FIFOF#(BusError) busError <- mkFIFOF;

    Reg#(Bit#(32)) cyc <- mkReg(32'h0);

    rule fuck;
        cyc <= cyc + 1;
    endrule

    ////////////////////////////////
    // Stages + Functional Units //
    //////////////////////////////
    FetchIntf fetch;
    DecodeIntf decode;
    ExecuteIntf execute;
    CommitIntf commit;
    ExceptionsIntf exceptions;

    Alu alu;
    BranchUnit bu;
    MemUnit mu;
    MulDivUnit mdu;


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

    FIFO#(BusBusiness) busTracker <- mkPipelineFIFO;
    FIFO#(IMemResp) fromImem <- mkBypassFIFO;
    FIFO#(DMemResp) fromDmem <- mkBypassFIFO;

    FIFO#(DMemReq) dmemReqs <- mkFIFO;


    /////////////////////
    // Konata/Logging //
    ///////////////////
    KonataIntf konataHelper <- mkKonata;


    ////////////////////
    // General rules //
    //////////////////
    rule init if (fsm.getState() == Starting);
        konataHelper.init("konata.log");
        fsm.trs_Start();
    endrule

    ///////////////////////////////////
    // Architectural state handling //
    /////////////////////////////////
   
    function Epoch archEpoch();
        return epoch[0];
    endfunction

    function Bit#(32) archNextPc();
        return npc[0];
    endfunction

    function Action redirectArchState(ControlRedirection cr);
    action
        npc[1] <= cr.pc;
        epoch[1] <= cr.epoch;
    endaction
    endfunction

    ///////////////////////////////
    // Memory/Cache Interfacing //
    /////////////////////////////

    function Action startDCacheFlush();
    action
        dCache.putFlushRequest();
        globalFlushStall.set();
    endaction
    endfunction 

    function Action finishDCacheFlush();
    action
        dCache.blockTillFlushDone();
        globalFlushStall.reset();
    endaction
    endfunction

    // Interface seen by CPU
    // TODO: these should probably be their own rules.
    // This way, we can make the scheduling of different 
    // bus requestors explicit using annotations.
    // Right now, the performance (i.e. prioritizing data over fetch) is at
    // the whim of BSC.

    function Action putIMemReq(IMemReq r);
    action
        // 2nd arg: Not using paging and in upper 3GB
        iCache.putFromProc(r, !crs.getCurrMode().m && r.addr[29:28] == 2'b11);
    endaction
    endfunction

    rule handleDMemReqs;
        // 2nd arg: Not using paging and in upper 3GB
        let r = dmemReqs.first; dmemReqs.deq();
        dCache.putFromProc(r, !crs.getCurrMode().m && r.addr[29:28] == 2'b11);
    endrule

    function Action putDMemReq(DMemReq r);
    action
        dmemReqs.enq(r);
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
    rule handleICacheRequest if (!globalFlushStall.read());
        let cacheReq <- iCache.getToMem();
        busTracker.enq(BusBusiness {
            origin: L1I,
            addr_low: ?
        });
        toBus.enq(cacheReq);
    endrule

    rule handleDCacheRequest;
        let cacheReq <- dCache.getToMem();
        if (cacheReq.byte_strobe == 0) begin
            busTracker.enq(BusBusiness {
                origin: L1D,
                addr_low: ?
            });
        end
        toBus.enq(cacheReq);
    endrule

    /////////////////////////
    // Connect everything //
    ///////////////////////
   
    fetch <- mkFetch(
        fsm,
        konataHelper,
        f2d,
        putIMemReq,
        globalFlushStall
    );
    alu <- mkAlu(
        crs
    );
    bu <- mkBranchUnit(
        crs,
        fetch.redirect,
        fetch.currentEpoch,
        archEpoch
    );
    mu <- mkMemUnit(
        fsm,
        konataHelper,
        putDMemReq,
        getDMemResp,
        startDCacheFlush,
        finishDCacheFlush
    );
    mdu <- mkMulDivUnit();
    decode <- mkDecode(
        fsm,
        konataHelper,
        f2d,
        d2e,
        fromImem,
        crs.getCurrMode
    );
    execute <- mkExecute(
        fsm,
        konataHelper,
        d2e,
        e2w,
        fetch.currentEpoch,
        mu,
        bu,
        alu,
        mdu,
        crs
    );
    exceptions <- mkExceptions(
        fsm,
        konataHelper,
        crs,
        archNextPc,
        fetch.currentEpoch,
        fetch.redirect,
        redirectArchState
    );
    commit <- mkCommit(
        fsm,
        konataHelper,
        e2w,
        decode.freeRegister,
        decode.writeRf,
        exceptions.putSyncException,
        archEpoch,
        redirectArchState,
        mu,
        bu,
        alu,
        mdu,
        crs
    );
   

    rule handleAsyncException if (fsm.runOk());
        if (busError.notEmpty) begin
            $display("exception time @ %d", cyc);
            let err = busError.first; busError.deq();
            fsm.trs_EnterASyncException();
            exceptions.putASyncException(tagged Valid(err.badAddr));
        end else if (irq) begin
            fsm.trs_EnterASyncException();
            exceptions.putASyncException(tagged Invalid);
        end
    endrule
    
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

    method Action putIrq(Bool line);
        irq <= line;
    endmethod

    method Action putBusError(BusError err);
        busError.enq(err);
    endmethod
endmodule