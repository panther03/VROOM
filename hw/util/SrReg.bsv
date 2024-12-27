interface SrReg;
    method Action set();
    method Action reset();
    method Bool read();
endinterface

module mkSrReg #(
    Bool setBeforeClear
)(SrReg);
    Reg#(Bool) state <- mkReg(False);
    PulseWire setState <- mkPulseWire;
    PulseWire resetState <- mkPulseWire;

    rule update;
        if (setBeforeClear) begin
            if (setState) 
                state <= True;
            else if (resetState)
                state <= False;
        end else begin
            if (resetState)
                state <= False;
            else if (setState)
                state <= True;
        end 
    endrule

    method Bool read();
        return state;
    endmethod

    method Action set();
        setState.send();
    endmethod

    method Action reset();
        resetState.send();
    endmethod

endmodule