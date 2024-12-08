import MemTypes::*;
import VROOMTypes::*;
import FIFO::*;
import Ehr::*;

interface FetchIntf;
    method ActionValue#(F2D) deq;
endinterface

module mkFetch #(
    Reg#(Bool) started,
    function Action putIMemReq(IMemReq r),
    Ehr#(2, Bit#(32)) pc,
    Ehr#(2, Bit#(1)) epoch
)(FetchIntf);

    FIFO#(F2D) f2d <- mkFIFO;
        
    rule fetch if (started);
        Bit#(32) pc_next = pc[0] + 4;

        pc[0] <= pc_next;

        let req = IMemReq { addr: pc[0][31:4] };
        putIMemReq(req);

        f2d.enq(F2D {
            fi: FetchInfo {
                pc: pc[0],       // Current PC
                // npc: pc_next, // Next PC
                epoch: epoch[0]
            }
        });
    endrule

    method ActionValue#(F2D) deq;
        f2d.deq(); return f2d.first();
    endmethod

endmodule