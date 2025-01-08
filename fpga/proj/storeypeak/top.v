`default_nettype none
module top			    ( input wire         clock12MHz,
                                             clock50MHz,
                                             nReset,
                          input wire         RxD,
                          output wire        TxD,

                    
                          output wire [4:0] leds
                           );


///////////////////////////////
// Clock & reset generation //
/////////////////////////////

  reg[4:0] s_resetCountReg;
  wire     s_pllLocked;

  wire 	   s_systemClock;
  wire     s_systemReset = ~s_resetCountReg[4];  

  always @(posedge s_systemClock or negedge s_pllLocked)
    if (s_pllLocked == 1'b0) s_resetCountReg <= 5'd0;
    else s_resetCountReg <= (s_resetCountReg[4] == 1'b0) ? s_resetCountReg + 5'd1 : s_resetCountReg;

  
	altpll	altpll_component (
				.areset (~nReset),
				.inclk ({1'b0,clock50MHz}),
				.clk (s_systemClock),
				.locked (s_pllLocked),
				.activeclock (),
				.clkbad (),
				.clkena ({6{1'b1}}),
				.clkloss (),
				.clkswitch (1'b0),
				.configupdate (1'b0),
				.enable0 (),
				.enable1 (),
				.extclk (),
				.extclkena ({4{1'b1}}),
				.fbin (1'b1),
				.fbmimicbidir (),
				.fbout (),
				.fref (),
				.icdrclk (),
				.pfdena (1'b1),
				.phasecounterselect ({4{1'b1}}),
				.phasedone (),
				.phasestep (1'b1),
				.phaseupdown (1'b1),
				.pllena (1'b1),
				.scanaclr (1'b0),
				.scanclk (1'b0),
				.scanclkena (1'b1),
				.scandata (1'b0),
				.scandataout (),
				.scandone (),
				.scanread (1'b0),
				.scanwrite (1'b0),
				.sclkout0 (),
				.sclkout1 (),
				.vcooverrange (),
				.vcounderrange ());
	defparam
		altpll_component.bandwidth_type = "AUTO",
		altpll_component.clk0_divide_by = 1,
		altpll_component.clk0_duty_cycle = 50,
		altpll_component.clk0_multiply_by = 1,
		altpll_component.clk0_phase_shift = "0",
		altpll_component.compensate_clock = "CLK0",
		altpll_component.inclk0_input_frequency = 83333,
		altpll_component.intended_device_family = "Cyclone IV E",
		altpll_component.lpm_hint = "CBX_MODULE_PREFIX=test",
		altpll_component.lpm_type = "altpll",
		altpll_component.operation_mode = "NORMAL",
		altpll_component.pll_type = "AUTO",
		altpll_component.port_activeclock = "PORT_UNUSED",
		altpll_component.port_areset = "PORT_USED",
		altpll_component.port_clkbad0 = "PORT_UNUSED",
		altpll_component.port_clkbad1 = "PORT_UNUSED",
		altpll_component.port_clkloss = "PORT_UNUSED",
		altpll_component.port_clkswitch = "PORT_UNUSED",
		altpll_component.port_configupdate = "PORT_UNUSED",
		altpll_component.port_fbin = "PORT_UNUSED",
		altpll_component.port_inclk0 = "PORT_USED",
		altpll_component.port_inclk1 = "PORT_UNUSED",
		altpll_component.port_locked = "PORT_USED",
		altpll_component.port_pfdena = "PORT_UNUSED",
		altpll_component.port_phasecounterselect = "PORT_UNUSED",
		altpll_component.port_phasedone = "PORT_UNUSED",
		altpll_component.port_phasestep = "PORT_UNUSED",
		altpll_component.port_phaseupdown = "PORT_UNUSED",
		altpll_component.port_pllena = "PORT_UNUSED",
		altpll_component.port_scanaclr = "PORT_UNUSED",
		altpll_component.port_scanclk = "PORT_UNUSED",
		altpll_component.port_scanclkena = "PORT_UNUSED",
		altpll_component.port_scandata = "PORT_UNUSED",
		altpll_component.port_scandataout = "PORT_UNUSED",
		altpll_component.port_scandone = "PORT_UNUSED",
		altpll_component.port_scanread = "PORT_UNUSED",
		altpll_component.port_scanwrite = "PORT_UNUSED",
		altpll_component.port_clk0 = "PORT_USED",
		altpll_component.port_clk1 = "PORT_UNUSED",
		altpll_component.port_clk2 = "PORT_UNUSED",
		altpll_component.port_clk3 = "PORT_UNUSED",
		altpll_component.port_clk4 = "PORT_UNUSED",
		altpll_component.port_clk5 = "PORT_UNUSED",
		altpll_component.port_clkena0 = "PORT_UNUSED",
		altpll_component.port_clkena1 = "PORT_UNUSED",
		altpll_component.port_clkena2 = "PORT_UNUSED",
		altpll_component.port_clkena3 = "PORT_UNUSED",
		altpll_component.port_clkena4 = "PORT_UNUSED",
		altpll_component.port_clkena5 = "PORT_UNUSED",
		altpll_component.port_extclk0 = "PORT_UNUSED",
		altpll_component.port_extclk1 = "PORT_UNUSED",
		altpll_component.port_extclk2 = "PORT_UNUSED",
		altpll_component.port_extclk3 = "PORT_UNUSED",
		altpll_component.self_reset_on_loss_lock = "OFF",
		altpll_component.width_clock = 5;
		

/////////////////////////
// Instantiate system //
///////////////////////

CoreWrapper iCORE (
	.clk(s_systemClock),
	.rst(s_systemReset),
	.uart_tx(TxD),
	.uart_rx(RxD),
	.finished(),
	.leds(leds)
);
endmodule
`default_nettype wire



`default_nettype none

module otma_bringup (
    // Clocks
    input           CLK_125M,
    input           CLK_PCIE1,
	 
    input           CLK_PCIE2,

    // I2C
    inout           I2C_IDT_SCL,
    inout           I2C_IDT_SDA,

    inout           I2C_QSFP0_SCL,
    inout           I2C_QSFP0_SDA,

    inout           I2C_QSFP1_SCL,
    inout           I2C_QSFP1_SDA,

    inout           I2C_MON_SCL,
    inout           I2C_MON_SDA,

    // DDR3
    output [15:0]   memory_mem_a,
    output [ 2:0]   memory_mem_ba,
    output [ 0:0]   memory_mem_ck,
    output [ 0:0]   memory_mem_ck_n,
    output [ 0:0]   memory_mem_cke,
    output [ 0:0]   memory_mem_cs_n,
    output [ 8:0]   memory_mem_dm,
    output [ 0:0]   memory_mem_ras_n,
    output [ 0:0]   memory_mem_cas_n,
    output [ 0:0]   memory_mem_we_n,
    output          memory_mem_reset_n,
    inout  [71:0]   memory_mem_dq,
    inout  [ 8:0]   memory_mem_dqs,
    inout  [ 8:0]   memory_mem_dqs_n,
    output [ 0:0]   memory_mem_odt,
    input           oct_rzqin,

    // QSFP0
    // input  [3:0]    XCVR_QSFP0_RX,
    // output [3:0]    XCVR_QSFP0_TX,

    // QSFP1
    // input  [3:0]    XCVR_QSFP1_RX,
    // output [3:0]    XCVR_QSFP1_TX,

    // PCIe 1
    input           PCIE1_PERSTN,
    input  [ 7:0]   PCIE1_SERIAL_RX,
    output [ 7:0]   PCIE1_SERIAL_TX,

    // PCIe 2
    input           PCIE2_PERSTN,
    input  [ 7:0]   PCIE2_SERIAL_RX,
    output [ 7:0]   PCIE2_SERIAL_TX,

    // LED
    output [7:0]    LEDS
);


//==============================================================================
// clocks

wire clk_125_int;  // generated by Qsys

//==============================================================================
// blinky

wire [7:0] ptr;

reg		[7:0]		onchip_memory_s2_address = 0;
reg					onchip_memory_s2_chipselect = 0;
reg					onchip_memory_s2_clken = 0;
reg					onchip_memory_s2_write = 0;
wire     [128:0]	    onchip_memory_s2_readdata;
reg		[128:0]	    onchip_memory_s2_writedata = 0;
reg		[15:0]		onchip_memory_s2_byteenable = 0;

always @(posedge clk_125_int)
begin 
    onchip_memory_s2_address <= ptr;
    onchip_memory_s2_chipselect <= 1;
    onchip_memory_s2_clken <= 1;
    onchip_memory_s2_write <= 0;
    onchip_memory_s2_writedata <= 0;
    onchip_memory_s2_byteenable <= 255;
end

assign LEDS = onchip_memory_s2_readdata[7:0];

//==============================================================================
// I2C

wire i2c_idt_osc_sda_oe;
wire i2c_idt_osc_scl_oe;

assign I2C_IDT_SDA = i2c_idt_osc_sda_oe ? 1'b0 : 1'bz;
assign I2C_IDT_SCL = i2c_idt_osc_scl_oe ? 1'b0 : 1'bz;

wire i2c_qsfp0_sda_oe;
wire i2c_qsfp0_scl_oe;

assign I2C_QSFP0_SDA = i2c_qsfp0_sda_oe ? 1'b0 : 1'bz;
assign I2C_QSFP0_SCL = i2c_qsfp0_scl_oe ? 1'b0 : 1'bz;

wire i2c_qsfp1_sda_oe;
wire i2c_qsfp1_scl_oe;

assign I2C_QSFP1_SDA = i2c_qsfp1_sda_oe ? 1'b0 : 1'bz;
assign I2C_QSFP1_SCL = i2c_qsfp1_scl_oe ? 1'b0 : 1'bz;

wire i2c_mon_sda_oe;
wire i2c_mon_scl_oe;

assign I2C_MON_SDA = i2c_mon_sda_oe ? 1'b0 : 1'bz;
assign I2C_MON_SCL = i2c_mon_scl_oe ? 1'b0 : 1'bz;


//==============================================================================
// DDR3

wire ddr3_mem_status_local_init_done;
wire ddr3_mem_status_local_cal_success;
wire ddr3_mem_status_local_cal_fail;

// assign LEDS[6] = ddr3_mem_status_local_init_done;
// assign LEDS[5] = ddr3_mem_status_local_cal_success;
// assign LEDS[4] = ddr3_mem_status_local_cal_fail;

//==============================================================================
// PCIe

wire [31:0] pcie_test_in;
assign pcie_test_in[0] = 1'b0;
assign pcie_test_in[4:1] = 4'b1000;
assign pcie_test_in[5] = 1'b0;
assign pcie_test_in[31:6] = 26'h2;

wire pcie_cpu_npor;

//==============================================================================
// qsys

system inst_system (
    .clk_clk                            ( CLK_125M                              ),
    .clk_125_out_out_clk_clk            ( clk_125_int ),
    .reset_reset_n                      ( 1'b1                                  ),
    .led_dbg_export                     (                             ),
    .cpu_pcie_npor_export               ( pcie_cpu_npor                         ),
    .i2c_idt_osc_sda_in                 ( I2C_IDT_SDA                           ),
    .i2c_idt_osc_scl_in                 ( I2C_IDT_SCL                           ),
    .i2c_idt_osc_sda_oe                 ( i2c_idt_osc_sda_oe                    ),
    .i2c_idt_osc_scl_oe                 ( i2c_idt_osc_scl_oe                    ),
    .i2c_qsfp_0_sda_in                  ( I2C_QSFP0_SDA                         ),
    .i2c_qsfp_0_scl_in                  ( I2C_QSFP0_SCL                         ),
    .i2c_qsfp_0_sda_oe                  ( i2c_qsfp0_sda_oe                      ),
    .i2c_qsfp_0_scl_oe                  ( i2c_qsfp0_scl_oe                      ),
    .i2c_qsfp_1_sda_in                  ( I2C_QSFP1_SDA                         ),
    .i2c_qsfp_1_scl_in                  ( I2C_QSFP1_SCL                         ),
    .i2c_qsfp_1_sda_oe                  ( i2c_qsfp1_sda_oe                      ),
    .i2c_qsfp_1_scl_oe                  ( i2c_qsfp1_scl_oe                      ),
    .i2c_mon_sda_in                     ( I2C_MON_SDA                           ),
    .i2c_mon_scl_in                     ( I2C_MON_SCL                           ),
    .i2c_mon_sda_oe                     ( i2c_mon_sda_oe                        ),
    .i2c_mon_scl_oe                     ( i2c_mon_scl_oe                        ),
    .ddr3_mem_status_local_init_done    ( ddr3_mem_status_local_init_done       ),
    .ddr3_mem_status_local_cal_success  ( ddr3_mem_status_local_cal_success     ),
    .ddr3_mem_status_local_cal_fail     ( ddr3_mem_status_local_cal_fail        ),
    .memory_mem_a                       ( memory_mem_a                          ),
    .memory_mem_ba                      ( memory_mem_ba                         ),
    .memory_mem_ck                      ( memory_mem_ck                         ),
    .memory_mem_ck_n                    ( memory_mem_ck_n                       ),
    .memory_mem_cke                     ( memory_mem_cke                        ),
    .memory_mem_cs_n                    ( memory_mem_cs_n                       ),
    .memory_mem_dm                      ( memory_mem_dm                         ),
    .memory_mem_ras_n                   ( memory_mem_ras_n                      ),
    .memory_mem_cas_n                   ( memory_mem_cas_n                      ),
    .memory_mem_we_n                    ( memory_mem_we_n                       ),
    .memory_mem_reset_n                 ( memory_mem_reset_n                    ),
    .memory_mem_dq                      ( memory_mem_dq                         ),
    .memory_mem_dqs                     ( memory_mem_dqs                        ),
    .memory_mem_dqs_n                   ( memory_mem_dqs_n                      ),
    .memory_mem_odt                     ( memory_mem_odt                        ),
    .oct_rzqin                          ( oct_rzqin                             ),
    .pcie1_hip_ctrl_test_in             ( pcie_test_in                          ),
    .pcie1_hip_ctrl_simu_mode_pipe      (                                       ),
    .pcie1_hip_serial_rx_in0            ( PCIE1_SERIAL_RX[0]                    ),
    .pcie1_hip_serial_rx_in1            ( PCIE1_SERIAL_RX[1]                    ),
    .pcie1_hip_serial_rx_in2            ( PCIE1_SERIAL_RX[2]                    ),
    .pcie1_hip_serial_rx_in3            ( PCIE1_SERIAL_RX[3]                    ),
    .pcie1_hip_serial_rx_in4            ( PCIE1_SERIAL_RX[4]                    ),
    .pcie1_hip_serial_rx_in5            ( PCIE1_SERIAL_RX[5]                    ),
    .pcie1_hip_serial_rx_in6            ( PCIE1_SERIAL_RX[6]                    ),
    .pcie1_hip_serial_rx_in7            ( PCIE1_SERIAL_RX[7]                    ),
    .pcie1_hip_serial_tx_out0           ( PCIE1_SERIAL_TX[0]                    ),
    .pcie1_hip_serial_tx_out1           ( PCIE1_SERIAL_TX[1]                    ),
    .pcie1_hip_serial_tx_out2           ( PCIE1_SERIAL_TX[2]                    ),
    .pcie1_hip_serial_tx_out3           ( PCIE1_SERIAL_TX[3]                    ),
    .pcie1_hip_serial_tx_out4           ( PCIE1_SERIAL_TX[4]                    ),
    .pcie1_hip_serial_tx_out5           ( PCIE1_SERIAL_TX[5]                    ),
    .pcie1_hip_serial_tx_out6           ( PCIE1_SERIAL_TX[6]                    ),
    .pcie1_hip_serial_tx_out7           ( PCIE1_SERIAL_TX[7]                    ),
    .pio_pcie_external_connection_export( ptr ),
    .pcie1_npor_npor                    ( pcie_cpu_npor                         ),
    .pcie1_npor_pin_perst               ( PCIE1_PERSTN                          ),
    .pcie1_refclk_clk                   ( CLK_PCIE1                             ),
    .pcie2_hip_ctrl_test_in             ( pcie_test_in                          ),
    .pcie2_hip_ctrl_simu_mode_pipe      (                                       ),
    .pcie2_hip_serial_rx_in0            ( PCIE2_SERIAL_RX[0]                    ),
    .pcie2_hip_serial_rx_in1            ( PCIE2_SERIAL_RX[1]                    ),
    .pcie2_hip_serial_rx_in2            ( PCIE2_SERIAL_RX[2]                    ),
    .pcie2_hip_serial_rx_in3            ( PCIE2_SERIAL_RX[3]                    ),
    .pcie2_hip_serial_rx_in4            ( PCIE2_SERIAL_RX[4]                    ),
    .pcie2_hip_serial_rx_in5            ( PCIE2_SERIAL_RX[5]                    ),
    .pcie2_hip_serial_rx_in6            ( PCIE2_SERIAL_RX[6]                    ),
    .pcie2_hip_serial_rx_in7            ( PCIE2_SERIAL_RX[7]                    ),
    .pcie2_hip_serial_tx_out0           ( PCIE2_SERIAL_TX[0]                    ),
    .pcie2_hip_serial_tx_out1           ( PCIE2_SERIAL_TX[1]                    ),
    .pcie2_hip_serial_tx_out2           ( PCIE2_SERIAL_TX[2]                    ),
    .pcie2_hip_serial_tx_out3           ( PCIE2_SERIAL_TX[3]                    ),
    .pcie2_hip_serial_tx_out4           ( PCIE2_SERIAL_TX[4]                    ),
    .pcie2_hip_serial_tx_out5           ( PCIE2_SERIAL_TX[5]                    ),
    .pcie2_hip_serial_tx_out6           ( PCIE2_SERIAL_TX[6]                    ),
    .pcie2_hip_serial_tx_out7           ( PCIE2_SERIAL_TX[7]                    ),
    .pcie2_led_dbg_export               (                              ),
    .pcie2_npor_npor                    ( pcie_cpu_npor                         ),
    .pcie2_npor_pin_perst               ( PCIE2_PERSTN                          ),
    .pcie2_refclk_clk                   ( CLK_PCIE2                             ),
    .onchip_memory_s2_address      (onchip_memory_s2_address),
    .onchip_memory_s2_chipselect   (onchip_memory_s2_chipselect),
    .onchip_memory_s2_clken        (onchip_memory_s2_clken),
    .onchip_memory_s2_write        (onchip_memory_s2_write),
    .onchip_memory_s2_readdata     (onchip_memory_s2_readdata),
    .onchip_memory_s2_writedata    (onchip_memory_s2_writedata),
    .onchip_memory_s2_byteenable   (onchip_memory_s2_byteenable),
    .onchip_memory_reset2_reset      (1'b0),
    .onchip_memory_clk2_clk(clk_125_int)
);

endmodule

`default_nettype wire