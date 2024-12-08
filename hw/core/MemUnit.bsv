import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import MemTypes::*;
import XRUtil::*;
import VROOMTypes::*;

typedef struct {
    Maybe#(ExcResult) ru;
    Bool wr;
} Stage1Result deriving (Bits);

typedef struct {
    Bit#(32) rv1;
    Bit#(32) rv2;
    Bit#(32) rv3;
    Bit#(32) inst;
} MemRequest deriving (Bits);

typedef struct { Bit#(2) size; Bit#(2) offset; } ReadBusiness deriving (Eq, FShow, Bits);

interface MemUnit;
    method ActionValue#(ExcResult) deq();
    method Action enq(MemRequest m);
    method Action commitStore();
endinterface

function Bit#(32) swap32(Bit#(32) x);
    return {x[7:0], x[15:8], x[23:16], x[31:24]};
endfunction

module mkMemUnit#(
    function Action putDMemReq(DMemReq r),
    function ActionValue#(DMemResp) getDMemResp
)(MemUnit);
    FIFO#(Stage1Result) stage1 <- mkFIFO;
    FIFO#(ExcResult) results <- mkBypassFIFO;
    FIFOF#(ReadBusiness) currBusiness <- mkFIFOF;
    // pipeline FIFO: want to be able to enqueue and dequeue in same cycle,
    // but also have only one state that we need to check
    FIFOF#(DMemReq) storeQueue <- mkPipelineFIFOF;

    rule getMemoryResponse;
        let stage1_res = stage1.first(); stage1.deq();
        if (!isValid(stage1_res.ru)) begin
            let business = currBusiness.first(); currBusiness.deq();
            DMemResp resp <- getDMemResp();
            let mem_data = swap32(resp) >> {business.offset, 3'b0};

            Bit#(32) data = ?;
            case (business.size) matches
                2'b11 : data = zeroExtend(mem_data[7:0]);
                2'b10 : data = zeroExtend(mem_data[15:0]);
                2'b01 : data = mem_data;
            endcase
            results.enq(ExcResult {
                data: data,
                ecause: tagged Invalid
            });
        end else begin
            results.enq(fromMaybe(?, stage1_res.ru));
        end
    endrule

    method Action enq(MemRequest m);
        let fields = getInstFields(m.inst);
        Bool regForm = (fields.op3l == op3l_REG);
        let addr = m.rv1 + (regForm ? (m.rv2 << fields.shamt5) : zeroExtend(fields.imm16));
        // only store small immediate instructions have top bit of op3u set to 0
        Bit#(32) val = !unpack(fields.op3u[2]) ? zeroExtend(fields.regC) : m.rv3;
        Bit#(3) lsOpc = regForm ? fields.funct4[2:0] : fields.op3u;
        
        Bit#(2) offset = addr[1:0];
        // Technical details for load byte/int/long
        let shift_amount = {offset, 3'b0};
        Bit#(4) byte_en = 0;
        Bool misaligned = False;
        let size = lsOpc[1:0];
        case (size) matches
        2'b11: begin byte_en = 4'b1000 >> offset; end
        2'b10: begin byte_en = 4'b1100 >> offset; misaligned = unpack(offset[0]); end
        2'b01: begin byte_en = 4'b1111; misaligned = unpack(|offset); end
        endcase
        
        let isStore = unpack(lsOpc[2]);
        let data = swap32(m.rv2) >> shift_amount;
        let req = DMemReq {
            word_byte : isStore ? byte_en : 0,
            addr : addr[31:2],
            data : data
        };
        
        if (misaligned) begin
            stage1.enq(Stage1Result {
                ru: tagged Valid ExcResult {
                    data: ?,
                    ecause: tagged Valid(ecause_UNA)
                },
                wr: isStore
            });
        end else if (isStore) begin
            storeQueue.enq(req);
        end else begin // LOAD
            // Check if there is already a pending store to the same address
            if (storeQueue.notEmpty() && storeQueue.first.addr == addr[31:2]) begin
                stage1.enq(Stage1Result {
                    ru: tagged Valid ExcResult {
                        data: swap32(storeQueue.first.data),
                        ecause: tagged Invalid
                    },
                    wr: isStore
                });
            end else begin
                putDMemReq(req);
                currBusiness.enq(ReadBusiness{
                    size: size,
                    offset: offset
                });    
                stage1.enq(Stage1Result {
                    ru: tagged Invalid,
                    wr: isStore
                });
            end
        end 
    endmethod

    method ActionValue#(ExcResult) deq();
        let res = results.first; results.deq();
        return res;
    endmethod

    method Action commitStore();
        let lastStore = storeQueue.first;
        storeQueue.deq();
        putDMemReq(lastStore);
    endmethod
endmodule