set_property IOSTANDARD LVCMOS33 [get_ports ENET0_GMII_RX_CLK_0]
set_property IOSTANDARD LVCMOS33 [get_ports ENET0_GMII_TX_CLK_0]
set_property IOSTANDARD LVCMOS33 [get_ports {ENET0_GMII_RXD[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ENET0_GMII_RXD[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ENET0_GMII_RXD[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ENET0_GMII_RXD[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ENET0_GMII_TX_EN_0[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ENET0_GMII_TXD[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ENET0_GMII_TXD[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ENET0_GMII_TXD[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ENET0_GMII_TXD[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports ENET0_GMII_RX_DV_0]
set_property IOSTANDARD LVCMOS33 [get_ports MDIO_ETHERNET_0_0_mdc]
set_property IOSTANDARD LVCMOS33 [get_ports MDIO_ETHERNET_0_0_mdio_io]
set_property PACKAGE_PIN U14 [get_ports ENET0_GMII_RX_CLK_0]
set_property PACKAGE_PIN U15 [get_ports ENET0_GMII_TX_CLK_0]
set_property PACKAGE_PIN W19 [get_ports {ENET0_GMII_TX_EN_0[0]}]
set_property PACKAGE_PIN W18 [get_ports {ENET0_GMII_TXD[0]}]
set_property PACKAGE_PIN Y18 [get_ports {ENET0_GMII_TXD[1]}]
set_property PACKAGE_PIN V18 [get_ports {ENET0_GMII_TXD[2]}]
set_property PACKAGE_PIN Y19 [get_ports {ENET0_GMII_TXD[3]}]
set_property PACKAGE_PIN Y16 [get_ports {ENET0_GMII_RXD[0]}]
set_property PACKAGE_PIN V16 [get_ports {ENET0_GMII_RXD[1]}]
set_property PACKAGE_PIN V17 [get_ports {ENET0_GMII_RXD[2]}]
set_property PACKAGE_PIN Y17 [get_ports {ENET0_GMII_RXD[3]}]
set_property PACKAGE_PIN W16 [get_ports ENET0_GMII_RX_DV_0]
set_property PACKAGE_PIN W15 [get_ports MDIO_ETHERNET_0_0_mdc]
set_property PACKAGE_PIN Y14 [get_ports MDIO_ETHERNET_0_0_mdio_io]
#set_property -dict { PACKAGE_PIN E19   IOSTANDARD LVCMOS33  } [get_ports { led_0 }];
#set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33  } [get_ports { led2_0 }];
set_property -dict { PACKAGE_PIN P18   IOSTANDARD LVCMOS33  } [get_ports { uart_rx_0 }];
set_property -dict { PACKAGE_PIN M17   IOSTANDARD LVCMOS33  } [get_ports { uart_tx_0 }];
set_property -dict { PACKAGE_PIN U20   IOSTANDARD LVCMOS33  } [get_ports { rst_button_n }];

set_property -dict { PACKAGE_PIN H18   IOSTANDARD LVCMOS33  } [get_ports { led_high_0 }];
set_property -dict { PACKAGE_PIN K17   IOSTANDARD LVCMOS33  } [get_ports { led_pulse_0 }];
set_property -dict { PACKAGE_PIN E19   IOSTANDARD LVCMOS33  } [get_ports { led_low_0 }];