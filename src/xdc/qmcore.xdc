################################################################################
# Constraint file for the QMTech Core Board development board
################################################################################

# Compress bitstream and configure for fast Flash programming
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]

## Clock Signal
set_property -dict {PACKAGE_PIN F22 IOSTANDARD LVCMOS33} [get_ports {sys_clk_i}];
#create_clock -name sys_clk -period 20 [get_ports sys_clk_i]

################################################################################
## Buttons
set_property -dict {PACKAGE_PIN AF9  IOSTANDARD LVCMOS18} [get_ports {usr_btn[0]}];
set_property -dict {PACKAGE_PIN AF10 IOSTANDARD LVCMOS18} [get_ports {usr_btn[1]}];
#set_property -dict {PACKAGE_PIN AF13 IOSTANDARD LVCMOS18} [get_ports {usr_btn[2]}]; # dummy
#set_property -dict {PACKAGE_PIN AE13 IOSTANDARD LVCMOS18} [get_ports {usr_btn[3]}]; # dummy

## UART
set_property -dict {PACKAGE_PIN N26 IOSTANDARD LVCMOS33} [get_ports {uart_rx}];
set_property -dict {PACKAGE_PIN P23 IOSTANDARD LVCMOS33} [get_ports {uart_tx}];

## LEDs
set_property -dict {PACKAGE_PIN J26 IOSTANDARD LVCMOS33} [get_ports {usr_led[0]}];
set_property -dict {PACKAGE_PIN H26 IOSTANDARD LVCMOS33} [get_ports {usr_led[1]}];
#set_property -dict {PACKAGE_PIN H21 IOSTANDARD LVCMOS33} [get_ports {usr_led[2]}]; # dummy
#set_property -dict {PACKAGE_PIN G21 IOSTANDARD LVCMOS33} [get_ports {usr_led[3]}]; # dummy

## SD Card (SPI)
#set_property -dict { PACKAGE_PIN W21 IOSTANDARD LVCMOS33 } [get_ports { sdio_d01 }];
set_property -dict { PACKAGE_PIN V21 IOSTANDARD LVCMOS33 } [get_ports { spi_miso }]; # sdio_d00
set_property -dict { PACKAGE_PIN AE23 IOSTANDARD LVCMOS33 } [get_ports { spi_sck }];  # sdio_clk
set_property -dict { PACKAGE_PIN AE22 IOSTANDARD LVCMOS33 } [get_ports { spi_mosi }]; # sdio_cmd
set_property -dict { PACKAGE_PIN AD21 IOSTANDARD LVCMOS33 } [get_ports { spi_ss }];   # sdio_d03
#set_property -dict { PACKAGE_PIN AF23 IOSTANDARD LVCMOS33 } [get_ports { sdio_d02 }];

## I2C
#set_property -dict { PACKAGE_PIN AD21 IOSTANDARD LVCMOS33 } [get_ports { i2c_scl }];
#set_property -dict { PACKAGE_PIN AE22 IOSTANDARD LVCMOS33 } [get_ports { i2c_sda }];

## Differential PMOD-HDMI w/o capacitors in the signal traces
#set_property -dict { PACKAGE_PIN E10 IOSTANDARD TMDS_33 } [get_ports { tmds_data_p[2] }];
#set_property -dict { PACKAGE_PIN B10 IOSTANDARD TMDS_33 } [get_ports { tmds_data_p[1] }];
#set_property -dict { PACKAGE_PIN C9  IOSTANDARD TMDS_33 } [get_ports { tmds_data_p[0] }];
#set_property -dict { PACKAGE_PIN A9  IOSTANDARD TMDS_33 } [get_ports { tmds_clk_p     }];
#set_property -dict { PACKAGE_PIN D10 IOSTANDARD TMDS_33 } [get_ports { tmds_data_n[2] }];
#set_property -dict { PACKAGE_PIN A10 IOSTANDARD TMDS_33 } [get_ports { tmds_data_n[1] }];
#set_property -dict { PACKAGE_PIN A9  IOSTANDARD TMDS_33 } [get_ports { tmds_data_n[0] }];
#set_property -dict { PACKAGE_PIN A8  IOSTANDARD TMDS_33 } [get_ports { tmds_clk_n     }];

## 90-degree PMOD-HDMI w/o capacitors in the signal traces
#set_property -dict { PACKAGE_PIN E25 IOSTANDARD LVCMOS33 } [get_ports { tmds_data_p[1] }];
#set_property -dict { PACKAGE_PIN F25 IOSTANDARD LVCMOS33 } [get_ports { tmds_data_n[1] }];
#set_property -dict { PACKAGE_PIN B25 IOSTANDARD LVCMOS33 } [get_ports { tmds_clk_p     }];
#set_property -dict { PACKAGE_PIN D26 IOSTANDARD LVCMOS33 } [get_ports { tmds_clk_n     }];
#set_property -dict { PACKAGE_PIN D25 IOSTANDARD LVCMOS33 } [get_ports { tmds_data_p[2] }];
#set_property -dict { PACKAGE_PIN E26 IOSTANDARD LVCMOS33 } [get_ports { tmds_data_n[2] }];
#set_property -dict { PACKAGE_PIN B26 IOSTANDARD LVCMOS33 } [get_ports { tmds_data_p[0] }];
#set_property -dict { PACKAGE_PIN C26 IOSTANDARD LVCMOS33 } [get_ports { tmds_data_n[0] }];

## Qmcore HDMI
#set_property -dict { PACKAGE_PIN C26 IOSTANDARD LVCMOS33 } [get_ports { tmds_data_p[1] }];
#set_property -dict { PACKAGE_PIN D26 IOSTANDARD LVCMOS33 } [get_ports { tmds_data_n[1] }];
#set_property -dict { PACKAGE_PIN B26 IOSTANDARD LVCMOS33 } [get_ports { tmds_clk_p     }];
#set_property -dict { PACKAGE_PIN B25 IOSTANDARD LVCMOS33 } [get_ports { tmds_clk_n     }];
#set_property -dict { PACKAGE_PIN E26 IOSTANDARD LVCMOS33 } [get_ports { tmds_data_p[2] }];
#set_property -dict { PACKAGE_PIN F25 IOSTANDARD LVCMOS33 } [get_ports { tmds_data_n[2] }];
#set_property -dict { PACKAGE_PIN D25 IOSTANDARD LVCMOS33 } [get_ports { tmds_data_p[0] }];
#set_property -dict { PACKAGE_PIN E25 IOSTANDARD LVCMOS33 } [get_ports { tmds_data_n[0] }];
