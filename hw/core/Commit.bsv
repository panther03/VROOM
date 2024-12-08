import VROOMTypes::*;
import VROOMFsm::*;
import Scoreboard::*;
import XRUtil::*;
import RegFile::*;
import FIFO::*;
import KonataHelper::*;

import MemUnit::*;
import BranchUnit::*;
import Alu::*;

interface CommitIntf;
endinterface

module mkCommit #(
    VROOMFsm fsm,
    KonataIntf konataHelper,
    FIFO#(E2W) e2w,
    function Action freeRegister(Bit#(5) rd),
    function Action writeRf(Bit#(5) rd, Bit#(32) val),
    MemUnit mu,
    BranchUnit bu,
    Alu alu
)(CommitIntf);

    // TODO add state guards
    rule commit if (fsm.getState() == Steady);
        let e2wResult = e2w.first; e2w.deq();
        Bool earlyPoison = !stillValid(e2wResult.sr);

        ExcResult ru = ?;
        if (!earlyPoison) begin
            case (e2wResult.di.fu) 
                LoadStore: ru <- mu.deq();
                Control: ru <- bu.deq();
                ALU: ru <- alu.deq();
            endcase
        end

        Maybe#(Bit#(4)) earlyEcause = case (e2wResult.sr)
            MisalignFetch: tagged Valid(ecause_UNA);
            DecodeInvalid: tagged Valid(ecause_INV);
            default: tagged Invalid;
        endcase;
        
        Maybe#(Bit#(4)) finalEcause;
        if (!earlyPoison && isValid(ru.ecause)) begin
            finalEcause = ru.ecause;
        end else begin
            finalEcause = earlyEcause;
        end

        let commitOk = !earlyPoison && !isValid(finalEcause);

        let rd = fromMaybe(?, e2wResult.di.rd);
        if (isValid(e2wResult.di.rd)) begin
            if (commitOk) begin
                writeRf(rd, ru.data);
            end
            freeRegister(rd);
        end else if (isValid(e2wResult.di.rs3)) begin // store instruction
            // RS3 is used exclusively for stores so this is a shortcut
            // TODO: Stop being a fuckhead and add another field
            if (commitOk) mu.commitStore();
        end
        
        if (isValid(finalEcause)) begin
            // exception handling, TODO
            konataHelper.squashInst(e2wResult.kid);
        end

        if (commitOk) begin
            konataHelper.stageInst(e2wResult.kid, "W");
            konataHelper.commitInst(e2wResult.kid);
            if (isValid(e2wResult.di.rd)) begin
                konataHelper.labelInstLeft(e2wResult.kid, $format(" | RF [%d]=%08x", rd, ru.data));
            end
        end
    endrule
endmodule