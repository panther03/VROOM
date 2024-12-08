import Vector::*;
import XRUtil::*;
import RegFile::*;
import KonataHelper::*;

typedef enum {
    Starting,
    Steady,
    SerialMtcr,
    Exception
} VROOMState deriving (Eq, FShow, Bits);

typedef enum {
    None,
    MisalignFetch,
    DecodeInvalid,
    Poisoned
} SquashReason deriving (Eq, FShow, Bits);

function Bool stillValid(SquashReason sr); 
    return sr == None;
endfunction

typedef Bit#(2) Epoch;

typedef RegFile#(Bit#(5), Bit#(32)) VROOMRf;

typedef struct {
    Bit#(32) data;
    Maybe#(Bit#(4)) ecause;
} ExcResult deriving (Eq, FShow, Bits);

typedef struct {
    // Current PC (address of executing instruction)
    Bit#(32) pc;
    // Next PC -- do we even need this?
    // Bit#(32) npc;
    // Epoch (for squashing branches)
    Epoch epoch;
} FetchInfo deriving (Eq, FShow, Bits);

typedef FetchInfo ControlRedirection;

typedef struct {
    Bit#(32) rv1;
    Bit#(32) rv2;
    Bit#(32) rv3;
} Operands deriving (Eq, FShow, Bits);

/////////////////////////
// Pipeline Registers //
///////////////////////

typedef struct {
    FetchInfo fi;
    SquashReason sr;
    KonataId kid;
} F2D deriving (Eq, FShow, Bits);

typedef struct {
    FetchInfo fi;
    DecodedInst di;
    Operands ops;
    SquashReason sr;
    KonataId kid;
} D2E deriving (Eq, FShow, Bits);

typedef struct {
    DecodedInst di;
    SquashReason sr;
    KonataId kid;
} E2W deriving (Eq, FShow, Bits);