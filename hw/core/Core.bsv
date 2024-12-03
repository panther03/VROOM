// cache enabled by default
`define CACHE_ENABLE

// system imports
import BRAM::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Ehr::*;
// local imports
import RVUtil::*;
import VLIW::*;

import MemTypes::*;
`ifdef CACHE_ENABLE
import CacheInterface::*;
`endif

typedef struct {
    // TODO: the address doesn't need to be this big for our purposes
    Bit#(32) addr;
    Bit#(32) data;
    Bool write_enable;
} CoreBusRequest deriving (Bits);

interface Core;
    // Bus Request
    method ActionValue#(CoreBusRequest) getBusReq();
    // Bus Response
    method Action putBusResp(Bit#(32) resp);
    // Has the core reached a halt
    method Bool getFinished();
endinterface

(* synthesize *)
module mkCore #(Bool ctr_enable) (Core);
`ifdef CACHE_ENABLE
    CacheInterface cache <- mkCacheInterface();
    BRAM_Configure cfg = defaultValue();
    cfg.loadFormat = tagged Binary "zeroScratch.mem";
    BRAM2Port#(Bit#(12), Word) scratch <- mkBRAM2Server(cfg); // 32K
`else
    // Instantiate the dual ported memory
    BRAM_Configure cfg = defaultValue();
    cfg.loadFormat = tagged Hex "mem.mem";
    BRAM2PortBE#(Bit#(12), Word, 4) bram <- mkBRAM2ServerBE(cfg);
`endif

    RVIfc rv_core <- mkVLIW(ctr_enable);

    FIFO#(CoreBusRequest) busReqs <- mkFIFO;
    FIFO#(Bit#(32)) busResps <- mkFIFO;

    Reg#(IMem) ireq <- mkRegU;
    FIFO#(Mem) dreq <- mkPipelineFIFO;
    FIFO#(Mem) mmioreq <- mkFIFO;
    let debug = False;
    Reg#(Bit#(32)) cycle_count <- mkReg(0);
    Reg#(Bit#(32)) count_arrived <- mkReg(0);

    rule tic;
	    cycle_count <= cycle_count + 1;
    endrule

    rule requestI;
        let req <- rv_core.getIReq;
        if (debug) $display("Get IReq", fshow(req));
        ireq <= req;

`ifdef CACHE_ENABLE
        cache.sendReqInstr(ICacheReq{addr: req.addr, data: req.data});
`else
        bram.portB.request.put(BRAMRequestBE{
                    writeen: req.byte_en,
                    responseOnWrite: True,
                    address: truncate(req.addr >> 2),
                    datain: req.data});
`endif
    endrule

    rule responseI;
`ifdef CACHE_ENABLE
        let x <- cache.getRespInstr();
`else
        let x <- bram.portB.response.get();
`endif
        let req = ireq;
        if (debug) $display("Get IResp ", fshow(req), fshow(x));
        req.data = x;
        rv_core.getIResp(req);
    endrule

    rule requestD;
        let req <- rv_core.getDReq;
        dreq.enq(req);
        if (debug) $display("Get DReq", fshow(req));

`ifdef CACHE_ENABLE
        cache.sendReqData(CacheReq{word_byte: req.byte_en, addr: req.addr, data: req.data});
`else
        bram.portA.request.put(BRAMRequestBE{
          writeen: req.byte_en,
          responseOnWrite: True,
          address: truncate(req.addr >> 2),
          datain: req.data});
`endif
    endrule

    rule responseD;
`ifdef CACHE_ENABLE
        let x <- cache.getRespData();
`else 
        let x <- bram.portA.response.get();
`endif
        let req = dreq.first;
        dreq.deq();
        if (debug) $display("Get IResp ", fshow(req), fshow(x));
        req.data = x;
            rv_core.getDResp(req);
    endrule
  
  (* descending_urgency = "getBusResp, requestMMIO" *)
    rule requestMMIO;
        let req <- rv_core.getMMIOReq;
        if (debug) $display("Get MMIOReq", fshow(req));

        // Write MMIO (ignore sub-word MMIO store)
        else if (req.byte_en == 'hf) begin
            // Send out to bus
            if (req.addr[31:28] == 'he) begin
                busReqs.enq(CoreBusRequest{
                    addr: req.addr,
                    data: req.data,
                    write_enable: True
                });
            // putchar()
            end else if (req.addr ==  'hf000_fff0) begin
                // Writing to STDERR
                $fwrite(stderr, "%c", req.data[7:0]);
                $fflush(stderr);

            // exit()
            end else if (req.addr == 'hf000_fff8) begin
                $display("RAN CYCLES", cycle_count);
                if (ctr_enable) $display("RAN INSNS", rv_core.getInsnCount);

                // Exiting Simulation
                if (req.data == 0) begin
                    if (count_arrived == 0 ) $fdisplay(stderr, "  [0;32mPASS first thread [0m");
                    if (count_arrived == 1 ) $fdisplay(stderr, "  [0;32mPASS second thread [0m");
                end else begin
                    if (count_arrived == 0) $fdisplay(stderr, "  [0;31mFAIL first thread[0m (%0d)", req.data);
                    if (count_arrived == 1) $fdisplay(stderr, "  [0;31mFAIL second thread[0m (%0d)", req.data);
                end
                $fflush(stderr);
                count_arrived <= count_arrived + 1; 
            end
            mmioreq.enq(req);
        // Read MMIO
        end else if (req.byte_en == 'h0) begin
            if (req.addr[31:28] == 'he) begin
                busReqs.enq(CoreBusRequest{
                    addr: req.addr,
                    data: ?,
                    write_enable: False
                });
            end
        end else begin
            $fdisplay(stderr, "Illegal sub-word MMIO access");
            $finish;
        end
    endrule

    rule getBusResp;
        let busResp = busResps.first(); busResps.deq();
        mmioreq.enq(Mem { byte_en: 4'b0, addr: 32'b0, data: busResp});
    endrule

    rule responseMMIO;
        let req = mmioreq.first();
        mmioreq.deq();
        if (debug) $display("Put MMIOResp", fshow(req));
        rv_core.getMMIOResp(req);
    endrule


    method Bool getFinished();
        return count_arrived == 1;
    endmethod

    method ActionValue#(CoreBusRequest) getBusReq();
        let f = busReqs.first(); busReqs.deq();
        return f;
    endmethod

    method Action putBusResp(Bit#(32) resp);
        busResps.enq(resp);
    endmethod
endmodule
