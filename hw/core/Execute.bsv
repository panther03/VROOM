import FIFO::*;
import SpecialFIFOs::*;
import Vector::*;

import ControlRegs::*;
import MemTypes::*;
import XRUtil::*;
import VROOMTypes::*;
import VROOMFsm::*;

import MemUnit::*;
import BranchUnit::*;
import Alu::*;

interface ExecuteIntf;
endinterface

module mkExecute #(
    VROOMFsm fsm,
    FIFO#(D2E) d2e,
    FIFO#(E2W) e2w,
    function Epoch currentEpoch(),
    MemUnit mu,
    BranchUnit bu,
    Alu alu,
    ControlRegs crs
)(ExecuteIntf);

    rule execute if (fsm.getState() == Steady);
        let d2eResult = d2e.first();
        d2e.deq();

        let sr = d2eResult.sr;
        // Detect squashed instructions. We poison them so we can 
        // simply drop the instructions in writeback, freeing the 
        // scoreboard entry as we would normally.
        // Invalid instructions are also squashed this way.
        if (currentEpoch() != d2eResult.fi.epoch) begin
            sr = Poisoned;
        end

        if (stillValid(sr)) case (d2eResult.di.fu) 
            LoadStore: mu.enq(MemRequest {
                rv1: d2eResult.ops.rv1,
                rv2: d2eResult.ops.rv2,
                rv3: d2eResult.ops.rv3,
                inst: d2eResult.di.inst
            });
            ALU: alu.enq(AluRequest {
                rv1: d2eResult.ops.rv1,
                rv2: d2eResult.ops.rv2,
                inst: d2eResult.di.inst
            });
            Control: bu.enq(BranchRequest {
                rv1: d2eResult.ops.rv1,
                inst: d2eResult.di.inst,
                pc: d2eResult.fi.pc
            });
        endcase
        
        e2w.enq(E2W {
            di: d2eResult.di,
            sr: sr
        });
    endrule

endmodule