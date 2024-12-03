import MemTypes::*;
import VROOMTypes::*;
import FIFO::*;

interface DecodeIntf;
    method Action enq(F2D f2d);
    method ActionValue#(D2I) deq;
endinterface

module mkDecode #(
    function ActionValue#(IMemResp) getIMemResp,
    Reg#(Bit#(32)) pc,
    Reg#(Bit#(1)) epoch
)(DecodeIntf);

    FIFO#(D2I) d2i <- mkFIFO;
        
    method Action enq(F2D f2d);
        
    endmethod

    method ActionValue#(D2I) deq;
        d2i.deq(); return d2i.first();
    endmethod

endmodule