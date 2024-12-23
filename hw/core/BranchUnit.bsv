import FIFO::*;
import VROOMTypes::*;
import VROOMFsm::*;
import XRUtil::*;

typedef struct {
    Bit#(32) rv1;
    Bit#(32) inst;
    Bit#(32) pc;
} BranchRequest deriving (Bits);

interface BranchUnit;
    method Action enq(BranchRequest b);
    method ActionValue#(ExcResult) deq();
    method ActionValue#(Maybe#(ControlRedirection)) getCR();
endinterface

function Bool canSpeculateMoreBranches(Epoch speculated, Epoch committed);
    // Why 2? Need to block for commit in this case because one more branch and we will wrap around to
    // the current committed epoch if an exception happens on one of the inflight instructions
    // (this increments the frontend counter)
    return pack(speculated) != pack(committed) + 2'h2;
endfunction

module mkBranchUnit#(
    function Action redirect(ControlRedirection r),
    function Epoch frontendEpoch(),
    function Epoch backendEpoch()
)(BranchUnit);
    FIFO#(ExcResult) results <- mkFIFO;
    FIFO#(Maybe#(ControlRedirection)) crs <- mkFIFO;

    method Action enq(BranchRequest b) if (canSpeculateMoreBranches(frontendEpoch(), backendEpoch()));
        // Note: This method NEEDS to work like this
        // Adding a FIFO between this and execute stage (where the epoch is checked) will break everything
        // Breaks the property that the epoch flip of the earlier instruction in program order must be visible,
        // since they could get stuck in the FIFO
        
        let fields = getInstFields(b.inst);
        
        Bit#(32) immExt = ((fields.op3l == op3l_IMM_GRP000) ? signExtend({fields.imm16,2'h0}) : signExtend({fields.brofs21,2'h0}));
        let pcPlus4 = b.pc + 4;
        let pc_add = ((fields.op3l == op3l_IMM_GRP000) ? b.rv1 : b.pc) + immExt;
        let n_epoch = frontendEpoch() + 1;
        Maybe#(ControlRedirection) r = tagged Invalid;
        Bit#(32) result = ?;

        // We can just use taken as a trigger for a misprediction, since we always predict not taken.
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
        crs.enq(r);
        results.enq(ExcResult {
            data: result,
            ecause: tagged Invalid
        });
    endmethod

    method ActionValue#(ExcResult) deq();
        let res = results.first; results.deq();
        return res;
    endmethod

    method ActionValue#(Maybe#(ControlRedirection)) getCR();
        crs.deq(); return crs.first();
    endmethod
endmodule