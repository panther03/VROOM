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
import KonataHelper::*;

interface DecodeIntf;
    method Action freeRegister(Bit#(5) rd);
    method Action writeRf(Bit#(5) rd, Bit#(32) val);
endinterface

module mkDecode #(
    VROOMFsm fsm,
    KonataIntf konataHelper,
    FIFO#(F2D) f2ws,
    FIFO#(D2E) d2e,
    FIFO#(IMemResp) fromImem,
    function ModeByte getCurrMode()
)(DecodeIntf);
    FIFO#(F2D) ws2d <- mkFIFO;
    FIFO#(Word) decodeWord <- mkFIFO;
    RWire#(Bit#(5)) freeReg <- mkRWire();
    RWire#(Bit#(5)) markReg <- mkRWire();
    Reg#(IMemResp) fetchedLine <- mkReg(128'h0);

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

    rule wordSelect if (fsm.getState() == Steady);
        let f2wsResult = f2ws.first(); f2ws.deq();
        IMemResp line = fetchedLine;
        if (f2wsResult.needsNewFetch) begin
            line = fromImem.first(); fromImem.deq();
        end
        Vector#(4, Word) lineVec = unpack(line);
        let sel = (f2wsResult.fi.pc[31:30] == 2'b11) ? 0 : f2wsResult.fi.pc[3:2];
        ws2d.enq(f2wsResult);

        konataHelper.stageInst(f2wsResult.kid, "WS");
        konataHelper.labelInstLeft(f2wsResult.kid, $format(" | %08x", lineVec[sel]));
        decodeWord.enq(lineVec[sel]);
    endrule

    rule decode if (fsm.getState() == Steady);
        // TODO if there is an exception from fetch, catch it here and don't do an actual decode
        let ws2dResult = ws2d.first();
        let inst = decodeWord.first();        
        let dinst = decodeInst(inst);

        Bool t = getCurrMode().t;

        Bit#(5) rs1 = fromMaybe(5'h0, dinst.rs1);
        let rs1_rdy = (!isValid(dinst.rs1) || (!t && rs1 == 5'h0) || sc.search(rs1));

        Bit#(5) rs2 = fromMaybe(5'h0, dinst.rs2);
        let rs2_rdy = (!isValid(dinst.rs2) || (!t && rs2 == 5'h0) || sc.search(rs2));

        Bit#(5) rs3 = fromMaybe(5'h0, dinst.rs3);
        let rs3_rdy = (!isValid(dinst.rs3) || (!t && rs3 == 5'h0) || sc.search(rs3));


        if (!dinst.legal || (rs1_rdy && rs2_rdy && rs3_rdy)) begin
            ws2d.deq();
            decodeWord.deq();

            let rv1 = (dinst.legal && (t || rs1 != 5'h0)) ? rf.sub(rs1) : 32'h0;
            let rv2 = (dinst.legal && (t || rs2 != 5'h0)) ? rf.sub(rs2) : 32'h0;
            let rv3 = (dinst.legal && (t || rs3 != 5'h0)) ? rf.sub(rs3) : 32'h0;

            let rd = fromMaybe(5'h0, dinst.rd);
            if (dinst.legal && isValid(dinst.rd) && rd != 5'h0) begin
                markReg.wset(rd);
            end

            konataHelper.stageInst(ws2dResult.kid, "D");
            // TODO more informative debugging info here
            konataHelper.labelInstLeft(ws2dResult.kid, $format(" | WR = %d; RS=[%08x,%08x,%08x]", rd, rv1, rv2, rv3));

            d2e.enq(D2E {
                fi: ws2dResult.fi,
                di: dinst,
                ops: Operands {
                    rv1: rv1,
                    rv2: rv2,
                    rv3: rv3
                },
                sr: dinst.legal ? None : DecodeInvalid,
                kid: ws2dResult.kid
            });
        end else begin
            konataHelper.stageInst(ws2dResult.kid, "Ds");
        end
    endrule

    method Action freeRegister(Bit#(5) rd);
        freeReg.wset(rd);
    endmethod

    method Action writeRf(Bit#(5) rd, Bit#(32) val);
        rf.upd(rd, val);
    endmethod
endmodule