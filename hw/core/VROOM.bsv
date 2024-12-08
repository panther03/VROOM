`define KONATA_ENABLE
//`define DEBUG_ENABLE
`include "Logging.bsv"

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import RegFile::*;
import ConfigReg::*;
import RVUtil::*;
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
import ControlRegs::*;
import Fetch::*;

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
module mkVROOM #(Bool ctr_enable) (VROOMIfc);
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

    ////////////////
    // CPU state //
    //////////////
    Ehr#(2, Bit#(32)) pc <- mkEhr(32'h0);
    Ehr#(2, Bit#(1)) epoch <- mkEhr(1'h0);

    RegFile#(Bit#(5), Bit#(32)) rf <- mkRegFile(5'h0, 5'd31);
    Scoreboard sc <- mkScoreboardBoolFlags;
    ControlRegs crs <- mkCRS;

    Reg#(Bit#(32)) insn_count <- mkReg(0);
    Reg#(Bool) started <- mkReg(False); 

    ///////////////////////
    // Functional Units //
    /////////////////////
    //let memUnitInput = (interface MemUnitInput;
    //    interface toDmem = toDmem;
    //    interface fromDmem = fromDmem;
    //    interface toMMIO = toMMIO;
    //    interface fromMMIO = fromMMIO;
    //endinterface);
    //MemUnit mu <- mkMemUnit(memUnitInput, True);
    //let branchUnitInput = (interface BranchUnitInput;
    //    interface extPC = pc; interface extEpoch = epoch; 
    //endinterface);
    //BranchUnit bu <- mkBranchUnit(branchUnitInput);
    //Alu alu1 <- mkAlu();
    //Alu alu2 <- mkAlu();

    //////////////////////
    // Pipeline stages //
    ////////////////////

    


    ////////////
    // Rules //
    //////////
    //rule init if (offsetting);
    //    offsetting <= False;
    //    let req = IMem {byte_en: 0, addr: 0, data: ?};
    //    toImem.enq(req);
    //endrule
    
    ///////////////////////////////
    // Memory/Cache Interfacing //
    /////////////////////////////
    // Interface seen by CPU
    function Action putIMemReq(IMemReq r);
    action
        // Not using paging and in upper 3GB
        if (!crs.getCurrMode().m && r.addr[27:26] == 2'b11) begin
            toBus.enq(BusReq {
                byte_strobe: 4'hF,
                line_en: 1,
                addr: {r.addr, 2'h0}
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

    (* descending_urgency = "handleICacheRequest, handleDCacheREquest" *)
    rule handleICacheRequest;
        let cacheReq <- iCache.getToMem();
        toBus.enq(cacheReq);
    endrule

    rule handleDCacheRequest;
        let cacheReq <- dCache.getToMem();
        toBus.enq(cacheReq);
    endrule

    FetchIntf fetch <- mkFetch(
        started,
        putIMemReq,
        pc,
        epoch
    );

    method ActionValue#(BusReq) getBusReq();
		toBus.deq();
		return toBus.first();
    endmethod

    method Action putBusResp(BusResp r);
		fromBus.enq(r);
    endmethod
endmodule