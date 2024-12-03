import RVUtil::*;
import FIFO::*;

typedef Bit#(32) AluResult;

typedef struct {
    Bit#(32) rv1;
    Bit#(32) rv2;
    Bit#(32) imm;
    Bit#(32) inst;
    Bit#(32) pc;
} AluRequest deriving (Bits);

interface Alu;
    method ActionValue#(AluResult) deq();
    method Action enq(AluRequest a);
endinterface

module mkAlu(Alu);
    FIFO#(AluResult) results <- mkFIFO;
    method Action enq(AluRequest a);
        let data = execALU32(a.inst, a.rv1, a.rv2, a.imm, a.pc);

        results.enq(data);
    endmethod

    method ActionValue#(AluResult) deq();
        let res = results.first; results.deq();
        return res;
    endmethod
endmodule