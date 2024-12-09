import MemTypes::*;
import VROOMTypes::*;
import VROOMFsm::*;
import KonataHelper::*;
import FIFO::*;
import Ehr::*;

interface FetchIntf;
    method Action redirect(ControlRedirection r);
    method Epoch currentEpoch();
endinterface

module mkFetch #(
    VROOMFsm fsm,
    KonataIntf konataHelper,
    FIFO#(F2D) f2d,
    function Action putIMemReq(IMemReq r)
)(FetchIntf);
    Ehr#(2, Bit#(32)) pc <- mkEhr(32'hFFFE1000);
    Ehr#(2, Epoch) epoch <- mkEhr(2'h0);
    Reg#(Bit#(28)) lastImemAddr <- mkReg(28'h0);
        
    rule fetch if (fsm.getState() == Steady);
        Bit#(32) pc_next = pc[0] + 4;

        pc[0] <= pc_next;

        let imem_addr = pc[0][31:4];

        // Access to word in the same fetched line. Doesn't need to be fetched from cache again
        // If in uncached region, always need new fetch.
        let needsNewFetch = pc[0][31:30] == 2'b11 || imem_addr != lastImemAddr;
        if (needsNewFetch) begin
            let req = IMemReq { addr: pc[0][31:2] };
            putIMemReq(req);
        end

        lastImemAddr <= imem_addr;

        let kid <- konataHelper.declareInst(tagged Invalid);
        konataHelper.stageInst(kid, needsNewFetch ? "Fn" : "Fo");
        konataHelper.labelInstLeft(kid, $format("PC=%08x", pc[0]));

        f2d.enq(F2D {
            fi: FetchInfo {
                pc: pc[0],       // Current PC
                // npc: pc_next, // Next PC
                epoch: epoch[0]
            },
            sr: None, // TODO misalignment exception
            kid: kid,
            needsNewFetch: needsNewFetch
        });
    endrule

    method Action redirect(ControlRedirection r);
        pc[1] <= r.pc;
        epoch[1] <= r.epoch;
    endmethod

    method Epoch currentEpoch();
        return epoch[0];
    endmethod
endmodule