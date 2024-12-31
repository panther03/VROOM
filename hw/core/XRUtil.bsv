typedef struct {
    Bit#(3) op3u;
    Bit#(3) op3l;
    Bit#(4) funct4;
    Bit#(2) sc;
    Bit#(5) shamt5;
    Bit#(5) regC;
    Bit#(5) regB;
    Bit#(5) regA;
    Bit#(16) imm16;
    Bit#(21) brofs21;
    Bit#(29) jt29;
} InstFields deriving (FShow);

function InstFields getInstFields(Bit#(32) inst);
    return InstFields {
        op3u:    inst[5:3],
        op3l:    inst[2:0],
        funct4:  inst[31:28],
        sc:      inst[27:26],
        shamt5:  inst[25:21],
        regC:    inst[20:16],
        regB:    inst[15:11],
        regA:    inst[10:6],
        imm16:   inst[31:16],
        brofs21: inst[31:11],
        jt29:    inst[31:3]
    };
endfunction

// JUMP
Bit#(3) op3l_JUMP = 3'b110;
Bit#(3) op3l_JAL  = 3'b111;
// BEQ
Bit#(3) op3l_BRANCH = 3'b101;
Bit#(3) op3u_BEQ    = 3'b111;
Bit#(3) op3u_BNE    = 3'b110;
Bit#(3) op3u_BLT    = 3'b101;
Bit#(3) op3u_BGT    = 3'b100;
Bit#(3) op3u_BLE    = 3'b011;
Bit#(3) op3u_BGE    = 3'b010;
Bit#(3) op3u_BPE    = 3'b001;
Bit#(3) op3u_BPO    = 3'b000;
// IMMEDIATE
Bit#(3) op3l_IMM_GRP100 = 3'b100;
Bit#(3) op3u_ADDI        = 3'b111;
Bit#(3) op3u_SUBI        = 3'b110;
Bit#(3) op3u_SLTI        = 3'b101;
Bit#(3) op3u_SLTIS       = 3'b100;
Bit#(3) op3u_ANDI        = 3'b011;
Bit#(3) op3u_XORI        = 3'b010;
Bit#(3) op3u_ORI         = 3'b001;
Bit#(3) op3u_LUI         = 3'b000;

Bit#(3) op3l_IMM_GRP011 = 3'b011;
Bit#(3) op3u_LOADB      = 3'b111;
Bit#(3) op3u_LOADI      = 3'b110;
Bit#(3) op3u_LOADL      = 3'b101;

Bit#(3) op3l_IMM_GRP010 = 3'b010;
Bit#(3) op3u_STORB      = 3'b111;
Bit#(3) op3u_STORI      = 3'b110;
Bit#(3) op3u_STORL      = 3'b101;
Bit#(3) op3u_STORIB     = 3'b011;
Bit#(3) op3u_STORII     = 3'b010;
Bit#(3) op3u_STORIL     = 3'b001;

Bit#(3) op3l_IMM_GRP000 = 3'b000;
Bit#(3) op3u_JALR       = 3'b111;

// REGISTER OPERATORS
Bit#(3) op3l_REG        = 3'b001;
Bit#(3) op3u_REG_111    = 3'b111;
Bit#(4) fn4_LOADB       = 4'b1111;
Bit#(4) fn4_LOADI       = 4'b1110;
Bit#(4) fn4_LOADL       = 4'b1101;
Bit#(4) fn4_STORB       = 4'b1011;
Bit#(4) fn4_STORI       = 4'b1010;
Bit#(4) fn4_STORL       = 4'b1001;
Bit#(4) fn4_SHIFT       = 4'b1000;
Bit#(4) fn4_ADD         = 4'b0111;
Bit#(4) fn4_SUB         = 4'b0110;
Bit#(4) fn4_SLT         = 4'b0101;
Bit#(4) fn4_SLTS        = 4'b0100;
Bit#(4) fn4_AND         = 4'b0011;
Bit#(4) fn4_XOR         = 4'b0010;
Bit#(4) fn4_OR          = 4'b0001;
Bit#(4) fn4_NOR         = 4'b0000;

Bit#(3) op3u_REG_110    = 3'b110;
Bit#(4) fn4_MUL         = 4'b1111;
Bit#(4) fn4_DIV         = 4'b1101;
Bit#(4) fn4_DIVS        = 4'b1100;
Bit#(4) fn4_MOD         = 4'b1011;
Bit#(4) fn4_LL          = 4'b1001;
Bit#(4) fn4_SC          = 4'b1000;
Bit#(4) fn4_MB          = 4'b0011;
Bit#(4) fn4_WMB         = 4'b0010;
Bit#(4) fn4_BRK         = 4'b0001;
Bit#(4) fn4_SYS         = 4'b0000;

Bit#(3) op3u_REG_101    = 3'b101;
Bit#(4) fn4_MFCR        = 4'b1111;
Bit#(4) fn4_MTCR        = 4'b1110;
Bit#(4) fn4_HLT         = 4'b1100;
Bit#(4) fn4_RFE         = 4'b1011;

Bit#(5) reg_LR = 5'd31;

Bit#(4) ecause_INT = 4'd1;
Bit#(4) ecause_SYS = 4'd2;
Bit#(4) ecause_BUS = 4'd4;
Bit#(4) ecause_NMI = 4'd5;
Bit#(4) ecause_BRK = 4'd6;
Bit#(4) ecause_INV = 4'd7;
Bit#(4) ecause_PRV = 4'd8;
Bit#(4) ecause_UNA = 4'd9;
Bit#(4) ecause_PGF = 4'd12;
Bit#(4) ecause_PFW = 4'd13;
Bit#(4) ecause_ITB = 4'd14;
Bit#(4) ecause_DTB = 4'd15;

typedef enum {
    LoadStore,
    Control,
    ALU,
    Nop,
    MulDiv
} FunctUnit deriving (Eq, FShow, Bits);

// rs1, rs2, rs3 and rd are used instead of RA, RB, and RC,
// because RA is sometimes a destination and sometimes a source.
// The ALU will always be fed two operands. Decode takes care of this.
typedef struct {
    Bool legal;
    Maybe#(Bit#(5)) rs1;
    Maybe#(Bit#(5)) rs2;
    Maybe#(Bit#(5)) rs3;
    Maybe#(Bit#(5)) rd;
    Bool serial;
    Bool priv;
    Bool barrier;
    Bool forceExceptionSkip;
    Bit#(32) inst;
    FunctUnit fu;
} DecodedInst deriving (Eq, FShow, Bits);

function Bool isLegal(InstFields fields);
    return case (fields.op3l) 
    op3l_JUMP, op3l_JAL, op3l_BRANCH: True;
    op3l_IMM_GRP100: True;
    op3l_IMM_GRP011: case (fields.op3u) 
        op3u_LOADB, op3u_LOADI, op3u_LOADL: True;
        default: False;
    endcase
    op3l_IMM_GRP010: case (fields.op3u)
        op3u_STORB, op3u_STORI, op3u_STORL: True;
        op3u_STORIB, op3u_STORII, op3u_STORIL: True;
        default: False;
    endcase
    op3l_IMM_GRP000: fields.op3u == op3u_JALR;
    op3l_REG: case (fields.op3u)
        op3u_REG_111: True;
        op3u_REG_110: case (fields.funct4)
            fn4_MB, fn4_WMB: True;
            fn4_MUL, fn4_DIV, fn4_DIVS, fn4_MOD: True;
            fn4_BRK, fn4_SYS: True;
            default: False;
        endcase
        op3u_REG_101: case (fields.funct4)
            fn4_MFCR, fn4_MTCR, fn4_HLT, fn4_RFE: True;
            default: False;
        endcase
        default: False;
    endcase
    default: False;
    endcase;
endfunction

function FunctUnit getFU(InstFields fields);
    return case (fields.op3l) 
    op3l_JUMP, op3l_JAL, op3l_BRANCH: Control;
    op3l_IMM_GRP100: ALU;
    op3l_IMM_GRP011: LoadStore;
    op3l_IMM_GRP010: LoadStore;
    op3l_IMM_GRP000: Control;
    op3l_REG: case (fields.op3u)
        op3u_REG_111: unpack(fields.funct4[3] & |fields.funct4[2:0]) ? LoadStore : ALU;
        op3u_REG_110: case (fields.funct4)
            fn4_MUL, fn4_MOD, fn4_DIV, fn4_DIVS: MulDiv;
            fn4_BRK, fn4_SYS: ALU;
            fn4_MB, fn4_WMB: LoadStore;
            default: ALU;
        endcase
        op3u_REG_101: case (fields.funct4)
            fn4_HLT: Nop;
            fn4_RFE: Control;
            default: ALU;
        endcase
        default: ALU;
    endcase
    default: ALU; // TODO I wonder if bluespec has a dont-care facility for enums
    endcase;
endfunction

function Maybe#(Bit#(5)) getRD(InstFields fields);
    return case (fields.op3l)
        op3l_JAL, op3l_IMM_GRP000: tagged Valid(reg_LR);
        op3l_IMM_GRP100, op3l_IMM_GRP011: tagged Valid(fields.regA);
        op3l_REG: case (fields.op3u)
            op3u_REG_111: 
                unpack(fields.funct4[3] & ~fields.funct4[2] & |fields.funct4[1:0]) ? tagged Invalid : tagged Valid(fields.regA);
            op3u_REG_110: case (fields.funct4)
                fn4_MUL,fn4_MOD,fn4_DIV,fn4_DIVS: tagged Valid(fields.regA);
                default: tagged Invalid;
            endcase
            op3u_REG_101: case (fields.funct4)
                fn4_MFCR: tagged Valid(fields.regA);
                default: tagged Invalid;
            endcase
            default: tagged Invalid;
        endcase
        default: tagged Invalid;
    endcase;
endfunction

function Maybe#(Bit#(5)) getRS1(InstFields fields);
    return case (fields.op3l)
        op3l_BRANCH: tagged Valid(fields.regA);
        op3l_IMM_GRP100: tagged Valid(fields.regB);
        // Rs1 is used as address in load/store  instructions
        op3l_IMM_GRP011: tagged Valid(fields.regB);
        op3l_IMM_GRP010: tagged Valid(fields.regA);
        op3l_IMM_GRP000: tagged Valid(fields.regB);
        op3l_REG: case (fields.op3u) 
            op3u_REG_111: tagged Valid(fields.regB);
            op3u_REG_110: case (fields.funct4)
                fn4_MUL,fn4_MOD,fn4_DIV,fn4_DIVS: tagged Valid(fields.regB);
                default: tagged Invalid;
            endcase
            op3u_REG_101: case (fields.funct4)
                fn4_MTCR: tagged Valid(fields.regB);
                default: tagged Invalid;
            endcase
            default: tagged Invalid;
        endcase
        default: tagged Invalid;
    endcase;
endfunction

function Maybe#(Bit#(5)) getRS2(InstFields fields);
    // RS2 is used exclusively as RC in the register operand forms
    // In the address generator unit, it is used as another addend to the address
    return case (fields.op3l)
        op3l_REG: case (fields.op3u)
            op3u_REG_111: tagged Valid(fields.regC);
            op3u_REG_110: case (fields.funct4)
                fn4_MUL,fn4_MOD,fn4_DIV,fn4_DIVS: tagged Valid(fields.regC);
                default: tagged Invalid;
            endcase
            default: tagged Invalid;
        endcase
        default: tagged Invalid;
    endcase;
endfunction

function Maybe#(Bit#(5)) getRS3(InstFields fields);
    // RS3 is used exclusively as the value in store instructions
    return case (fields.op3l)
        op3l_IMM_GRP010: case (fields.op3u)
            op3u_STORB, op3u_STORI, op3u_STORL: tagged Valid(fields.regB);
            default: tagged Invalid;
        endcase
        op3l_REG: case (fields.op3u)
            op3u_REG_111: case (fields.funct4) 
                fn4_STORB, fn4_STORI, fn4_STORL: tagged Valid(fields.regA);
                default: tagged Invalid;
            endcase
            default: tagged Invalid;
        endcase
        default: tagged Invalid;
    endcase;
endfunction

function Bool isSerialInst(InstFields fields);
    return case (fields.op3l)
        op3l_REG: case (fields.op3u)
            op3u_REG_101: case (fields.funct4)
                fn4_MTCR, fn4_RFE, fn4_HLT: True;
                default: False;
            endcase
            default: False;
        endcase
        default: False;
    endcase;
endfunction

function Bool isBarrier(InstFields fields);
    return case (fields.op3l)
        op3l_REG: case (fields.op3u)
            op3u_REG_110: case (fields.funct4)
                fn4_WMB, fn4_MB: True;
                default: False;
            endcase
            default: False;
        endcase
        default: False;
    endcase;
endfunction

// not a big fan of this solution but it works i guess
function Bool isForceExceptionSkip(InstFields fields);
    return case (fields.op3l)
        op3l_REG: case (fields.op3u)
            op3u_REG_110: case (fields.funct4)
                fn4_BRK, fn4_SYS: True;
                default: False;
            endcase
            default: False;
        endcase
        default: False;
    endcase;
endfunction

function DecodedInst decodeInst(Bit#(32) inst);
    let fields = getInstFields(inst);
    return DecodedInst {
        legal: isLegal(fields),
        rs1: getRS1(fields),
        rs2: getRS2(fields),
        rs3: getRS3(fields),
        rd: getRD(fields),
        priv: ((fields.op3l == op3l_REG) && (fields.op3u == op3u_REG_101)),
        serial: isSerialInst(fields),
        barrier: isBarrier(fields),
        fu: getFU(fields),
        forceExceptionSkip: isForceExceptionSkip(fields),
        inst: inst
    };
endfunction

function Bit#(32) swap32(Bit#(32) x);
    return {x[7:0], x[15:8], x[23:16], x[31:24]};
endfunction