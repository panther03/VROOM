import FIFO::*;
import SpecialFIFOs::*;
import Vector::*;

import ControlRegs::*;
import MemTypes::*;
import XRUtil::*;
import VROOMTypes::*;

interface ExecuteIntf;
    method Action enq(D2E d2e);
    method ActionValue#(E2W) deq;
endinterface

module mkExecute #(
    ControlRegs crs
)(ExecuteIntf);
FIFO#(E2W) e2w <- mkSizedFIFO(4);

method Action enq(D2E d2e);
    let poisoned = False;

    // Detect squashed instructions. We poison them so we can 
    // simply drop the instructions in writeback, freeing the 
    // scoreboard entry as we would normally.
    // Invalid instructions are also squashed this way.
    if (epoch[0] != d2e.fi.epoch || !d2e.di.legal) begin
        poisoned = True;
    end else case (d2e.di.fu) 
        LoadStore: 
        ALU: 
        Control:
    endcase
endmethod

method ActionValue#(E2W) deq;
    e2w.deq(); return e2w.first();
endmethod

endmodule