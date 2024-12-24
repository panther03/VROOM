import VROOMTypes::*;
import VROOMFsm::*;
import Scoreboard::*;
import XRUtil::*;
import RegFile::*;
import FIFO::*;
import KonataHelper::*;
import Ehr::*;

import MemUnit::*;
import BranchUnit::*;
import Alu::*;
import ControlRegs::*;

interface ExceptionsIntf;
    method Action putASyncException();
    method Action putSyncException(ExceptionRequest er);
endinterface

module mkExceptions #(
    VROOMFsm fsm,
    KonataIntf konataHelper,
    ControlRegs crs,
    function Bit#(32) archNextPc(),
    function Epoch frontendEpoch(),
    function Action redirectFrontend(ControlRedirection r),
    function Action redirectBackend(ControlRedirection r)
)(ExceptionsIntf);
    Ehr#(2, Bool) busy <- mkEhr(False);
    Reg#(ExceptionRequest) erReg <- mkReg(?);

    rule exceptionHandler if (fsm.getState() == Exception);
        // The architectural next PC is always where we want to resume to.
        // This is even the case if we have to retry an instruction because 
        // it generated an exception. If this is the case, we do not update the next PC in commit.
        // So, the next PC still points to that instruction.
        crs.setEpc(archNextPc());
        // Update RS: push mode bits, set ECAUSE
        crs.updateRsForExc(erReg.ecause);
        // TODO handle NMI tomfoolery

        // TODO: weirdness with EB == 0 meaning reset? 
        // can't find in manual on cursory glance
        // https://github.com/xrarch/xremu/blob/92be4f224aa1395b1462757353d6a2248192b958/src/xr17032mp.c#L174
        // not sure if just safety precaution
        // TODO: could make horribly slow hardware if it doesn't inline readCR
        Bit#(32) npc = {(crs.readCRRaw(pack(EB)))[31:12], erReg.ecause, 8'h0};
        let cr = ControlRedirection {
            pc: npc,
            epoch: frontendEpoch() + 2'h1
        };
        redirectFrontend(cr);
        redirectBackend(cr);
        fsm.trs_FinishException(); 
        busy[0] <= False;      
    endrule

    method Action putASyncException() if (!busy[1] && fsm.getState() != Exception);
        erReg <= ExceptionRequest {
            ecause: ecause_INT
        };
        busy[0] <= True;
    endmethod

    method Action putSyncException(ExceptionRequest er) if (!busy[0] && fsm.getState() != Exception);
        erReg <= er;
        busy[0] <= True;
    endmethod

endmodule