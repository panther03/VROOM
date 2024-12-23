import VROOMTypes::*;
import ConfigReg::*;

interface VROOMFsm;
    method VROOMState getState();
    method Bool runOk();
    method Action trs_Start();
    method Action trs_EnterASyncException();
    method Action trs_EnterSyncException();
    method Action trs_StopDecode();
    method Action trs_RestartDecode();
    method Action trs_FinishException();
endinterface 

module mkVROOMFsm(VROOMFsm);
    Reg#(VROOMState) state <- mkConfigReg(Starting);
    PulseWire startEn <- mkPulseWire;
    PulseWire enterSExcEn <- mkPulseWire;
    PulseWire enterASExcEn <- mkPulseWire;
    PulseWire stopDecode <- mkPulseWire;
    PulseWire restartDecode <- mkPulseWire;
    PulseWire finishException <- mkPulseWire;

    rule fsm;
        case (state)
            Starting: if (startEn) state <= Steady;
            Steady: if (enterASExcEn || enterSExcEn) state <= Exception; else if (stopDecode) state <= Serial;
            Serial: if (enterASExcEn || enterSExcEn) state <= Exception; else if (restartDecode) state <= Steady;
        endcase
    endrule

    method VROOMState getState();
        return state;
    endmethod

    method Bool runOk();
        return state == Steady || state == Serial;
    endmethod

    method Action trs_Start();
        startEn.send();
    endmethod

    method Action trs_EnterSyncException();
        enterSExcEn.send();
    endmethod

    method Action trs_EnterASyncException();
        enterASExcEn.send();
    endmethod

    method Action trs_StopDecode();
        stopDecode.send();
    endmethod

    method Action trs_RestartDecode();
        restartDecode.send();
    endmethod

    method Action trs_FinishException();
        finishException.send();
    endmethod
endmodule