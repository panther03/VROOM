`include "BuildDefs.bsv"

import FIFO::*;

`ifdef KONATA_ENABLE
typedef Bit#(48) KonataId; 
typedef Bit#(8) ThreadId;
`else
typedef void KonataId;
typedef void ThreadId;
`endif

interface KonataIntf;
    method Action init(String logpath);
    method ActionValue#(KonataId) declareInst(Maybe#(ThreadId) tid);
    method Action commitInst(KonataId kid);
    method Action squashInst(KonataId kid);
    method Action stageInst(KonataId kid, String stage);
    method Action labelInstLeft(KonataId kid, Fmt f);
    method Action labelInstHover(KonataId kid, Fmt f);
endinterface

`ifdef KONATA_ENABLE
Bit#(32) deadlockLimit = 32'd1000;
// Konata-enabled implementation
module mkKonata (KonataIntf);
    Reg#(KonataId) allCtr <- mkReg(0);
    Reg#(KonataId) commitCtr <- mkReg(1);
    Reg#(Bit#(32)) deadlockCtr <- mkReg(0);
    Reg#(Bool) inited <- mkReg(False);
    let lfh <- mkReg(InvalidFile);

    FIFO#(KonataId) committed <- mkFIFO;
    FIFO#(KonataId) squashed <- mkFIFO;

    PulseWire comitting <- mkPulseWire;
    PulseWire squashing <- mkPulseWire;
    
    rule tick if (inited);
        $fdisplay(lfh, "C\t1");
    endrule

    rule deadlockCheck if (inited);
        if (comitting || squashing) 
            deadlockCtr <= 0;
        else 
            deadlockCtr <= deadlockCtr + 1;
        
        //if (deadlockCtr >= deadlockLimit) begin
        //    $fdisplay(stderr, "Stopping due to deadlock after %d cycles of no commit/squash", deadlockCtr);
        //    $finish;
        //end
    endrule

    rule doSquash if (inited);
        let kid = squashed.first(); squashed.deq();
        squashing.send();
        $fdisplay(lfh, "R\t%d\t%d\t%d", kid, 0, 1);
    endrule
        
    rule doCommit if (inited);
        let kid = committed.first(); committed.deq();
        comitting.send();
        commitCtr <= commitCtr + 1;
        $fdisplay(lfh, "R\t%d\t%d\t%d", kid, commitCtr, 0);
    endrule

    method Action init(String logPath) if (!inited);
        let f <- $fopen(logPath, "w");
        lfh <= f;
        inited <= True;
        $fwrite(f, "Kanata\t0004\nC=\t1\n");
    endmethod

    method ActionValue#(KonataId) declareInst(Maybe#(ThreadId) tid) if (inited);
        let tidM = fromMaybe(0, tid);
        allCtr <= allCtr + 1;
        $fdisplay(lfh,"I\t%d\t%d\t%d",allCtr,allCtr,tid);
        return allCtr;
    endmethod

    method Action squashInst(KonataId kid) if (inited);
        squashed.enq(kid);
    endmethod

    method Action commitInst(KonataId kid) if (inited);
        committed.enq(kid);
    endmethod

    method Action stageInst(KonataId kid, String stage) if (inited);
        $fdisplay(lfh,"S\t%d\t%d\t%s", kid, 0, stage);
    endmethod

    method Action labelInstLeft(KonataId kid, Fmt f) if (inited);
        $fdisplay(lfh, "L\t%d\t%d\t", kid, 0, f);
    endmethod

    method Action labelInstHover(KonataId kid, Fmt f) if (inited);
        $fdisplay(lfh, "L\t%d\t%d\t", kid, 1, f);
    endmethod
endmodule
`else
// Dummy implementation
module mkKonata (KonataIntf);
    method Action init(String logPath);
    endmethod

    method ActionValue#(KonataId) declareInst(Maybe#(ThreadId) tid);
        return ?;
    endmethod

    method Action squashInst(KonataId kid);
    endmethod

    method Action commitInst(KonataId kid);
    endmethod

    method Action stageInst(KonataId kid, String stage);
    endmethod

    method Action labelInstLeft(KonataId kid, Fmt f);
    endmethod

    method Action labelInstHover(KonataId kid, Fmt f);
    endmethod
endmodule
`endif