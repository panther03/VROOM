import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import MemTypes::*;
import XRUtil::*;
import VROOMTypes::*;
import KonataHelper::*;

typedef struct {
    Maybe#(ExcResult) ru;
    Bool wr;
    KonataId kid;
} Stage1Result deriving (Bits);

typedef struct {
    Bit#(32) rv1;
    Bit#(32) rv2;
    Bit#(32) rv3;
    Bit#(32) inst;
    KonataId kid;
} MemRequest deriving (Bits);

typedef struct { Bit#(2) size; Bit#(2) offset; } ReadBusiness deriving (Eq, FShow, Bits);

interface MemUnit;
    method ActionValue#(ExcResult) deq();
    method Action enq(MemRequest m);
    method Action commitStore();
endinterface

module mkMemUnit#(
    KonataIntf konataHelper,
    function Action putDMemReq(DMemReq r),
    function ActionValue#(DMemResp) getDMemResp
)(MemUnit);
    FIFO#(Stage1Result) stage1 <- mkFIFO;
    FIFO#(MemRequest) reqs <- mkBypassFIFO;
    FIFO#(ExcResult) results <- mkBypassFIFO;
    FIFOF#(ReadBusiness) currBusiness <- mkFIFOF;
    // pipeline FIFO: want to be able to enqueue and dequeue in same cycle,
    // but also have only one state that we need to check
    FIFOF#(DMemReq) storeQueue <- mkPipelineFIFOF;
    FIFO#(DMemReq) loadQueue <- mkFIFO;

    rule getMemoryResponse;
        let stage1_res = stage1.first(); stage1.deq();
        konataHelper.stageInst(stage1_res.kid, "Xm2");
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

    rule executeLoad;
        let lastLoad = loadQueue.first();
        loadQueue.deq();
        putDMemReq(lastLoad);
    endrule

    rule handleRequest;
        let m = reqs.first(); reqs.deq();
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
                wr: isStore,
                kid: m.kid
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
                    wr: isStore,
                    kid: m.kid
                });
            end else begin
                currBusiness.enq(ReadBusiness{
                    size: size,
                    offset: offset
                });    
                stage1.enq(Stage1Result {
                    ru: tagged Invalid,
                    wr: isStore,
                    kid: m.kid
                });
            end
        end 

        if (isStore) begin
            konataHelper.labelInstLeft(m.kid, $format(" STORE @ %08x", addr));
        end else begin
            konataHelper.labelInstLeft(m.kid, $format(" LOAD @ %08x", addr));
        end
    endrule

    // Bluespec is being weird with the stalling logic here. Inlining handleRequest here should not make a difference,
    // but it stalls all instructions, even those which are not going to memory. So I am adding a FIFO between.
    method Action enq(MemRequest m);
        reqs.enq(m);
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