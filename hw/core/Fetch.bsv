import MemTypes::*;
import VROOMTypes::*;
import FIFO::*;

interface FetchIntf;
    method ActionValue#(F2D) deq;
endinterface

module mkFetch #(
    Reg#(Bool) starting,
    function Action putIMemReq(IMemReq r),
    Reg#(Bit#(32)) pc,
    Reg#(Bit#(1)) epoch
)(FetchIntf);

    FIFO#(F2D) f2d <- mkFIFO;
        
    rule fetch if (!starting);
        Bit#(32) pc_next = pc[0] + 4;

        pc[0] <= pc_next;

        let req = IMemReq { addr: pc[31:6] };
        putIMemReq(req);

        f2d.enq(F2D {
            pc: pc_next,  // NEXT pc
            ppc: pcs[thread][0], // PREVIOUS pc
            epoch: epochs[thread][0],
            thread_id: 0
        });
    endrule

    method ActionValue#(F2D) deq;
        f2d.deq(); return f2d.first();
    endmethod

endmodule