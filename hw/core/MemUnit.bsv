import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import MemTypes::*;

typedef Bit#(32) MemResult;

typedef struct {
    Bit#(32) rv1;
    Bit#(32) rv2;
    Bit#(32) rv3;
    Bit#(32) inst;
} MemRequest deriving (Bits);

typedef struct { Bool we; Bit#(2) size; Bit#(2) offset; Bool mmio; } MemBusiness deriving (Eq, FShow, Bits);

interface MemUnit;
    method ActionValue#(MemResult) deq();
    method Action enq(MemRequest m);
    method Action commit();
endinterface

module mkMemUnit#(
    function Action putDMemReq(DMemReq r),
    function ActionValue#(DMemResp) getDMemResp
)(MemUnit);
    FIFO#(MemResult) results <- mkBypassFIFO;
    FIFO#(MemBusiness) currBusiness <- mkFIFO;
    FIFOF#(DMemReq) storeQueue <- mkFIFOF1;

    rule getMemoryResponse;
        let business = currBusiness.first(); currBusiness.deq();
        Mem resp = ?;
        if (business.mmio) begin
            resp = fromMMIO.first; fromMMIO.deq();            
        end else begin
            resp = fromDmem.first; fromDmem.deq();
        end
        let mem_data = resp.data;
        mem_data = mem_data >> {business.offset, 3'b0};

        MemResult data = ?;
        case ({pack(business.isUnsigned), business.size}) matches
	     	3'b000 : data = signExtend(mem_data[7:0]);
	     	3'b001 : data = signExtend(mem_data[15:0]);
	     	3'b100 : data = zeroExtend(mem_data[7:0]);
	     	3'b101 : data = zeroExtend(mem_data[15:0]);
	     	3'b010 : data = mem_data;
        endcase
        if (!business.we || respOnStore) begin
            results.enq(data);
        end
    endrule

    method Action enq(MemRequest m);
        let fields = getInstFields(m.inst);
        Bool regForm = (fields.op3l == op3l_REG);
        let addr = m.rv1 + regForm ? (m.rv2 << fields.shamt5) : zeroExtend(fields.imm16);
        // only store small immediate instructions have top bit of op3u set to 0
        Bit#(32) val = !unpack(fields.op3u[2]) ? zeroExtend(fields.regC) : m.rv3;
        
		Bit#(2) offset = addr[1:0];
        addr = {addr[31:2], 2'b0};
        // Technical details for load byte/halfword/word
        let shift_amount = {offset, 3'b0};
        Bit#(4) byte_en = 0;
        let size = m.funct3[1:0];
        case (size) matches
        2'b00: byte_en = 4'b0001 << offset;
        2'b01: byte_en = 4'b0011 << offset;
        2'b10: byte_en = 4'b1111 << offset;
        endcase
        let data = m.rv2 << shift_amount;
        let isUnsigned = m.funct3[2];
        Bit#(4) type_mem = (m.inst[5] == 1) ? byte_en : 0;
        let req = Mem {byte_en : type_mem,
                    addr : addr,
                    data : data};

        if

        currBusiness.enq(MemBusiness{
            isUnsigned: unpack(isUnsigned),
            size: size,
            offset: offset,
            mmio: mmio,
            we: (type_mem == 0)
        });
    endmethod

    method ActionValue#(MemResult) deq();
        let res = results.first; results.deq();
        return res;
    endmethod

    method Action commit();
        let lastStore = storeQueue.first;
        storeQueue.deq();

    endmethod
endmodule