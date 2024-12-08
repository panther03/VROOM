import Vector::*;
import Ehr::*;

// TODO: ordering??
// assuming low bits come first
typedef struct {
    Bool u;
    Bool i;
    Bool m;
    Bool t;
    Bit#(4) mbz;
} ModeByte deriving (Bits);

typedef struct {
    ModeByte curr;
    ModeByte old;
    ModeByte oldold;
    Bit#(4) mbz;
    Bit#(4) ecause;
} RS deriving (Bits);

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
    method ModeByte getCurrMode();
endinterface

module mkCRS (ControlRegs);
    Vector#(32, Ehr#(2, Bit#(32))) crf <- replicateM(mkEhr(32'h0));

    method Action writeCR(Bit#(5) idx, Bit#(32) val);
        crf[idx][0] <= val;
    endmethod

    method Bit#(32) readCR(Bit#(5) idx);
        return crf[idx][0];
    endmethod

    method ModeByte getCurrMode();
        RS rs = unpack(crf[pack(RS)][0]);
        return rs.curr;
    endmethod
endmodule