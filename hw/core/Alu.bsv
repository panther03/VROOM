import XRUtil::*;
import FIFO::*;
import Vector::*;
import ControlRegs::*;
import VROOMTypes::*;

typedef struct {
    Bit#(32) rv1;
    Bit#(32) rv2;
    Bit#(32) inst;
} AluRequest deriving (Bits);

interface Alu;
    method ActionValue#(ExcResult) deq();
    method Action enq(AluRequest a);
endinterface

function Bit#(32) alu32(Bit#(32) op1, Bit#(32) op2, Bit#(3) aluOp, Bool regForm);  
    Vector#(32, Bit#(1)) regFormMask = replicate(pack(regForm));
    return (case (aluOp) 
        op3u_ADDI: op1 + op2;
        op3u_SUBI: op1 - op2;
        op3u_SLTI: zeroExtend(pack(op1 < op2));
        op3u_SLTIS: zeroExtend(pack(signedLT(op1, op2)));
        op3u_ANDI: op1 & op2;
        op3u_XORI: op1 ^ op2;
        op3u_ORI: op1 | op2;
        op3u_LUI: pack(regFormMask) ^ (op1 | (regForm ? op2 : {op2[15:0], 16'h0}));
    endcase);
endfunction

// this is fucked
function Bit#(32) shft32(Bit#(32) op1, Bit#(5) shamt, Bit#(2) sc);
    Vector#(32, Bit#(1)) opBv = unpack(op1);

    Bit#(32) temp0 = (shamt[0]==1) ? (
        case (sc) 
            2'b00: op1 << 1;
            2'b01: op1 >> 1;
            2'b10: signedShiftRight(op1, 1);
            2'b11: {op1[0], op1[31:1]};
        endcase
    ) : op1;
    Bit#(32) temp1 = (shamt[1]==1) ? (
        case (sc) 
            2'b00: temp0 << 2;
            2'b01: temp0 >> 2;
            2'b10: signedShiftRight(op1, 2);
            2'b11: {temp0[1:0], temp0[31:2]};
        endcase
    ) : temp0;
    Bit#(32) temp2 = (shamt[2]==1) ? (
        case (sc) 
            2'b00: temp1 << 4;
            2'b01: temp1 >> 4;
            2'b10: signedShiftRight(op1, 4);
            2'b11: {temp1[3:0], temp1[31:4]};
        endcase
    ) : temp1;
    Bit#(32) temp3 = (shamt[3]==1) ? (
        case (sc) 
            2'b00: temp2 << 8;
            2'b01: temp2 >> 8;
            2'b10: signedShiftRight(op1, 8);
            2'b11: {temp2[7:0], temp2[31:8]};
        endcase
    ) : temp2;
    Bit#(32) temp4 = (shamt[4]==1) ? (
        case (sc) 
            2'b00: temp3 << 16;
            2'b01: temp3 >> 16;
            2'b10: signedShiftRight(op1, 16);
            2'b11: {temp3[7:0], temp3[31:8]};
        endcase
    ) : temp3;
    return temp4;
endfunction

module mkAlu #(
    ControlRegs crs   
)(Alu);
    FIFO#(ExcResult) results <- mkFIFO;
    method Action enq(AluRequest a);
        let fields = getInstFields(a.inst);
        if (fields.op3l != op3l_IMM_GRP100 && fields.op3l != op3l_REG) begin
            $display("malformed ALU instruction? ", fshow(a.inst));
        end
        Bool regForm = (fields.op3l == op3l_REG);
        Bit#(32) imm = (!regForm && fields.op3u == op3u_SLTIS) ? signExtend(fields.imm16) : zeroExtend(fields.imm16);
        let op1 = a.rv1;
        let do_shift = regForm && fields.op3u == op3u_REG_111;
        let is_reg_shamt = fields.funct4 == fn4_SHIFT;
        let op2_reg = shft32(a.rv2, (do_shift ? (is_reg_shamt ? a.rv1[4:0]: fields.shamt5) : 0), fields.sc);
        let op2 = regForm ? op2_reg : imm;
        Bit#(3) aluOp = regForm ? fields.funct4[2:0] : fields.op3u;
        let data = (regForm && is_reg_shamt) ? op2 : alu32(op1, op2, aluOp, regForm);
        Maybe#(Bit#(4)) ecause = tagged Invalid;
        if (regForm && fields.op3u == op3u_REG_101) begin
            if (unpack(fields.funct4[0])) begin
                data = crs.readCR(fields.regC);
            end else begin
                data = op1;
            end
        end
        results.enq(ExcResult {
            data: data,
            ecause: ecause
        });
    endmethod

    method ActionValue#(ExcResult) deq();
        let res = results.first; results.deq();
        return res;
    endmethod
endmodule