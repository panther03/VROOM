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
import ControlRegs::*;

interface CommitIntf;
endinterface

module mkCommit #(
    VROOMFsm fsm,
    KonataIntf konataHelper,
    FIFO#(E2W) e2w,
    function Action freeRegister(Bit#(5) rd),
    function Action writeRf(Bit#(5) rd, Bit#(32) val),
    function Action putSyncException(ExceptionRequest er),
    function Epoch archEpoch(),
    function Action redirectArchState(ControlRedirection cr),
    MemUnit mu,
    BranchUnit bu,
    Alu alu,
    ControlRegs crs
)(CommitIntf);

    rule commit if (fsm.runOk());
        let e2wResult = e2w.first; e2w.deq();
        Bool earlyPoison = !stillValid(e2wResult.sr);
        // RS3 is used exclusively for stores so this is a shortcut
        // TODO: Stop being a fuckhead and add another field
        Bool isStore = isValid(e2wResult.di.rs3);

        ExcResult ru = ExcResult {
            data: ?,
            ecause: tagged Invalid
        };
        Maybe#(ControlRedirection) cr = tagged Invalid;
        if (!earlyPoison) begin
            case (e2wResult.di.fu) 
                LoadStore: ru <- mu.deq();
                Control: begin ru <- bu.deq(); cr <- bu.getCR(); end
                ALU: ru <- alu.deq();
            endcase
        end

        // Indicates
        // 1. The correct next PC after this instruction
        // 2. The epoch after this instruction.
        let nextArchState = ControlRedirection {
            pc: e2wResult.fi.npc,
            epoch: e2wResult.fi.epoch
        };
        if (isValid(cr)) begin
            nextArchState = fromMaybe(?, cr);
        end

        Maybe#(Bit#(4)) earlyEcause = case (e2wResult.sr)
            MisalignFetch: tagged Valid(ecause_UNA);
            DecodeInvalid: tagged Valid(ecause_INV);
            PrivilegeFail: tagged Valid(ecause_PRV);
            default: tagged Invalid;
        endcase;
        
        Bool latePoison = e2wResult.fi.epoch != archEpoch();
        Bool poisoned = earlyPoison || latePoison; 

        Maybe#(Bit#(4)) finalEcause;
        if (!poisoned && isValid(ru.ecause)) begin
            finalEcause = ru.ecause;
        end else begin
            finalEcause = earlyEcause;
        end

        let commitOk = !poisoned && !isValid(finalEcause);

        let rd = fromMaybe(?, e2wResult.di.rd);
        let fields = getInstFields(e2wResult.di.inst);
        if (isValid(e2wResult.di.rd)) begin
            if (commitOk) begin
                writeRf(rd, ru.data);
            end
            freeRegister(rd);
        end else if (e2wResult.di.priv && fields.funct4 == fn4_MTCR) begin
            // handling write to control registers (MTCR)
            // needs to be done here instead of in execute to preserve precise state
            // otherwise need to also flush the pipleine *before* mtcr
            if (commitOk) crs.writeCR(fields.regC, ru.data); 
        end else if (isStore) begin
            if (commitOk) mu.commitStore();
        end
        
        if (isValid(finalEcause)) begin
            // exception handling, TODO
            $fdisplay(stderr, "Instruction exception due to ECAUSE=%04x", fromMaybe(?, finalEcause));
            konataHelper.stageInst(e2wResult.kid, "Ce");
            konataHelper.squashInst(e2wResult.kid);
            putSyncException(ExceptionRequest {
                ecause: fromMaybe(?, finalEcause)
            });
            fsm.trs_EnterSyncException();
        end else if (e2wResult.sr == Poisoned || latePoison) begin
            konataHelper.stageInst(e2wResult.kid, "Cp");
            konataHelper.squashInst(e2wResult.kid);
        end

        if (commitOk) begin
            redirectArchState(nextArchState);
            if (e2wResult.di.serial) fsm.trs_RestartDecode();
            konataHelper.stageInst(e2wResult.kid, "C");
            konataHelper.commitInst(e2wResult.kid);
            if (isValid(e2wResult.di.rd)) begin
                konataHelper.labelInstLeft(e2wResult.kid, $format(" | RF [%d]=%08x", rd, ru.data));
            end
        end
    endrule
endmodule