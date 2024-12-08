import VROOMTypes::*;
import ConfigReg::*;

interface VROOMFsm;
    method VROOMState getState();
    method Action trs_Start();
    method Action trs_EnterException();
endinterface 

module mkVROOMFsm(VROOMFsm);
    Reg#(VROOMState) state <- mkConfigReg(Starting);
    PulseWire start_en <- mkPulseWire;
    PulseWire enter_exc_en <- mkPulseWire;

    rule fsm;
        case (state)
            Starting: if (start_en) state <= Steady;
            Steady: if (enter_exc_en) state <= Exception;
            SerialMtcr: if (enter_exc_en) state <= Exception;
        endcase
    endrule

    method VROOMState getState();
        return state;
    endmethod

    method Action trs_Start();
        start_en.send();
    endmethod

    method Action trs_EnterException();
        enter_exc_en.send();
    endmethod
endmodule