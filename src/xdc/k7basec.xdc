################################################################################
# Constraint file for the K7BaseC Board development board
################################################################################
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullup [current_design]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# Compress bitstream and configure for fast Flash programming
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

## Clock Signal
set_property -dict {PACKAGE_PIN G22 IOSTANDARD LVCMOS33} [get_ports {sys_clk_i}];
#create_clock -name sys_clk -period 20 [get_ports sys_clk_i]

set_property -dict {PACKAGE_PIN D26 IOSTANDARD LVCMOS33} [get_ports { resetn_i }];

################################################################################
## Buttons
set_property -dict {PACKAGE_PIN J26 IOSTANDARD LVCMOS33} [get_ports {usr_btn[0]}];
set_property -dict {PACKAGE_PIN E26 IOSTANDARD LVCMOS33} [get_ports {usr_btn[1]}];
set_property -dict {PACKAGE_PIN G26 IOSTANDARD LVCMOS33} [get_ports {usr_btn[2]}];
set_property -dict {PACKAGE_PIN H26 IOSTANDARD LVCMOS33} [get_ports {usr_btn[3]}];

## UART
set_property -dict {PACKAGE_PIN B20 IOSTANDARD LVCMOS33} [get_ports {uart_rx}];
set_property -dict {PACKAGE_PIN C22 IOSTANDARD LVCMOS33} [get_ports {uart_tx}];

## LEDs
set_property -dict {PACKAGE_PIN A23 IOSTANDARD LVCMOS33} [get_ports {usr_led[0]}];
set_property -dict {PACKAGE_PIN A24 IOSTANDARD LVCMOS33} [get_ports {usr_led[1]}];
set_property -dict {PACKAGE_PIN D23 IOSTANDARD LVCMOS33} [get_ports {usr_led[2]}];
set_property -dict {PACKAGE_PIN D24 IOSTANDARD LVCMOS33} [get_ports {usr_led[3]}];
#set_property -dict {PACKAGE_PIN C26 IOSTANDARD LVCMOS33} [get_ports {usr_led[4]}];
#set_property -dict {PACKAGE_PIN D24 IOSTANDARD LVCMOS33} [get_ports {usr_led[5]}];
#set_property -dict {PACKAGE_PIN D25 IOSTANDARD LVCMOS33} [get_ports {usr_led[6]}];
#set_property -dict {PACKAGE_PIN E25 IOSTANDARD LVCMOS33} [get_ports {usr_led[7]}];

## SD Card (SPI)
#set_property -dict { PACKAGE_PIN E23 IOSTANDARD LVCMOS33 } [get_ports { sdio_d01 }];
set_property -dict { PACKAGE_PIN F23 IOSTANDARD LVCMOS33 } [get_ports { spi_miso }]; # sdio_d00
set_property -dict { PACKAGE_PIN G24 IOSTANDARD LVCMOS33 } [get_ports { spi_sck }];  # sdio_clk
set_property -dict { PACKAGE_PIN G25 IOSTANDARD LVCMOS33 } [get_ports { spi_mosi }]; # sdio_cmd
set_property -dict { PACKAGE_PIN F24 IOSTANDARD LVCMOS33 } [get_ports { spi_ss }];   # sdio_d03
#set_property -dict { PACKAGE_PIN F25 IOSTANDARD LVCMOS33 } [get_ports { sdio_d02 }];

## I2C (OLED)
#set_property -dict { PACKAGE_PIN J24 IOSTANDARD LVCMOS33 } [get_ports { i2c_scl }];
#set_property -dict { PACKAGE_PIN J25 IOSTANDARD LVCMOS33 } [get_ports { i2c_sda }];
#set_property -dict { PACKAGE_PIN H22 IOSTANDARD LVCMOS33 } [get_ports { oled_dc }];
#set_property -dict { PACKAGE_PIN J21 IOSTANDARD LVCMOS33 } [get_ports { oled_rst }];

## HDMI2 (output)
#set_property -dict { PACKAGE_PIN G17 IOSTANDARD TMDS_33 } [get_ports { tmds_data_p[2] }];
#set_property -dict { PACKAGE_PIN E15 IOSTANDARD TMDS_33 } [get_ports { tmds_data_p[1] }];
#set_property -dict { PACKAGE_PIN J15 IOSTANDARD TMDS_33 } [get_ports { tmds_data_p[0] }];
#set_property -dict { PACKAGE_PIN F17  IOSTANDARD TMDS_33 } [get_ports { tmds_clk_p     }];
#set_property -dict { PACKAGE_PIN G19 IOSTANDARD TMDS_33 } [get_ports { tmds_data_n[2] }];
#set_property -dict { PACKAGE_PIN H17 IOSTANDARD TMDS_33 } [get_ports { tmds_data_n[1] }];
#set_property -dict { PACKAGE_PIN D19 IOSTANDARD TMDS_33 } [get_ports { tmds_data_n[0] }];
#set_property -dict { PACKAGE_PIN E18 IOSTANDARD TMDS_33 } [get_ports { tmds_clk_n     }];
