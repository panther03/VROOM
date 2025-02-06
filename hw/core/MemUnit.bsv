import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import MemTypes::*;
import XRUtil::*;
import VROOMTypes::*;
import VROOMFsm::*;
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
    Bool isStore;
    KonataId kid;
} MemRequest deriving (Bits);

typedef union tagged {
    MemRequest LoadStore;
    void Barrier;
} MemInst deriving (Bits);

typedef struct { Bit#(2) size; Bit#(2) offset; } ReadBusiness deriving (Eq, FShow, Bits);

interface MemUnit;
    method ActionValue#(ExcResult) deq();
    method Action enq(MemInst m);
    method Action popSQ(Bool commit);
endinterface

module mkMemUnit#(
    VROOMFsm fsm,
    KonataIntf konataHelper,
    function Action putDMemReq(DMemReq r),
    function ActionValue#(DMemResp) getDMemResp,
    function Action putFlushRequest(),
    function Action blockTillFlushDone()
)(MemUnit);
    FIFO#(Stage1Result) stage1 <- mkFIFO;
    FIFO#(MemRequest) reqs <- mkBypassFIFO;
    FIFO#(ExcResult) results <- mkFIFO;
    FIFOF#(ReadBusiness) currBusiness <- mkFIFOF;
    // pipeline FIFO: want to be able to enqueue and dequeue in same cycle,
    // but also have only one state that we need to check
    FIFOF#(DMemReq) storeQueue <- mkPipelineFIFOF;
    Reg#(Bool) barrier <- mkReg(False);
    PulseWire setBarrier <- mkPulseWire;
    PulseWire clearBarrier <- mkPulseWire;

    rule updateBarrier;
        if (setBarrier) barrier <= True;
        else if (clearBarrier) barrier <= False;
    endrule

    rule getMemoryResponse if (fsm.runOk() && !barrier);
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

    //rule emptyStoreBuffer;
    //    let req = storeBuffer.first;
    //    storeBuffer.deq();
    //    
    //endrule

    rule handleRequest if (fsm.runOk() && !barrier);
        let m = reqs.first();
        let fields = getInstFields(m.inst);
        Bool regForm = (fields.op3l == op3l_REG);
        Bit#(3) lsOpc = regForm ? fields.funct4[2:0] : fields.op3u;
        let size = lsOpc[1:0];
        let immShift = ~size;
        let addr = m.rv1 + (regForm ? (m.rv2 << fields.shamt5) : (zeroExtend(fields.imm16)) << immShift);
        // only store small immediate instructions have top bit of op3u set to 0
        Bit#(32) val = !unpack(fields.op3u[2]) ? signExtend(fields.regB) : m.rv3;
        
        Bit#(2) offset = addr[1:0];
        // Technical details for load byte/int/long
        let shift_amount = {offset, 3'b0};
        Bit#(4) byte_en = 0;
        Bool misaligned = False;
        
        case (size) matches
        2'b11: begin byte_en = 4'b1000 >> offset; end
        2'b10: begin byte_en = 4'b1100 >> offset; misaligned = unpack(offset[0]); end
        2'b01: begin byte_en = 4'b1111; misaligned = unpack(|offset); end
        endcase
        let data = swap32(val) >> shift_amount;
        let req = DMemReq {
            word_byte : m.isStore ? byte_en : 0,
            addr : addr[31:2],
            data : data
        };
        //$display("request: (real addr %08x) %08x", addr, m.rv3, fshow(req));
        
        //Maybe#(Bit#(32)) sqHead = ?;

        Bool safetoDequeue = True;

        if (!misaligned) begin
            if (m.isStore) begin
                storeQueue.enq(req);
                //sqHead = tagged Invalid;
            end else if (storeQueue.notEmpty() && storeQueue.first.addr == addr[31:2]) begin
                //sqHead = tagged Valid storeQueue.first.data;
                safetoDequeue = False;
            end
        end 

        if (safetoDequeue) begin
            reqs.deq();
        end

        Maybe#(ExcResult) ru = ?;

        if (misaligned) begin
            ru = tagged Valid ExcResult {
                data: ?,
                ecause: tagged Valid(ecause_UNA)
            };
        end else if (m.isStore) begin
            ru = tagged Valid ExcResult { 
                data: ?,
                ecause: tagged Invalid
            };
        end else begin // LOAD
            // Check if there is already a pending store to the same address
            //if (isValid(sqHead)) begin
            //    $display("store queue stall");
            //    ru = tagged Valid ExcResult {
            //        data: swap32(fromMaybe(?, sqHead)),
            //        ecause: tagged Invalid
            //    };
            //end else begin
                putDMemReq(req);
                currBusiness.enq(ReadBusiness{
                    size: size,
                    offset: offset
                });    
                ru = tagged Invalid;
            //end
        end 

        if (m.isStore) begin
            konataHelper.labelInstLeft(m.kid, $format(" STORE @ %08x (%08x)", addr, data));
        end else begin
            konataHelper.labelInstLeft(m.kid, $format(" LOAD @ %08x", addr));
        end
        konataHelper.stageInst(m.kid, "Xm1");

        stage1.enq(Stage1Result {
            ru: ru,
            wr: m.isStore,
            kid: m.kid
        });
    endrule

    rule waitOnBarrier if (fsm.runOk() && barrier);
        blockTillFlushDone();
        clearBarrier.send();
        results.enq(ExcResult {
            data: ?,
            ecause: tagged Invalid
        });
    endrule

    // Bluespec is being weird with the stalling logic here. Inlining handleRequest here should not make a difference,
    // but it stalls all instructions, even those which are not going to memory. So I am adding a FIFO between.
    method Action enq(MemInst m) if (!barrier);
        case (m) matches
            tagged LoadStore .req: reqs.enq(req);
            tagged Barrier: begin 
                setBarrier.send();
                putFlushRequest();
            end
        endcase
    endmethod

    method ActionValue#(ExcResult) deq();
        let res = results.first; results.deq();
        return res;
    endmethod

    method Action popSQ(Bool commit);
        let lastStore = storeQueue.first;
        storeQueue.deq();
        //storeBuffer.enq(lastStore);
        if (commit) putDMemReq(lastStore);
    endmethod
endmodule