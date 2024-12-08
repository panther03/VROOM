import MemTypes::*;
import VROOMTypes::*;
import VROOMFsm::*;
import FIFO::*;
import Ehr::*;

interface FetchIntf;
    method Action redirect(ControlRedirection r);
    method Epoch currentEpoch();
endinterface

module mkFetch #(
    VROOMFsm fsm,
    FIFO#(F2D) f2d,
    function Action putIMemReq(IMemReq r)
)(FetchIntf);
    Ehr#(2, Bit#(32)) pc <- mkEhr(32'hFFFE1000);
    Ehr#(2, Epoch) epoch <- mkEhr(2'h0);
        
    rule fetch if (fsm.getState() == Steady);
        Bit#(32) pc_next = pc[0] + 4;

        pc[0] <= pc_next;

        let req = IMemReq { addr: pc[0][31:4] };
        putIMemReq(req);

        f2d.enq(F2D {
            fi: FetchInfo {
                pc: pc[0],       // Current PC
                // npc: pc_next, // Next PC
                epoch: epoch[0]
            },
            sr: None // TODO misalignment exception
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