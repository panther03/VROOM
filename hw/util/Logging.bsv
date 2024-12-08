`ifdef DEBUG_ENABLE
`define DEBUG_PRINT(a) $display a;
`else
`define DEBUG_PRINT(a) 
`endif 