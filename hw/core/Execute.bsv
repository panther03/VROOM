import FIFO::*;
import SpecialFIFOs::*;
import Vector::*;

import ControlRegs::*;
import MemTypes::*;
import XRUtil::*;
import VROOMTypes::*;
import VROOMFsm::*;
import KonataHelper::*;

import MemUnit::*;
import BranchUnit::*;
import Alu::*;
import MulDivUnit::*;

interface ExecuteIntf;
endinterface

module mkExecute #(
    VROOMFsm fsm,
    KonataIntf konataHelper,
    FIFO#(D2E) d2e,
    FIFO#(E2W) e2w,
    function Epoch currentEpoch(),
    MemUnit mu,
    BranchUnit bu,
    Alu alu,
    MulDivUnit mdu,
    ControlRegs crs
)(ExecuteIntf);

    rule execute if (fsm.runOk());
        let d2eResult = d2e.first();
        d2e.deq();

        let sr = d2eResult.sr;
        // Detect squashed instructions. We poison them so we can 
        // simply drop the instructions in writeback, freeing the 
        // scoreboard entry as we would normally.
        // Invalid instructions are also squashed this way.
        if (currentEpoch() != d2eResult.fi.epoch) begin
            konataHelper.stageInst(d2eResult.kid, "Xp");
            sr = Poisoned;
        end

        // Privilege check - are we executing prvilieged instruction in user mode
        if (crs.getCurrMode().u && d2eResult.di.priv) begin
            sr = PrivilegeFail;
        end

        if (stillValid(sr)) case (d2eResult.di.fu) 
            LoadStore: begin 
                if (d2eResult.di.barrier) begin
                    konataHelper.stageInst(d2eResult.kid, "Xmb");
                    mu.enq(tagged Barrier);
                end else begin
                    konataHelper.stageInst(d2eResult.kid, "Xm0");
                    mu.enq(tagged LoadStore (MemRequest {
                        rv1: d2eResult.ops.rv1,
                        rv2: d2eResult.ops.rv2,
                        rv3: d2eResult.ops.rv3,
                        inst: d2eResult.di.inst,
                        kid: d2eResult.kid,
                        isStore: d2eResult.di.store
                    }));
                end
            end
            ALU: begin
                konataHelper.stageInst(d2eResult.kid, "Xa");
                alu.enq(AluRequest {
                    rv1: d2eResult.ops.rv1,
                    rv2: d2eResult.ops.rv2,
                    inst: d2eResult.di.inst
                });
            end
            Control: begin
                konataHelper.stageInst(d2eResult.kid, "Xc");
                bu.enq(BranchRequest {
                    rv1: d2eResult.ops.rv1,
                    inst: d2eResult.di.inst,
                    pc: d2eResult.fi.pc
                });
            end
            MulDiv: begin
                konataHelper.stageInst(d2eResult.kid, "Xdm");
                let fields = getInstFields(d2eResult.di.inst);
                mdu.enq(MulDivRequest {
                    rv1: d2eResult.ops.rv1,
                    rv2: d2eResult.ops.rv2,
                    op: case (fields.funct4) 
                        fn4_DIV, fn4_DIVS: Div;
                        fn4_MOD: Mod;
                        fn4_MUL: Mul;
                    endcase,
                    isSigned: fields.funct4 == fn4_DIVS
                });
            end
            default: begin
                // do nothing
            end
        endcase
        
        e2w.enq(E2W {
            fi: d2eResult.fi,
            di: d2eResult.di,
            sr: sr,
            kid: d2eResult.kid
        });
    endrule

endmodule