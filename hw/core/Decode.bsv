import FIFO::*;
import SpecialFIFOs::*;
import Vector::*;

import ControlRegs::*;
import MemTypes::*;
import XRUtil::*;
import VROOMTypes::*;
import VROOMFsm::*;
import Scoreboard::*;
import RegFile::*;

interface DecodeIntf;
    method Action freeRegister(Bit#(5) rd);
    method Action writeRf(Bit#(5) rd, Bit#(32) val);
endinterface

module mkDecode #(
    VROOMFsm fsm,
    FIFO#(F2D) f2d,
    FIFO#(D2E) d2e,
    FIFO#(IMemResp) fromImem,
    function ModeByte getCurrMode()
)(DecodeIntf);
    RWire#(Bit#(5)) freeReg <- mkRWire();
    RWire#(Bit#(5)) markReg <- mkRWire();

    Scoreboard sc <- mkScoreboardBoolFlags;
    VROOMRf rf <- mkRegFile(5'h0, 5'd31);

    rule updateScoreboard;
        Maybe#(Bit#(5)) freeRegM = freeReg.wget();
        Maybe#(Bit#(5)) markRegM = markReg.wget();
        if (isValid(freeRegM)) begin
            sc.remove(fromMaybe(?, freeRegM));
        end
        if (isValid(markRegM)) begin
            sc.insert(fromMaybe(?, markRegM));
        end
    endrule

    rule decode if (fsm.getState() == Steady);
        // TODO if there is an exception from fetch, catch it here and don't do an actual decode
        let f2dResult = f2d.first();
        let imemResp = fromImem.first();        
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
            f2d.deq();
            fromImem.deq();

            let rv1 = (t || rs1 != 5'h0) ? rf.sub(rs1) : 32'h0;
            let rv2 = (t || rs2 != 5'h0) ? rf.sub(rs2) : 32'h0;
            let rv3 = (t || rs3 != 5'h0) ? rf.sub(rs3) : 32'h0;

            let rd = fromMaybe(?, dinst.rd);
            if (isValid(dinst.rd) && rd != 5'h0) begin
                markReg.wset(rd);
            end

            d2e.enq(D2E {
                fi: f2dResult.fi,
                di: dinst,
                ops: Operands {
                    rv1: rv1,
                    rv2: rv2,
                    rv3: rv3
                },
                sr: dinst.legal ? None : DecodeInvalid
            });
        end
    endrule

    method Action freeRegister(Bit#(5) rd);
        freeReg.wset(rd);
    endmethod

    method Action writeRf(Bit#(5) rd, Bit#(32) val);
        rf.upd(rd, val);
    endmethod
endmodule