## This file is a general .xdc for the ARTY Rev. A
## To use it in a project:
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project


# Clock signal

set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports clk_i]
#create_clock -name clk_i -period 10.000 -waveform {0.000 5.000} [get_ports clk_i];
#derive_pll_clocks
#derive_clock_uncertainty
#create_generated_clock -period 24.000 -waveform {0.000 12.000} -name clk -source [get_pins clk_wiz_0/clk_in1] [get_nets clk]
#create_generated_clock -period  6.000 -waveform {0.000  3.000} -name clk_166M -source [get_pins clk_wiz_0/clk_in1] [get_nets clk_166M]
#create_generated_clock -period  5.000 -waveform {0.000  2.500} -name clk_200M -source [get_pins clk_wiz_0/clk_in1] [get_nets clk_200M]

set_property -dict {PACKAGE_PIN C2 IOSTANDARD LVCMOS33} [get_ports resetn_i]

#Switches

#set_property -dict { PACKAGE_PIN A8  IOSTANDARD LVCMOS33 } [get_ports { usr_sw[0] }]; #IO_L12N_T1_MRCC_16 Sch=sw[0]
#set_property -dict { PACKAGE_PIN C11 IOSTANDARD LVCMOS33 } [get_ports { usr_sw[1] }]; #IO_L13P_T2_MRCC_16 Sch=sw[1]
#set_property -dict { PACKAGE_PIN C10 IOSTANDARD LVCMOS33 } [get_ports { usr_sw[2] }]; #IO_L13N_T2_MRCC_16 Sch=sw[2]
#set_property -dict { PACKAGE_PIN A10 IOSTANDARD LVCMOS33 } [get_ports { usr_sw[3] }]; #IO_L14P_T2_SRCC_16 Sch=sw[3]


# LEDs

set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS33} [get_ports {usr_led[0]}]
set_property -dict {PACKAGE_PIN J5 IOSTANDARD LVCMOS33} [get_ports {usr_led[1]}]
set_property -dict {PACKAGE_PIN T9 IOSTANDARD LVCMOS33} [get_ports {usr_led[2]}]
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {usr_led[3]}]
#set_property -dict { PACKAGE_PIN E1  IOSTANDARD LVCMOS33 } [get_ports { rgb_led[0] }]; #IO_L18N_T2_35 Sch=led0_b
#set_property -dict { PACKAGE_PIN F6  IOSTANDARD LVCMOS33 } [get_ports { rgb_led[1] }]; #IO_L19N_T3_VREF_35 Sch=led0_g
#set_property -dict { PACKAGE_PIN G6  IOSTANDARD LVCMOS33 } [get_ports { rgb_led[2] }]; #IO_L19P_T3_35 Sch=led0_r
#set_property -dict { PACKAGE_PIN G4  IOSTANDARD LVCMOS33 } [get_ports { rgb_led_b[1] }]; #IO_L20P_T3_35 Sch=led1_b
#set_property -dict { PACKAGE_PIN J4  IOSTANDARD LVCMOS33 } [get_ports { rgb_led_g[1] }]; #IO_L21P_T3_DQS_35 Sch=led1_g
#set_property -dict { PACKAGE_PIN G3  IOSTANDARD LVCMOS33 } [get_ports { rgb_led_r[1] }]; #IO_L20N_T3_35 Sch=led1_r
#set_property -dict { PACKAGE_PIN H4  IOSTANDARD LVCMOS33 } [get_ports { rgb_led_b[2] }]; #IO_L21N_T3_DQS_35 Sch=led2_b
#set_property -dict { PACKAGE_PIN J2  IOSTANDARD LVCMOS33 } [get_ports { rgb_led_g[2] }]; #IO_L22N_T3_35 Sch=led2_g
#set_property -dict { PACKAGE_PIN J3  IOSTANDARD LVCMOS33 } [get_ports { rgb_led_r[2] }]; #IO_L22P_T3_35 Sch=led2_r
#set_property -dict { PACKAGE_PIN K2  IOSTANDARD LVCMOS33 } [get_ports { rgb_led_b[3] }]; #IO_L23P_T3_35 Sch=led3_b
#set_property -dict { PACKAGE_PIN H6  IOSTANDARD LVCMOS33 } [get_ports { rgb_led_g[3] }]; #IO_L24P_T3_35 Sch=led3_g
#set_property -dict { PACKAGE_PIN K1  IOSTANDARD LVCMOS33 } [get_ports { rgb_led_r[3] }]; #IO_L23N_T3_35 Sch=led3_r


#Buttons

set_property -dict {PACKAGE_PIN D9 IOSTANDARD LVCMOS33} [get_ports {usr_btn[0]}]
set_property -dict {PACKAGE_PIN C9 IOSTANDARD LVCMOS33} [get_ports {usr_btn[1]}]
set_property -dict {PACKAGE_PIN B9 IOSTANDARD LVCMOS33} [get_ports {usr_btn[2]}]
set_property -dict {PACKAGE_PIN B8 IOSTANDARD LVCMOS33} [get_ports {usr_btn[3]}]

#UART
set_property -dict {PACKAGE_PIN D10 IOSTANDARD LVCMOS33} [get_ports uart_tx]
set_property -dict {PACKAGE_PIN A9 IOSTANDARD LVCMOS33} [get_ports uart_rx]

##ChipKit Digital I/O Low

#set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports { ck_io[0] }]; #IO_L16P_T2_CSI_B_14 Sch=ck_io[0]
#set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports { ck_io[1] }]; #IO_L18P_T2_A12_D28_14 Sch=ck_io[1]
#set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports { ck_io[2] }]; #IO_L8N_T1_D12_14 Sch=ck_io[2]
#set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } [get_ports { ck_io[3] }]; #IO_L19P_T3_A10_D26_14 Sch=ck_io[3]
#set_property -dict { PACKAGE_PIN R12 IOSTANDARD LVCMOS33 } [get_ports { ck_io[4] }]; #IO_L5P_T0_D06_14 Sch=ck_io[4]
#set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS33 } [get_ports { ck_io[5] }]; #IO_L14P_T2_SRCC_14 Sch=ck_io[5]
#set_property -dict { PACKAGE_PIN T15 IOSTANDARD LVCMOS33 } [get_ports { ck_io[6] }]; #IO_L14N_T2_SRCC_14 Sch=ck_io[6]
#set_property -dict { PACKAGE_PIN T16 IOSTANDARD LVCMOS33 } [get_ports { LCD_E }]; #IO_L15N_T2_DQS_DOUT_CSO_B_14 Sch=ck_io[7]
#set_property -dict { PACKAGE_PIN N15 IOSTANDARD LVCMOS33 } [get_ports { LCD_RW }]; #IO_L11P_T1_SRCC_14 Sch=ck_io[8]
#set_property -dict { PACKAGE_PIN M16 IOSTANDARD LVCMOS33 } [get_ports { LCD_RS }]; #IO_L10P_T1_D14_14 Sch=ck_io[9]
#set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports { LCD_D[3] }]; #IO_L18N_T2_A11_D27_14 Sch=ck_io[10]
#set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports { LCD_D[2] }]; #IO_L17N_T2_A13_D29_14 Sch=ck_io[11]
#set_property -dict { PACKAGE_PIN R17 IOSTANDARD LVCMOS33 } [get_ports { LCD_D[1] }]; #IO_L12N_T1_MRCC_14 Sch=ck_io[12]
#set_property -dict { PACKAGE_PIN P17 IOSTANDARD LVCMOS33 } [get_ports { LCD_D[0] }]; #IO_L12P_T1_MRCC_14 Sch=ck_io[13]

##ChipKit Digital I/O High

#set_property -dict { PACKAGE_PIN U11 IOSTANDARD LVCMOS33 } [get_ports { ck_io[26] }]; #IO_L19N_T3_A09_D25_VREF_14 Sch=ck_io[26]
#set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports { ck_io[27] }]; #IO_L16N_T2_A15_D31_14 Sch=ck_io[27]
#set_property -dict { PACKAGE_PIN M13 IOSTANDARD LVCMOS33 } [get_ports { VGA_HSYNC }]; #IO_L6N_T0_D08_VREF_14 Sch=ck_io[28]
#set_property -dict { PACKAGE_PIN R10 IOSTANDARD LVCMOS33 } [get_ports { VGA_VSYNC }]; #IO_25_14 Sch=ck_io[29]
#set_property -dict { PACKAGE_PIN R11 IOSTANDARD LVCMOS33 } [get_ports { VGA_GREEN[0] }]; #IO_0_14 Sch=ck_io[30]
#set_property -dict { PACKAGE_PIN R13 IOSTANDARD LVCMOS33 } [get_ports { VGA_GREEN[1] }]; #IO_L5N_T0_D07_14 Sch=ck_io[31]
#set_property -dict { PACKAGE_PIN R15 IOSTANDARD LVCMOS33 } [get_ports { VGA_GREEN[2] }]; #IO_L13N_T2_MRCC_14 Sch=ck_io[32]
#set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 } [get_ports { VGA_GREEN[3] }]; #IO_L13P_T2_MRCC_14 Sch=ck_io[33]
#set_property -dict { PACKAGE_PIN R16 IOSTANDARD LVCMOS33 } [get_ports { VGA_BLUE[0] }]; #IO_L15P_T2_DQS_RDWR_B_14 Sch=ck_io[34]
#set_property -dict { PACKAGE_PIN N16 IOSTANDARD LVCMOS33 } [get_ports { VGA_BLUE[1] }]; #IO_L11N_T1_SRCC_14 Sch=ck_io[35]
#set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports { VGA_BLUE[2] }]; #IO_L8P_T1_D11_14 Sch=ck_io[36]
#set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports { VGA_BLUE[3] }]; #IO_L17P_T2_A14_D30_14 Sch=ck_io[37]
#set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports { VGA_RED[0] }]; #IO_L7N_T1_D10_14 Sch=ck_io[38]
#set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports { VGA_RED[1] }]; #IO_L7P_T1_D09_14 Sch=ck_io[39]
#set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports { VGA_RED[2] }]; #IO_L9N_T1_DQS_D13_14 Sch=ck_io[40]
#set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports { VGA_RED[3] }]; #IO_L9P_T1_DQS_14 Sch=ck_io[41]

##Misc. ChipKit signals

#set_property -dict { PACKAGE_PIN M17   IOSTANDARD LVCMOS33 } [get_ports { ck_ioa }]; #IO_L10N_T1_D15_14 Sch=ck_ioa
#set_property -dict { PACKAGE_PIN C2    IOSTANDARD LVCMOS33 } [get_ports { ck_rst }]; #IO_L16P_T2_35 Sch=ck_rst

## ChipKit SPI

set_property -dict {PACKAGE_PIN F4 IOSTANDARD LVCMOS33} [get_ports spi_miso]
set_property -dict {PACKAGE_PIN D3 IOSTANDARD LVCMOS33} [get_ports spi_mosi]
set_property -dict {PACKAGE_PIN F3 IOSTANDARD LVCMOS33} [get_ports spi_sck]
set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVCMOS33} [get_ports spi_ss]
#set_property -dict { PACKAGE_PIN G1  IOSTANDARD LVCMOS33 } [get_ports { spi_miso }]; #IO_L17N_T2_35 Sch=ck_miso
#set_property -dict { PACKAGE_PIN H1  IOSTANDARD LVCMOS33 } [get_ports { spi_mosi }]; #IO_L17P_T2_35 Sch=ck_mosi
#set_property -dict { PACKAGE_PIN F1  IOSTANDARD LVCMOS33 } [get_ports { spi_sck }]; #IO_L18P_T2_35 Sch=ck_sck
#set_property -dict { PACKAGE_PIN C1  IOSTANDARD LVCMOS33 } [get_ports { spi_ss }]; #IO_L16N_T2_35 Sch=ck_ss


## ChipKit I2C

#set_property -dict { PACKAGE_PIN L18  PULLUP TRUE IOSTANDARD LVCMOS33 } [get_ports { i2c_scl }]; #IO_L4P_T0_D04_14 Sch=ck_scl
#set_property -dict { PACKAGE_PIN M18  PULLUP TRUE IOSTANDARD LVCMOS33 } [get_ports { i2c_sda }]; #IO_L4N_T0_D05_14 Sch=ck_sda
#set_property -dict { PACKAGE_PIN A14   IOSTANDARD LVCMOS33 } [get_ports { i2c_scl_pullup }]; #IO_L9N_T1_DQS_AD3N_15 Sch=scl_pup
#set_property -dict { PACKAGE_PIN A13   IOSTANDARD LVCMOS33 } [get_ports { i2c_sda_pullup }]; #IO_L9P_T1_DQS_AD3P_15 Sch=sda_pup


##SMSC Ethernet PHY

#set_property -dict { PACKAGE_PIN D17   IOSTANDARD LVCMOS33 } [get_ports { eth_col }]; #IO_L16N_T2_A27_15 Sch=eth_col
#set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { eth_crs }]; #IO_L15N_T2_DQS_ADV_B_15 Sch=eth_crs
#set_property -dict { PACKAGE_PIN F16   IOSTANDARD LVCMOS33 } [get_ports { eth_mdc }]; #IO_L14N_T2_SRCC_15 Sch=eth_mdc
#set_property -dict { PACKAGE_PIN K13   IOSTANDARD LVCMOS33 } [get_ports { eth_mdio }]; #IO_L17P_T2_A26_15 Sch=eth_mdio
#set_property -dict { PACKAGE_PIN G18   IOSTANDARD LVCMOS33 } [get_ports { eth_ref_clk }]; #IO_L22P_T3_A17_15 Sch=eth_ref_clk
#set_property -dict { PACKAGE_PIN C16   IOSTANDARD LVCMOS33 } [get_ports { eth_rstn }]; #IO_L20P_T3_A20_15 Sch=eth_rstn
#set_property -dict { PACKAGE_PIN F15   IOSTANDARD LVCMOS33 } [get_ports { eth_rx_clk }]; #IO_L14P_T2_SRCC_15 Sch=eth_rx_clk
#set_property -dict { PACKAGE_PIN G16   IOSTANDARD LVCMOS33 } [get_ports { eth_rx_dv }]; #IO_L13N_T2_MRCC_15 Sch=eth_rx_dv
#set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { eth_rxd[0] }]; #IO_L21N_T3_DQS_A18_15 Sch=eth_rxd[0]
#set_property -dict { PACKAGE_PIN E17   IOSTANDARD LVCMOS33 } [get_ports { eth_rxd[1] }]; #IO_L16P_T2_A28_15 Sch=eth_rxd[1]
#set_property -dict { PACKAGE_PIN E18   IOSTANDARD LVCMOS33 } [get_ports { eth_rxd[2] }]; #IO_L21P_T3_DQS_15 Sch=eth_rxd[2]
#set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports { eth_rxd[3] }]; #IO_L18N_T2_A23_15 Sch=eth_rxd[3]
#set_property -dict { PACKAGE_PIN C17   IOSTANDARD LVCMOS33 } [get_ports { eth_rxerr }]; #IO_L20N_T3_A19_15 Sch=eth_rxerr
#set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { eth_tx_clk }]; #IO_L13P_T2_MRCC_15 Sch=eth_tx_clk
#set_property -dict { PACKAGE_PIN H15   IOSTANDARD LVCMOS33 } [get_ports { eth_tx_en }]; #IO_L19N_T3_A21_VREF_15 Sch=eth_tx_en
#set_property -dict { PACKAGE_PIN H14   IOSTANDARD LVCMOS33 } [get_ports { eth_txd[0] }]; #IO_L15P_T2_DQS_15 Sch=eth_txd[0]
#set_property -dict { PACKAGE_PIN J14   IOSTANDARD LVCMOS33 } [get_ports { eth_txd[1] }]; #IO_L19P_T3_A22_15 Sch=eth_txd[1]
#set_property -dict { PACKAGE_PIN J13   IOSTANDARD LVCMOS33 } [get_ports { eth_txd[2] }]; #IO_L17N_T2_A25_15 Sch=eth_txd[2]
#set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { eth_txd[3] }]; #IO_L18P_T2_A24_15 Sch=eth_txd[3]


##Quad SPI Flash

#set_property -dict { PACKAGE_PIN L13   IOSTANDARD LVCMOS33 } [get_ports { qspi_cs }]; #IO_L6P_T0_FCS_B_14 Sch=qspi_cs
#set_property -dict { PACKAGE_PIN K17   IOSTANDARD LVCMOS33 } [get_ports { qspi_dq[0] }]; #IO_L1P_T0_D00_MOSI_14 Sch=qspi_dq[0]
#set_property -dict { PACKAGE_PIN K18   IOSTANDARD LVCMOS33 } [get_ports { qspi_dq[1] }]; #IO_L1N_T0_D01_DIN_14 Sch=qspi_dq[1]
#set_property -dict { PACKAGE_PIN L14   IOSTANDARD LVCMOS33 } [get_ports { qspi_dq[2] }]; #IO_L2P_T0_D02_14 Sch=qspi_dq[2]
#set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { qspi_dq[3] }]; #IO_L2N_T0_D03_14 Sch=qspi_dq[3]


##ChipKit Analog I/O (in Digital I/O mode)

#set_property -dict { PACKAGE_PIN F5 IOSTANDARD LVCMOS33 } [get_ports { ck_A[0] }]; # Sch=ck_A0
#set_property -dict { PACKAGE_PIN D8 IOSTANDARD LVCMOS33 } [get_ports { ck_A[1] }]; # Sch=ck_A1
#set_property -dict { PACKAGE_PIN C7 IOSTANDARD LVCMOS33 } [get_ports { ck_A[2] }]; # Sch=ck_A2
#set_property -dict { PACKAGE_PIN E7 IOSTANDARD LVCMOS33 } [get_ports { ck_A[3] }]; # Sch=ck_A3
#set_property -dict { PACKAGE_PIN D7 IOSTANDARD LVCMOS33 } [get_ports { ck_A[4] }]; # Sch=ck_A4
#set_property -dict { PACKAGE_PIN D5 IOSTANDARD LVCMOS33 } [get_ports { ck_A[5] }]; # Sch=ck_A5
#set_property -dict { PACKAGE_PIN B7 IOSTANDARD LVCMOS33 } [get_ports { ck_A[6] }]; # Sch=ck_A6
#set_property -dict { PACKAGE_PIN B6 IOSTANDARD LVCMOS33 } [get_ports { ck_A[7] }]; # Sch=ck_A7
#set_property -dict { PACKAGE_PIN E6 IOSTANDARD LVCMOS33 } [get_ports { ck_A[8] }]; # Sch=ck_A8
#set_property -dict { PACKAGE_PIN E5 IOSTANDARD LVCMOS33 } [get_ports { ck_A[9] }]; # Sch=ck_A9
#set_property -dict { PACKAGE_PIN A4 IOSTANDARD LVCMOS33 } [get_ports { ck_A[10] }]; # Sch=ck_A10
#set_property -dict { PACKAGE_PIN A3 IOSTANDARD LVCMOS33 } [get_ports { ck_A[11] }]; # Sch=ck_A11


##Power Analysis

#set_property -dict { PACKAGE_PIN A16   IOSTANDARD LVCMOS33 } [get_ports { sns0v_n[95] }]; #IO_L8N_T1_AD10N_15 Sch=sns0v_n[95]
#set_property -dict { PACKAGE_PIN A15   IOSTANDARD LVCMOS33 } [get_ports { sns0v_p[95] }]; #IO_L8P_T1_AD10P_15 Sch=sns0v_p[95]
#set_property -dict { PACKAGE_PIN F14   IOSTANDARD LVCMOS33 } [get_ports { sns5v_n[0] }]; #IO_L5N_T0_AD9N_15 Sch=sns5v_n[0]
#set_property -dict { PACKAGE_PIN F13   IOSTANDARD LVCMOS33 } [get_ports { sns5v_p[0] }]; #IO_L5P_T0_AD9P_15 Sch=sns5v_p[0]
#set_property -dict { PACKAGE_PIN C12   IOSTANDARD LVCMOS33 } [get_ports { vsns5v[0] }]; #IO_L3P_T0_DQS_AD1P_15 Sch=vsns5v[0]
#set_property -dict { PACKAGE_PIN B16   IOSTANDARD LVCMOS33 } [get_ports { vsnsvu }]; #IO_L7P_T1_AD2P_15 Sch=vsnsvu

set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]







connect_debug_port u_ila_0/probe0 [get_nets [list {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[0]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[1]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[2]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[3]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[4]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[5]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[6]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[7]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[8]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[9]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[10]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[11]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[12]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[13]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[14]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[15]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[16]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[17]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[18]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[19]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[20]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[21]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[22]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[23]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[24]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[25]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[26]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[27]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[28]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[29]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[30]} {genblk1[0].Aquila_SoC/RISCV_CORE/pcu_pc[31]}]]
connect_debug_port u_ila_0/probe5 [get_nets [list {genblk1[0].Aquila_SoC/M_DMEM_data_i[0]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[1]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[2]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[3]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[4]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[5]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[6]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[7]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[8]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[9]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[10]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[11]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[12]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[13]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[14]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[15]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[16]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[17]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[18]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[19]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[20]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[21]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[22]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[23]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[24]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[25]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[26]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[27]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[28]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[29]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[30]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[31]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[32]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[33]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[34]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[35]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[36]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[37]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[38]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[39]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[40]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[41]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[42]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[43]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[44]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[45]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[46]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[47]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[48]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[49]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[50]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[51]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[52]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[53]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[54]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[55]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[56]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[57]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[58]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[59]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[60]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[61]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[62]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[63]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[64]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[65]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[66]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[67]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[68]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[69]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[70]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[71]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[72]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[73]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[74]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[75]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[76]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[77]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[78]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[79]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[80]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[81]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[82]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[83]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[84]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[85]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[86]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[87]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[88]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[89]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[90]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[91]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[92]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[93]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[94]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[95]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[96]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[97]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[98]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[99]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[100]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[101]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[102]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[103]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[104]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[105]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[106]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[107]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[108]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[109]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[110]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[111]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[112]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[113]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[114]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[115]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[116]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[117]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[118]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[119]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[120]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[121]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[122]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[123]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[124]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[125]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[126]} {genblk1[0].Aquila_SoC/M_DMEM_data_i[127]}]]
connect_debug_port u_ila_0/probe6 [get_nets [list {genblk1[0].Aquila_SoC/M_IMEM_addr_o[4]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[5]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[6]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[7]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[8]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[9]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[10]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[11]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[12]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[13]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[14]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[15]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[16]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[17]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[18]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[19]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[20]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[21]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[22]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[23]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[24]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[25]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[26]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[27]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[28]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[29]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[30]} {genblk1[0].Aquila_SoC/M_IMEM_addr_o[31]}]]
connect_debug_port u_ila_0/probe9 [get_nets [list {genblk1[0].Aquila_SoC/M_IMEM_done_i}]]
connect_debug_port u_ila_0/probe10 [get_nets [list {genblk1[0].Aquila_SoC/M_IMEM_strobe_o}]]




connect_debug_port u_ila_0/probe1 [get_nets [list {L2_Cache/p0_cnt[0]} {L2_Cache/p0_cnt[1]} {L2_Cache/p0_cnt[2]} {L2_Cache/p0_cnt[3]} {L2_Cache/p0_cnt[4]} {L2_Cache/p0_cnt[5]} {L2_Cache/p0_cnt[6]} {L2_Cache/p0_cnt[7]} {L2_Cache/p0_cnt[8]} {L2_Cache/p0_cnt[9]} {L2_Cache/p0_cnt[10]} {L2_Cache/p0_cnt[11]} {L2_Cache/p0_cnt[12]} {L2_Cache/p0_cnt[13]} {L2_Cache/p0_cnt[14]} {L2_Cache/p0_cnt[15]}]]
connect_debug_port u_ila_0/probe2 [get_nets [list {L2_Cache/p0_same_cnt[0]} {L2_Cache/p0_same_cnt[1]} {L2_Cache/p0_same_cnt[2]} {L2_Cache/p0_same_cnt[3]} {L2_Cache/p0_same_cnt[4]} {L2_Cache/p0_same_cnt[5]} {L2_Cache/p0_same_cnt[6]} {L2_Cache/p0_same_cnt[7]} {L2_Cache/p0_same_cnt[8]} {L2_Cache/p0_same_cnt[9]} {L2_Cache/p0_same_cnt[10]} {L2_Cache/p0_same_cnt[11]} {L2_Cache/p0_same_cnt[12]} {L2_Cache/p0_same_cnt[13]} {L2_Cache/p0_same_cnt[14]} {L2_Cache/p0_same_cnt[15]}]]
connect_debug_port u_ila_0/probe3 [get_nets [list {L2_Cache/p1_cnt[0]} {L2_Cache/p1_cnt[1]} {L2_Cache/p1_cnt[2]} {L2_Cache/p1_cnt[3]} {L2_Cache/p1_cnt[4]} {L2_Cache/p1_cnt[5]} {L2_Cache/p1_cnt[6]} {L2_Cache/p1_cnt[7]} {L2_Cache/p1_cnt[8]} {L2_Cache/p1_cnt[9]} {L2_Cache/p1_cnt[10]} {L2_Cache/p1_cnt[11]} {L2_Cache/p1_cnt[12]} {L2_Cache/p1_cnt[13]} {L2_Cache/p1_cnt[14]} {L2_Cache/p1_cnt[15]}]]
connect_debug_port u_ila_0/probe4 [get_nets [list {L2_Cache/p1_same_cnt[0]} {L2_Cache/p1_same_cnt[1]} {L2_Cache/p1_same_cnt[2]} {L2_Cache/p1_same_cnt[3]} {L2_Cache/p1_same_cnt[4]} {L2_Cache/p1_same_cnt[5]} {L2_Cache/p1_same_cnt[6]} {L2_Cache/p1_same_cnt[7]} {L2_Cache/p1_same_cnt[8]} {L2_Cache/p1_same_cnt[9]} {L2_Cache/p1_same_cnt[10]} {L2_Cache/p1_same_cnt[11]} {L2_Cache/p1_same_cnt[12]} {L2_Cache/p1_same_cnt[13]} {L2_Cache/p1_same_cnt[14]} {L2_Cache/p1_same_cnt[15]}]]



create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 4 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER true [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list Clock_Generator/inst/clk_out1]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 1 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {L2_MEM_rw[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 1 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {L2_MEM_rw[0]}]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk]
