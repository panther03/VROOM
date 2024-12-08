import Vector::*;
import Ehr::*;

interface Scoreboard;
    method Action insert(Bit#(5) dst);
    method Action remove(Bit#(5) dst);
    method Bool search(Bit#(5) src);
endinterface

module mkScoreboardBoolFlags(Scoreboard); 
    Vector#(32,Ehr#(2, Bool)) ready <- replicateM(mkEhr(True));

    method Action insert(Bit#(5) dst);
        ready[dst][1] <= False;
    endmethod

    method Action remove(Bit#(5) dst);
        ready[dst][0] <= True;
    endmethod

    method Bool search(Bit#(5) src);
        return ready[src][0];
    endmethod
endmodule
