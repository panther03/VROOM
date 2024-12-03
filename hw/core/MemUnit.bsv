import FIFO::*;
import SpecialFIFOs::*;
import MemTypes::*;

typedef Bit#(32) MemResult;

typedef struct {
    Bit#(32) rv1;
    Bit#(32) rv2;
    Bit#(32) imm;
    Bit#(32) inst;
    Bit#(3) funct3;
    Bit#(32) pc;
    Bit#(32) addr_offset;
} MemRequest deriving (Bits);

typedef struct { Bool we; Bool isUnsigned; Bit#(2) size; Bit#(2) offset; Bool mmio; } MemBusiness deriving (Eq, FShow, Bits);

interface MemUnitInput;
    interface FIFO#(Mem) toDmem;
    interface FIFO#(Mem) toMMIO;
    interface FIFO#(Mem) fromDmem;
    interface FIFO#(Mem) fromMMIO;
endinterface

interface MemUnit;
    method ActionValue#(MemResult) deq();
    method Action enq(MemRequest m);
endinterface

function Bool isMMIO(Bit#(32) addr);
    /*Bool x = case (addr) 
        32'hf000fff0: True;
        32'hf000fff4: True;
        32'hf000fff8: True;
        default: False;
    endcase;*/
    // simplifying assumption
    return addr[31:29] == 3'h7;
endfunction

module mkMemUnit#(MemUnitInput inIfc, Bool respOnStore)(MemUnit);
    FIFO#(MemResult) results <- mkBypassFIFO;
    FIFO#(MemBusiness) currBusiness <- mkFIFO;

    FIFO#(Mem) toDmem = inIfc.toDmem;
    FIFO#(Mem) toMMIO = inIfc.toMMIO;
    FIFO#(Mem) fromDmem = inIfc.fromDmem;
    FIFO#(Mem) fromMMIO = inIfc.fromMMIO;

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
        let addr = m.rv1 + m.imm;
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
        Bool mmio = False;
`ifdef DEBUG_ENABLE
            $display("[Execute] Memory, addr=%x", addr);
`endif
        if (isMMIO(addr)) begin 
`ifdef DEBUG_ENABLE
            $display("[Execute] MMIO", fshow(req));
`endif
            toMMIO.enq(req);
`ifdef KONATA_ENABLE
            labelKonataLeft(lfh,current_id, $format(" (MMIO)", fshow(req)));
`endif
            mmio = True;
        end else begin 
`ifdef KONATA_ENABLE
            labelKonataLeft(lfh,current_id, $format(" (MEM)", fshow(req)));
`endif
            req.addr = req.addr + m.addr_offset;
            toDmem.enq(req);
        end

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
endmodule