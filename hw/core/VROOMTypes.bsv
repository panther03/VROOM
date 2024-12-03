import Vector::*;
import XRUtil::*;

typedef struct {
    // Current PC
    Bit#(32) pc;
    // Previous PC
    Bit#(32) ppc;
    // Epoch (for squashing branches)
    Bit#(1) epoch;
} FetchInfo deriving (Eq, FShow, Bits);

typedef struct {
    Bit#(5) rs1;
    Bit#(5) rs2;
    Bit#(5) rd;
} RegisterUsage deriving (Eq, FShow, Bits);

typedef struct {
    Bit#(32) rv1;
    Bit#(32) rv2;
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
    Vector#(4, DecodedInst) dis;
    Vector#(4, RegisterUsage) rus;
`ifdef KONATA_ENABLE
    KonataId k_id;
`endif
} D2I deriving (Eq, FShow, Bits);

typedef struct {
    FetchInfo fi;
    Vector#(4, DecodedInst) dis;
    Vector#(4, Operands) ops;
    Vector#(4, Bit#(5)) dests;
`ifdef KONATA_ENABLE
    KonataId k_id;
`endif
} I2E deriving (Eq, FShow, Bits);

typedef struct {
    Vector#(4, DecodedInst) dis;
    Vector#(4, Bit#(5)) dests;
    Bool poisoned;
`ifdef KONATA_ENABLE
    KonataId k_id;
`endif
} E2W deriving (Eq, FShow, Bits);