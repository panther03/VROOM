import Vector::*;
import Ehr::*;
import MemTypes::*;

typedef struct {
    Bit#(4) mbz;
    Bool t;
    Bool m;
    Bool i;
    Bool u;
} ModeByte deriving (FShow, Bits);

typedef struct {
    Bit#(4) ecause;
    Bit#(4) mbz;
    ModeByte oldold;
    ModeByte old;
    ModeByte curr;
} RS deriving (FShow, Bits);

typedef enum {
    RS          = 5'd0,
    WHAMI       = 5'd1,
    EB          = 5'd5,
    EPC         = 5'd6,
    EBADADDR    = 5'd7,
    TBMISSADDDR = 5'd9,
    TBPC        = 5'd10,
    SCRATCH0    = 5'd11,
    SCRATCH1    = 5'd12,
    SCRATCH2    = 5'd13,
    SCRATCH3    = 5'd14,
    SCRATCH4    = 5'd15,
    ITBPTE      = 5'd16,
    ITBTAG      = 5'd17,
    ITBINDEX    = 5'd18,
    ITBCTRL     = 5'd19,
    ICACHECTRL  = 5'd20,
    ITBADDR     = 5'd21,
    DTBPTE      = 5'd24,
    DTBTAG      = 5'd25,
    DTBINDEX    = 5'd26,
    DTBCTRL     = 5'd27,
    DCACHECTRL  = 5'd28,
    DTBADDR     = 5'd29
} CRNames deriving (Bits);

interface ControlRegs;
    method Action writeCR(Bit#(5) idx, Bit#(32) val);
    method Bit#(32) readCR(Bit#(5) idx);
    method Bit#(32) readCRRaw(Bit#(5) idx);
    method ModeByte getCurrMode();
    method Action setEpc(Bit#(32) pc);
    method Action updateBadAddr(Bit#(32) addr);
    method Action updateRsForExc(Bit#(4) ecause);
    method Bit#(32) calcPopModeBits();
endinterface

module mkCRS #(
    function Action icacheClearLines(),
    function Action dcacheClearLines()
) (ControlRegs);

    Vector#(32, Ehr#(2, Bit#(32))) crf;
    
    Integer i;
    for ( i = 0; i < 32; i = i + 1 ) begin
        if (fromInteger(i) == pack(ICACHECTRL) || fromInteger(i) == pack(DCACHECTRL))
            crf[i] <- mkEhr(cacheCtrlWord);
        else
            crf[i] <- mkEhr(32'h0);
    end

    method Action writeCR(Bit#(5) idx, Bit#(32) val);
        if (idx == pack(ICACHECTRL) && unpack(val[1])) begin
            icacheClearLines();
        end else if (idx == pack(DCACHECTRL) && unpack(val[1])) begin
            dcacheClearLines();
        end else begin
            crf[idx][0] <= val;
        end
    endmethod

    method Bit#(32) readCRRaw(Bit#(5) idx);
        return crf[idx][0];
    endmethod

    method Bit#(32) readCR(Bit#(5) idx);
        //if (idx == pack(ICACHECTRL) || idx) begin
        //    return cacheCtrlWord;
        //end
        return crf[idx][0];
    endmethod

    method ModeByte getCurrMode();
        RS rs = unpack(crf[pack(RS)][0]);
        return rs.curr;
    endmethod

    method Action setEpc(Bit#(32) pc);
        crf[pack(EPC)][1] <= pc;
    endmethod

    method Action updateRsForExc(Bit#(4) ecause);
        RS newRs = unpack(crf[pack(RS)][0]);
        newRs.oldold = newRs.old;
        newRs.old = newRs.curr;
        // for now: always disable usermode and external interrupts
        newRs.curr = unpack({pack(newRs.curr)[7:2], 2'b00});
        newRs.ecause = ecause;
        crf[pack(RS)][1] <= pack(newRs);
    endmethod

    method Action updateBadAddr(Bit#(32) addr);
        crf[pack(EBADADDR)][1] <= addr;
    endmethod

    method Bit#(32) calcPopModeBits();
        RS newRs = unpack(crf[pack(RS)][0]);
        newRs.curr = newRs.old;
        newRs.old = newRs.oldold;
        newRs.oldold = unpack(8'h0);
        return pack(newRs);
    endmethod
endmodule