import FIFO::*;
import VROOMTypes::*;
import XRUtil::*;

typedef struct {
    Bit#(32) rv1;
    Bit#(32) inst;
    Bit#(32) pc;
} BranchRequest deriving (Bits);

interface BranchUnit;
    method Action enq(BranchRequest b);
    method ActionValue#(ExcResult) deq();
endinterface


module mkBranchUnit#(
    function Action redirect(ControlRedirection r),
    function Epoch currentEpoch()
)(BranchUnit);
    FIFO#(ExcResult) results <- mkFIFO;

    method Action enq(BranchRequest b);
        // We can just use taken as a trigger for a misprediction, since we always predict not taken.
        let fields = getInstFields(b.inst);
        
        Bit#(32) immExt = ((fields.op3l == op3l_IMM_GRP000) ? signExtend({fields.imm16,2'h0}) : signExtend({fields.brofs21,2'h0}));
        let pcPlus4 = b.pc + 4;
        let pc_add = ((fields.op3l == op3l_IMM_GRP000) ? b.rv1 : b.pc) + immExt;
        let n_epoch = currentEpoch() + 1;
        Maybe#(ControlRedirection) r = tagged Invalid;
        Bit#(32) result = ?;

        case (fields.op3l) 
            op3l_JUMP: r = tagged Valid ControlRedirection {
                pc: {b.pc[31], fields.jt29, 2'h0},
                epoch: n_epoch
            };
            op3l_JAL: begin
                result = pcPlus4;
                r = tagged Valid ControlRedirection {
                    pc: {b.pc[31], fields.jt29, 2'h0},
                    epoch: n_epoch
                };
            end
            op3l_IMM_GRP000: begin // JALR assumed
                result = pcPlus4;
                r = tagged Valid ControlRedirection {
                    pc: pc_add,
                    epoch: n_epoch
                };
            end
            op3l_BRANCH: begin
                // 1. *Trust* the compiler.
                // 2. *Trust* the synthesizer.
                // 3. Focus on *Trailmix*.
                Bool taken = case (fields.op3u)
                    op3u_BEQ: (b.rv1 == 0);
                    op3u_BNE: (b.rv1 != 0);
                    op3u_BLT: (unpack(b.rv1[31]));
                    op3u_BGT: (!unpack(b.rv1[31]) && b.rv1 != 0);
                    op3u_BLE: (unpack(b.rv1[31]) || b.rv1 == 0);
                    op3u_BGE: !unpack(b.rv1[31]);
                    op3u_BPE: !unpack(b.rv1[0]);
                    op3u_BPO: unpack(b.rv1[0]);
                endcase;
                r = taken ? tagged Valid ControlRedirection {
                    pc: pc_add,
                    epoch: n_epoch
                } : tagged Invalid;
            end
            // HLT & RFE TODO
        endcase

        if (isValid(r)) begin
            redirect(fromMaybe(?, r));
        end
        results.enq(ExcResult {
            data: result,
            ecause: tagged Invalid
        });
    endmethod

    method ActionValue#(ExcResult) deq();
        let res = results.first; results.deq();
        return res;
    endmethod
endmodule