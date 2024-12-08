import FIFO::*;
import SpecialFIFOs::*;
import Vector::*;

import ControlRegs::*;
import MemTypes::*;
import XRUtil::*;
import VROOMTypes::*;
import Scoreboard::*;
import RegFile::*;

interface DecodeIntf;
    method Action enq(F2D f2d, IMemResp resp);
    method ActionValue#(D2E) deq;
endinterface

function Maybe#(Bit#(32)) rsToRv (Maybe#(Bit#(5)) rs, Bit#(32) rv);
    if (isValid(rs)) return tagged Valid(rv);
    else return tagged Invalid;
endfunction

module mkDecode #(
    function ModeByte getCurrMode(),
    Scoreboard sc,
    RegFile#(Bit#(5), Bit#(32)) rf
)(DecodeIntf);
    FIFO#(D2E) d2e <- mkFIFO;
    FIFO#(F2D) fetchInc <- mkBypassFIFO;
    FIFO#(IMemResp) imemInc <- mkBypassFIFO;

    rule decode;
        let f2dResult = fetchInc.first();
        let imemResp = imemInc.first();        
        Vector#(4, Word) imemRespVec = unpack(imemResp);
        let sel = f2dResult.fi.pc[3:2];
        let inst = imemRespVec[sel];
        let dinst = decodeInst(inst);

        Bool t = getCurrMode().t;

        Bit#(5) rs1 = fromMaybe(5'h0, dinst.rs1);
        let rs1_rdy = (!isValid(dinst.rs1) || (!t && rs1 == 5'h0) || sc.search(rs1));

        Bit#(5) rs2 = fromMaybe(5'h0, dinst.rs2);
        let rs2_rdy = (!isValid(dinst.rs2) || (!t && rs2 == 5'h0) || sc.search(rs2));

        Bit#(5) rs3 = fromMaybe(5'h0, dinst.rs3);
        let rs3_rdy = (!isValid(dinst.rs3) || (!t && rs3 == 5'h0) || sc.search(rs3));


        if (!dinst.legal || (rs1_rdy && rs2_rdy && rs3_rdy)) begin
            fetchInc.deq();
            imemInc.deq();

            let rv1 = 32'h0;
            let rv2 = 32'h0;
            let rv3 = 32'h0;
            if (t || rs1 != 5'h0) begin 
                sc.insert(rs1);
                rv1 = rf.sub(rs1);
            end
            if (t || rs2 != 5'h0) begin 
                sc.insert(rs2);
                rv2 = rf.sub(rs2);
            end
            if (t || rs3 != 5'h0) begin 
                sc.insert(rs3);
                rv3 = rf.sub(rs3);
            end

            d2e.enq(D2E {
                fi: f2dResult.fi,
                di: dinst,
                ops: Operands {
                    rv1: rsToRv(dinst.rs1, rv1),
                    rv2: rsToRv(dinst.rs2, rv2),
                    rv3: rsToRv(dinst.rs3, rv3)
                }
            });
        end
    endrule
        
    method Action enq(F2D f2d, IMemResp resp);
        fetchInc.enq(f2d);
        imemInc.enq(resp);
    endmethod

    method ActionValue#(D2E) deq;
        d2e.deq(); return d2e.first();
    endmethod

endmodule