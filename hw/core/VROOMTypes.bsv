import Vector::*;
import XRUtil::*;

typedef struct {
    // Current PC (address of executing instruction)
    Bit#(32) pc;
    // Next PC -- do we even need this?
    // Bit#(32) npc;
    // Epoch (for squashing branches)
    Bit#(1) epoch;
} FetchInfo deriving (Eq, FShow, Bits);

typedef struct {
    Maybe#(Bit#(32)) rv1;
    Maybe#(Bit#(32)) rv2;
    Maybe#(Bit#(32)) rv3;
} Operands deriving (Eq, FShow, Bits);

/////////////////////////
// Pipeline Registers //
///////////////////////

typedef struct {
    FetchInfo fi;
`ifdef KONATA_ENABLE
    KonataId k_id;
`endif
} F2D deriving (Eq, FShow, Bits);

typedef struct {
    FetchInfo fi;
    DecodedInst di;
    Operands ops;
`ifdef KONATA_ENABLE
    KonataId k_id;
`endif
} D2E deriving (Eq, FShow, Bits);

typedef struct {
    DecodedInst di;
    Bool poisoned;
`ifdef KONATA_ENABLE
    KonataId k_id;
`endif
} E2W deriving (Eq, FShow, Bits);