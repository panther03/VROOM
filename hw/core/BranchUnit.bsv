import FIFO::*;
import Ehr::*;
import RVUtil::*;

typedef Bit#(32) BranchResult;

typedef struct {
    Bit#(32) rv1;
    Bit#(32) rv2;
    Bit#(32) imm;
    Bit#(32) inst;
    Bit#(32) pc;
} BranchRequest deriving (Bits);

interface BranchUnitInput;
    interface Ehr#(2, Bit#(32)) extPC;
    interface Ehr#(2, Bit#(1)) extEpoch;
endinterface

interface BranchUnit;
    method Action enq(BranchRequest b);
    method ActionValue#(BranchResult) deq();
endinterface

module mkBranchUnit#(BranchUnitInput inIfc)(BranchUnit);
    FIFO#(BranchResult) results <- mkFIFO;

    Ehr#(2, Bit#(32)) extPC = inIfc.extPC;
    Ehr#(2, Bit#(1)) extEpoch = inIfc.extEpoch;


    method Action enq(BranchRequest b);
        // We can just use taken as a trigger for a misprediction, since we always predict not taken.
        let controlResult = execControl32(b.inst, b.rv1, b.rv2, b.imm, b.pc);
        let data = b.pc + 16;

        if (controlResult.taken) begin  
            //$display("taken!");
            extPC[1] <= controlResult.nextPC; 
            extEpoch[0] <= ~extEpoch[0];
        end else begin
            //$display("not taken ", fshow(b.inst));
        end
        results.enq(data);
    endmethod

    method ActionValue#(BranchResult) deq();
        let res = results.first; results.deq();
        return res;
    endmethod
endmodule