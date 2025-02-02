// System word size
typedef Bit#(32) Word;

// Bus types
typedef struct { Bit#(4) byte_strobe; Bit#(1) line_en; Bit#(30) addr; Bit#(512) data;} BusReq deriving (Eq, FShow, Bits, Bounded);
typedef Bit#(512) BusResp;

// Cache types
typedef struct { Bit#(4) word_byte; Bit#(30) addr; Bit#(32) data;} DMemReq deriving (Eq, FShow, Bits, Bounded);
typedef Word DMemResp;

typedef struct { Bit#(30) addr; } IMemReq deriving (Eq, FShow, Bits, Bounded);
// 128 bits for prefetching
// 120 more optimal for future vliw (?)
typedef Bit#(128) IMemResp;

///////////////////
// Shared types //
/////////////////
typedef enum{LdHit, StHit, Miss} HitMissType deriving (Bits, Eq);

typedef enum {WaitCAUResp, SendReq, WaitDramResp, BusPassthrough} CacheState deriving (Eq, Bits, FShow);

// You can translate between Vector#(16, Word) and Bit#(512) using the pack/unpack builtin functions.
typedef Bit#(512) LineData;

////////////////
// L1D Types //
//////////////

typedef Bit#(21) L1LineTag;
typedef Bit#(5) L1LineIndex;
typedef Bit#(4) WordOffset;

typedef struct {
    LineData data;
    L1LineTag tag;
    Bool isDirty;
} L1TaggedLine;

typedef struct {
    L1LineTag tag;
    L1LineIndex index;
    WordOffset offset;
} L1ParsedAddress deriving (Bits, Eq);

function L1ParsedAddress parseL1Address(Bit#(30) address);
    return L1ParsedAddress{
        tag: address[29:9],
        index: address[8:4],
        offset: address[3:0]
    };
endfunction

function Bit#(64) calcBE(L1ParsedAddress pa, DMemReq c);
    Bit#(64) wb_64  = zeroExtend(c.word_byte);
    Bit#(64) wb_ofs = zeroExtend(pa.offset) << 2;
    return wb_64 << wb_ofs;
endfunction

////////////////
// L1I Types //
//////////////

typedef Bit#(2) IWordOffset;

typedef struct {
    L1LineTag tag;
    L1LineIndex index;
    IWordOffset offset;
} L1IParsedAddress deriving (Bits, Eq);

function L1IParsedAddress parseL1IAddress(Bit#(28) address);
    return L1IParsedAddress {
        tag: address[27:7],
        index: address[6:2],
        offset: address[1:0]
    };
endfunction

Bit#(32) cacheCtrlWord = {8'd0, 8'd9, 8'd1, 8'd7};

// L2 no longer in use

///////////////
// L2 Types //
/////////////

//typedef Bit#(18) L2LineTag;
//typedef Bit#(8) L2LineIndex;
//
//typedef struct {
//    LineData data;
//    L2LineTag tag;
//    Bool isDirty;
//} L2TaggedLine;
//
//typedef struct {
//    L2LineTag tag;
//    L2LineIndex index;
//} L2ParsedAddress deriving (Bits, Eq);
//
//function L2ParsedAddress parseL2Address(Bit#(26) address);
//    return L2ParsedAddress {
//        tag: address[25:8],
//        index: address[7:0]
//    };
//endfunction

