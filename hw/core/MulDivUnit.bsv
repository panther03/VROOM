import VROOMTypes::*;
import StmtFSM::*;
import FIFO::*;
import ConfigReg::*;

typedef enum {
    Mul,
    Div,
    Mod
} MulDivOp deriving (Eq, FShow, Bits);

typedef struct {
    Bit#(32) rv1;
    Bit#(32) rv2;
    Bool isSigned;
    MulDivOp op;
} MulDivRequest deriving (Bits);

interface MulDivUnit;
    method ActionValue#(ExcResult) deq();
    method Action enq(MulDivRequest a);
endinterface

module mkMulDivUnit(MulDivUnit);
    FIFO#(MulDivRequest) reqs <- mkFIFO;
    Reg#(Bit#(32)) rv1 <- mkReg(32'h0);
    Reg#(Bit#(32)) rv2 <- mkReg(32'h0);
    Reg#(Bit#(32)) res <- mkReg(32'h0);
    Reg#(MulDivOp) op <- mkReg(?);
    FIFO#(ExcResult) results <- mkFIFO;
    Reg#(Bit#(32)) b <- mkReg(32'h0);
    Reg#(Bit#(1)) sign <- mkReg(1'b0);
    Reg#(Bool) running <- mkReg(False); // no idea why i need this

    Stmt s = seq
        if (op == Mul) seq
            /*for (i <= 0; i < 32; i <= i + 1) seq
                res <= res + (unpack(rv2[0]) ? rv1 : 0);  
                rv2 <= rv2 >> 1;
                rv1 <= rv1 << 1;
            endseq
            results.enq(ExcResult {
                data: res,
                ecause: tagged Invalid
            });*/
            // probably better mapping 2 FPGA
            results.enq(ExcResult {
                data: rv1 * rv2,
                ecause: tagged Invalid
            });
        endseq else if (op == Div || op == Mod) seq
            // lol
            // https://github.com/gcc-mirror/gcc/blob/master/libgcc/udivmodsi4.c
            while (rv2 < rv1 && b != 0 && !unpack(rv2[31])) seq
                rv2 <= rv2 << 1;
                b <= b << 1;
            endseq
            while (b != 0) seq
                if (rv1 >= rv2) seq
                    rv1 <= rv1 - rv2;
                    res <= res | b; 
                endseq
                b <= b >> 1;
                rv2 <= rv2 >> 1;
            endseq
            results.enq(ExcResult {
                data: (op == Mod) ? rv1 : (unpack(sign) ? -res : res),
                ecause: tagged Invalid 
            });
        endseq
        running <= False;
    endseq;
    FSM fsm <- mkFSMWithPred(s, running);

    rule handleReq if (!running);
        let a = reqs.first; reqs.deq();
        running <= True;
        res <= 0;
        b <= 32'h1;
        op <= a.op;
        if (a.isSigned) begin
            rv1 <= unpack(a.rv1[31]) ? (-a.rv1) : a.rv1;
            rv2 <= unpack(a.rv2[31]) ? (-a.rv2) : a.rv2;
            sign <= a.rv1[31] ^ a.rv2[31];
        end else begin
            rv1 <= a.rv1;
            rv2 <= a.rv2;
            sign <= 0;
        end
        fsm.start();
    endrule

    method Action enq(MulDivRequest a);
        reqs.enq(a);
    endmethod

    method ActionValue#(ExcResult) deq();
        results.deq(); return results.first;
    endmethod

endmodule