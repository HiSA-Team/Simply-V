## KR260-PL-Only-Master.xdc
## Simply-V, embedded profile, PL-only: the PS is not used, not even for the clock.
## This file is a general .xdc for the Kria KR260 Robotics Starter Kit (K26 SOM, carrier card SCK-KR rev A02).
## AMD does not publish a master XDC for the KR260 (it refers to the Vivado board files), so this file was built from:
## - the Vivado board files kr260_som 1.1 (part0_pins.xml, SOM240 pin to FPGA pin) and kr260_carrier 1.1 (board.xml, interfaces and IO standards)
## - the KR260 carrier card schematic (XTP743, 038-05101-01 rev A02), for net names, connectors and functions
## To use it in a project:
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project
## HP bank pins are at 1.8 V (LVCMOS18), HD bank pins at 3.3 V (LVCMOS33).
## SOM pins that are not connected on the carrier card (HPC bank, some HPA/HPB pins) are not listed.

## Clock signals - 25 MHz oscillator U92 through fanout buffer U91 (schematic page 16), no PS needed
set_property -dict { PACKAGE_PIN C3   IOSTANDARD LVCMOS18 } [get_ports { sys_clock_i }]; #SOM240_1 A6 Sch=HPA_CLK0P_CLK
create_clock -add -name sys_clk_pin -period 40.000 -waveform {0.000 20.000} [get_ports { sys_clock_i }];
#set_property -dict { PACKAGE_PIN L3   IOSTANDARD LVCMOS18 } [get_ports { hpb_clk0p_clk }]; #SOM240_2 D18 Sch=HPB_CLK0P_CLK
#create_clock -add -name hpb_clk_pin -period 40.000 -waveform {0.000 20.000} [get_ports { hpb_clk0p_clk }];

## User LEDs (UF1/UF2 on the carrier)
set_property -dict { PACKAGE_PIN F8   IOSTANDARD LVCMOS18 } [get_ports { gpio_out_o[0] }]; #SOM240_1 D13 Sch=HPA14P DS7
set_property -dict { PACKAGE_PIN E8   IOSTANDARD LVCMOS18 } [get_ports { gpio_out_o[1] }]; #SOM240_1 D14 Sch=HPA14N DS8

## PMOD1 (J2): IO1-IO4 on connector pins 1,3,5,7, IO5-IO8 on pins 2,4,6,8, GND on 9/10, 3.3 V on 11/12
## Simply-V PL-only: UART through an external USB-UART (FTDI), as on the Pynq-Z1 PL-only (JA)
set_property -dict { PACKAGE_PIN H12  IOSTANDARD LVCMOS33 } [get_ports { uart_tx_o }]; #SOM240_1 A17 Sch=HDA11 PMOD1_IO1 pin 1
set_property -dict { PACKAGE_PIN E10  IOSTANDARD LVCMOS33 } [get_ports { uart_rx_i }]; #SOM240_1 D20 Sch=HDA12 PMOD1_IO2 pin 3
#set_property -dict { PACKAGE_PIN D10  IOSTANDARD LVCMOS33 } [get_ports { pmod1[2] }]; #SOM240_1 D21 Sch=HDA13 PMOD1_IO3 pin 5
#set_property -dict { PACKAGE_PIN C11  IOSTANDARD LVCMOS33 } [get_ports { pmod1[3] }]; #SOM240_1 D22 Sch=HDA14 PMOD1_IO4 pin 7
#set_property -dict { PACKAGE_PIN B10  IOSTANDARD LVCMOS33 } [get_ports { pmod1[4] }]; #SOM240_1 B20 Sch=HDA15 PMOD1_IO5 pin 2
#set_property -dict { PACKAGE_PIN E12  IOSTANDARD LVCMOS33 } [get_ports { pmod1[5] }]; #SOM240_1 B21 Sch=HDA16_CC PMOD1_IO6 pin 4
#set_property -dict { PACKAGE_PIN D11  IOSTANDARD LVCMOS33 } [get_ports { pmod1[6] }]; #SOM240_1 B22 Sch=HDA17 PMOD1_IO7 pin 6
#set_property -dict { PACKAGE_PIN B11  IOSTANDARD LVCMOS33 } [get_ports { pmod1[7] }]; #SOM240_1 C22 Sch=HDA18 PMOD1_IO8 pin 8

## PMOD2 (J18): IO1-IO4 on connector pins 1,3,5,7, IO5-IO8 on pins 2,4,6,8, GND on 9/10, 3.3 V on 11/12
## Simply-V PL-only: GPIOs, and the reset on IO8 because the KR260 has no PL push button
set_property -dict { PACKAGE_PIN J11  IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[2] }]; #SOM240_1 D18 Sch=HDA02 PMOD2_IO1 pin 1
set_property -dict { PACKAGE_PIN J10  IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[3] }]; #SOM240_1 B16 Sch=HDA03 PMOD2_IO2 pin 3
set_property -dict { PACKAGE_PIN K13  IOSTANDARD LVCMOS33 PULLDOWN TRUE } [get_ports { gpio_in_i[0] }]; #SOM240_1 B17 Sch=HDA04 PMOD2_IO3 pin 5
set_property -dict { PACKAGE_PIN K12  IOSTANDARD LVCMOS33 PULLDOWN TRUE } [get_ports { gpio_in_i[1] }]; #SOM240_1 B18 Sch=HDA05 PMOD2_IO4 pin 7
set_property -dict { PACKAGE_PIN H11  IOSTANDARD LVCMOS33 PULLDOWN TRUE } [get_ports { gpio_in_i[2] }]; #SOM240_1 C18 Sch=HDA06 PMOD2_IO5 pin 2
set_property -dict { PACKAGE_PIN G10  IOSTANDARD LVCMOS33 PULLDOWN TRUE } [get_ports { gpio_in_i[3] }]; #SOM240_1 C19 Sch=HDA07 PMOD2_IO6 pin 4
#set_property -dict { PACKAGE_PIN F12  IOSTANDARD LVCMOS33 } [get_ports { pmod2[6] }]; #SOM240_1 C20 Sch=HDA08_CC PMOD2_IO7 pin 6
set_property -dict { PACKAGE_PIN F11  IOSTANDARD LVCMOS33 PULLDOWN TRUE } [get_ports { sys_reset_i }]; #SOM240_1 A15 Sch=HDA09 PMOD2_IO8 pin 8

## PMOD3 (J19): IO1-IO4 on connector pins 1,3,5,7, IO5-IO8 on pins 2,4,6,8, GND on 9/10, 3.3 V on 11/12
#set_property -dict { PACKAGE_PIN AE12 IOSTANDARD LVCMOS33 } [get_ports { pmod3[0] }]; #SOM240_2 D44 Sch=HDB00_CC PMOD3_IO1 pin 1
#set_property -dict { PACKAGE_PIN AF12 IOSTANDARD LVCMOS33 } [get_ports { pmod3[1] }]; #SOM240_2 D45 Sch=HDB01 PMOD3_IO2 pin 3
#set_property -dict { PACKAGE_PIN AG10 IOSTANDARD LVCMOS33 } [get_ports { pmod3[2] }]; #SOM240_2 D46 Sch=HDB02 PMOD3_IO3 pin 5
#set_property -dict { PACKAGE_PIN AH10 IOSTANDARD LVCMOS33 } [get_ports { pmod3[3] }]; #SOM240_2 D48 Sch=HDB03 PMOD3_IO4 pin 7
#set_property -dict { PACKAGE_PIN AF11 IOSTANDARD LVCMOS33 } [get_ports { pmod3[4] }]; #SOM240_2 D49 Sch=HDB04 PMOD3_IO5 pin 2
#set_property -dict { PACKAGE_PIN AG11 IOSTANDARD LVCMOS33 } [get_ports { pmod3[5] }]; #SOM240_2 D50 Sch=HDB05 PMOD3_IO6 pin 4
#set_property -dict { PACKAGE_PIN AH12 IOSTANDARD LVCMOS33 } [get_ports { pmod3[6] }]; #SOM240_2 C46 Sch=HDB06 PMOD3_IO7 pin 6
#set_property -dict { PACKAGE_PIN AH11 IOSTANDARD LVCMOS33 } [get_ports { pmod3[7] }]; #SOM240_2 C47 Sch=HDB07 PMOD3_IO8 pin 8

## PMOD4 (J20): IO1-IO4 on connector pins 1,3,5,7, IO5-IO8 on pins 2,4,6,8, GND on 9/10, 3.3 V on 11/12
#set_property -dict { PACKAGE_PIN AC12 IOSTANDARD LVCMOS33 } [get_ports { pmod4[0] }]; #SOM240_2 C48 Sch=HDB08_CC PMOD4_IO1 pin 1
#set_property -dict { PACKAGE_PIN AD12 IOSTANDARD LVCMOS33 } [get_ports { pmod4[1] }]; #SOM240_2 C50 Sch=HDB09 PMOD4_IO2 pin 3
#set_property -dict { PACKAGE_PIN AE10 IOSTANDARD LVCMOS33 } [get_ports { pmod4[2] }]; #SOM240_2 C51 Sch=HDB10 PMOD4_IO3 pin 5
#set_property -dict { PACKAGE_PIN AF10 IOSTANDARD LVCMOS33 } [get_ports { pmod4[3] }]; #SOM240_2 C52 Sch=HDB11 PMOD4_IO4 pin 7
#set_property -dict { PACKAGE_PIN AD11 IOSTANDARD LVCMOS33 } [get_ports { pmod4[4] }]; #SOM240_2 B44 Sch=HDB12 PMOD4_IO5 pin 2
#set_property -dict { PACKAGE_PIN AD10 IOSTANDARD LVCMOS33 } [get_ports { pmod4[5] }]; #SOM240_2 B45 Sch=HDB13 PMOD4_IO6 pin 4
#set_property -dict { PACKAGE_PIN AA11 IOSTANDARD LVCMOS33 } [get_ports { pmod4[6] }]; #SOM240_2 B46 Sch=HDB14 PMOD4_IO7 pin 6
#set_property -dict { PACKAGE_PIN AA10 IOSTANDARD LVCMOS33 } [get_ports { pmod4[7] }]; #SOM240_2 B48 Sch=HDB15 PMOD4_IO8 pin 8

## Raspberry Pi header (J21)
#set_property -dict { PACKAGE_PIN AD15 IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[0] }]; #SOM240_2 D52 Sch=HDC00_CC RPI_GPIO0_ID_SD pin 27
#set_property -dict { PACKAGE_PIN AD14 IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[1] }]; #SOM240_2 D53 Sch=HDC01 RPI_GPIO1_ID_SC pin 28
#set_property -dict { PACKAGE_PIN AE15 IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[2] }]; #SOM240_2 D54 Sch=HDC02 RPI_GPIO2_SDA pin 3
#set_property -dict { PACKAGE_PIN AE14 IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[3] }]; #SOM240_2 D56 Sch=HDC03 RPI_GPIO3_SCL pin 5
#set_property -dict { PACKAGE_PIN AG14 IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[4] }]; #SOM240_2 D57 Sch=HDC04 RPI_GPIO4_GPCLK0 pin 7
#set_property -dict { PACKAGE_PIN AH14 IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[5] }]; #SOM240_2 D58 Sch=HDC05 RPI_GPIO5 pin 29
#set_property -dict { PACKAGE_PIN AG13 IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[6] }]; #SOM240_2 C54 Sch=HDC06 RPI_GPIO6 pin 31
#set_property -dict { PACKAGE_PIN AH13 IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[7] }]; #SOM240_2 C55 Sch=HDC07 RPI_GPIO7_CE1 pin 26
#set_property -dict { PACKAGE_PIN AC14 IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[8] }]; #SOM240_2 C56 Sch=HDC08_CC RPI_GPIO8_CE0 pin 24
#set_property -dict { PACKAGE_PIN AC13 IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[9] }]; #SOM240_2 C58 Sch=HDC09 RPI_GPIO9_MISO pin 21
#set_property -dict { PACKAGE_PIN AE13 IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[10] }]; #SOM240_2 C59 Sch=HDC10 RPI_GPIO10_MOSI pin 19
#set_property -dict { PACKAGE_PIN AF13 IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[11] }]; #SOM240_2 C60 Sch=HDC11 RPI_GPIO11_SCLK pin 23
#set_property -dict { PACKAGE_PIN AA13 IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[12] }]; #SOM240_2 B52 Sch=HDC12 RPI_GPIO12_PWM0 pin 32
#set_property -dict { PACKAGE_PIN AB13 IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[13] }]; #SOM240_2 B53 Sch=HDC13 RPI_GPIO13_PWM1 pin 33
#set_property -dict { PACKAGE_PIN W14  IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[14] }]; #SOM240_2 B54 Sch=HDC14 RPI_GPIO14_TXD pin 8
#set_property -dict { PACKAGE_PIN W13  IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[15] }]; #SOM240_2 B56 Sch=HDC15 RPI_GPIO15_RXD pin 10
#set_property -dict { PACKAGE_PIN AB15 IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[16] }]; #SOM240_2 B57 Sch=HDC16_CC RPI_GPIO16 pin 36
#set_property -dict { PACKAGE_PIN AB14 IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[17] }]; #SOM240_2 B58 Sch=HDC17 RPI_GPIO17 pin 11
#set_property -dict { PACKAGE_PIN Y14  IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[18] }]; #SOM240_2 A54 Sch=HDC18 RPI_GPIO18_PCM_CLK pin 12
#set_property -dict { PACKAGE_PIN Y13  IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[19] }]; #SOM240_2 A55 Sch=HDC19 RPI_GPIO19_PCM_FS pin 35
#set_property -dict { PACKAGE_PIN W12  IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[20] }]; #SOM240_2 A56 Sch=HDC20 RPI_GPIO20_PCM_DIN pin 38
#set_property -dict { PACKAGE_PIN W11  IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[21] }]; #SOM240_2 A58 Sch=HDC21 RPI_GPIO21_PCM_DOUT pin 40
#set_property -dict { PACKAGE_PIN Y12  IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[22] }]; #SOM240_2 A59 Sch=HDC22 RPI_GPIO22 pin 15
#set_property -dict { PACKAGE_PIN AA12 IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[23] }]; #SOM240_2 A60 Sch=HDC23 RPI_GPIO23 pin 16
#set_property -dict { PACKAGE_PIN Y9   IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[24] }]; #SOM240_2 A48 Sch=HDB20 RPI_GPIO24 pin 18
#set_property -dict { PACKAGE_PIN AA8  IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[25] }]; #SOM240_2 A50 Sch=HDB21 RPI_GPIO25 pin 22
#set_property -dict { PACKAGE_PIN AB10 IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[26] }]; #SOM240_2 A51 Sch=HDB22 RPI_GPIO26 pin 37
#set_property -dict { PACKAGE_PIN AB9  IOSTANDARD LVCMOS33 } [get_ports { rpi_gpio[27] }]; #SOM240_2 A52 Sch=HDB23 RPI_GPIO27 pin 13

## PL Ethernet GEM2 (RGMII, Marvell M88E1111 PHY, schematic page 20)
#set_property -dict { PACKAGE_PIN A2   IOSTANDARD LVCMOS18 } [get_ports { gem2_rgmii_txc }]; #SOM240_1 A3 Sch=HPA06P_CLK
#set_property -dict { PACKAGE_PIN F1   IOSTANDARD LVCMOS18 } [get_ports { gem2_rgmii_tx_ctl }]; #SOM240_1 C4 Sch=HPA00_CCN
#set_property -dict { PACKAGE_PIN E1   IOSTANDARD LVCMOS18 } [get_ports { gem2_rgmii_td[0] }]; #SOM240_1 D7 Sch=HPA01P
#set_property -dict { PACKAGE_PIN D1   IOSTANDARD LVCMOS18 } [get_ports { gem2_rgmii_td[1] }]; #SOM240_1 D8 Sch=HPA01N
#set_property -dict { PACKAGE_PIN F2   IOSTANDARD LVCMOS18 } [get_ports { gem2_rgmii_td[2] }]; #SOM240_1 D4 Sch=HPA02P
#set_property -dict { PACKAGE_PIN E2   IOSTANDARD LVCMOS18 } [get_ports { gem2_rgmii_td[3] }]; #SOM240_1 D5 Sch=HPA02N
#set_property -dict { PACKAGE_PIN D4   IOSTANDARD LVCMOS18 } [get_ports { gem2_rgmii_rxc }]; #SOM240_1 D10 Sch=HPA09P_CLK
#set_property -dict { PACKAGE_PIN A4   IOSTANDARD LVCMOS18 } [get_ports { gem2_rgmii_rx_ctl }]; #SOM240_1 C10 Sch=HPA08N
#set_property -dict { PACKAGE_PIN A1   IOSTANDARD LVCMOS18 } [get_ports { gem2_rgmii_rd[0] }]; #SOM240_1 A4 Sch=HPA06N
#set_property -dict { PACKAGE_PIN B3   IOSTANDARD LVCMOS18 } [get_ports { gem2_rgmii_rd[1] }]; #SOM240_1 B7 Sch=HPA07P
#set_property -dict { PACKAGE_PIN A3   IOSTANDARD LVCMOS18 } [get_ports { gem2_rgmii_rd[2] }]; #SOM240_1 B8 Sch=HPA07N
#set_property -dict { PACKAGE_PIN B4   IOSTANDARD LVCMOS18 } [get_ports { gem2_rgmii_rd[3] }]; #SOM240_1 C9 Sch=HPA08P
#set_property -dict { PACKAGE_PIN G3   IOSTANDARD LVCMOS18 } [get_ports { gem2_mdc }]; #SOM240_1 C6 Sch=HPA03P
#set_property -dict { PACKAGE_PIN F3   IOSTANDARD LVCMOS18 } [get_ports { gem2_mdio }]; #SOM240_1 C7 Sch=HPA03N
#set_property -dict { PACKAGE_PIN B1   IOSTANDARD LVCMOS18 } [get_ports { gem2_reset_b }]; #SOM240_1 B2 Sch=HPA05_CCN through reset logic U19 (page 16)
#set_property -dict { PACKAGE_PIN E4   IOSTANDARD LVCMOS18 } [get_ports { gem2_led[0] }]; #SOM240_1 B4 Sch=HPA04P
#set_property -dict { PACKAGE_PIN E3   IOSTANDARD LVCMOS18 } [get_ports { gem2_led[1] }]; #SOM240_1 B5 Sch=HPA04N
#set_property -dict { PACKAGE_PIN C1   IOSTANDARD LVCMOS18 } [get_ports { gem2_led[2] }]; #SOM240_1 B1 Sch=HPA05_CCP

## PL Ethernet GEM3 (RGMII, Marvell M88E1111 PHY, schematic page 21)
#set_property -dict { PACKAGE_PIN J1   IOSTANDARD LVCMOS18 } [get_ports { gem3_rgmii_txc }]; #SOM240_2 A20 Sch=HPB06P_CLK
#set_property -dict { PACKAGE_PIN Y8   IOSTANDARD LVCMOS18 } [get_ports { gem3_rgmii_tx_ctl }]; #SOM240_2 D16 Sch=HPB00_CCN
#set_property -dict { PACKAGE_PIN U9   IOSTANDARD LVCMOS18 } [get_ports { gem3_rgmii_td[0] }]; #SOM240_2 D12 Sch=HPB01P
#set_property -dict { PACKAGE_PIN V9   IOSTANDARD LVCMOS18 } [get_ports { gem3_rgmii_td[1] }]; #SOM240_2 D13 Sch=HPB01N
#set_property -dict { PACKAGE_PIN U8   IOSTANDARD LVCMOS18 } [get_ports { gem3_rgmii_td[2] }]; #SOM240_2 C17 Sch=HPB02P
#set_property -dict { PACKAGE_PIN V8   IOSTANDARD LVCMOS18 } [get_ports { gem3_rgmii_td[3] }]; #SOM240_2 C18 Sch=HPB02N
#set_property -dict { PACKAGE_PIN K4   IOSTANDARD LVCMOS18 } [get_ports { gem3_rgmii_rxc }]; #SOM240_2 C11 Sch=HPB09P_CLK
#set_property -dict { PACKAGE_PIN H3   IOSTANDARD LVCMOS18 } [get_ports { gem3_rgmii_rx_ctl }]; #SOM240_2 A15 Sch=HPB08N
#set_property -dict { PACKAGE_PIN H1   IOSTANDARD LVCMOS18 } [get_ports { gem3_rgmii_rd[0] }]; #SOM240_2 A21 Sch=HPB06N
#set_property -dict { PACKAGE_PIN K2   IOSTANDARD LVCMOS18 } [get_ports { gem3_rgmii_rd[1] }]; #SOM240_2 B15 Sch=HPB07P
#set_property -dict { PACKAGE_PIN J2   IOSTANDARD LVCMOS18 } [get_ports { gem3_rgmii_rd[2] }]; #SOM240_2 B16 Sch=HPB07N
#set_property -dict { PACKAGE_PIN H4   IOSTANDARD LVCMOS18 } [get_ports { gem3_rgmii_rd[3] }]; #SOM240_2 A14 Sch=HPB08P
#set_property -dict { PACKAGE_PIN R8   IOSTANDARD LVCMOS18 } [get_ports { gem3_mdc }]; #SOM240_2 B24 Sch=HPB03P
#set_property -dict { PACKAGE_PIN T8   IOSTANDARD LVCMOS18 } [get_ports { gem3_mdio }]; #SOM240_2 B25 Sch=HPB03N
#set_property -dict { PACKAGE_PIN K1   IOSTANDARD LVCMOS18 } [get_ports { gem3_reset_b }]; #SOM240_2 B19 Sch=HPB05_CCN through reset logic U19 (page 16)
#set_property -dict { PACKAGE_PIN R7   IOSTANDARD LVCMOS18 } [get_ports { gem3_led[0] }]; #SOM240_2 D21 Sch=HPB04P
#set_property -dict { PACKAGE_PIN T7   IOSTANDARD LVCMOS18 } [get_ports { gem3_led[1] }]; #SOM240_2 D22 Sch=HPB04N
#set_property -dict { PACKAGE_PIN L1   IOSTANDARD LVCMOS18 } [get_ports { gem3_led[2] }]; #SOM240_2 B18 Sch=HPB05_CCP

## SFP+ cage (schematic page 14)
#set_property -dict { PACKAGE_PIN AB11 IOSTANDARD LVCMOS33 } [get_ports { sfp_scl }]; #SOM240_2 B49 Sch=HDB16_CC
#set_property -dict { PACKAGE_PIN AC11 IOSTANDARD LVCMOS33 } [get_ports { sfp_sda }]; #SOM240_2 B50 Sch=HDB17
#set_property -dict { PACKAGE_PIN W10  IOSTANDARD LVCMOS33 } [get_ports { sfp_mod_abs }]; #SOM240_2 A46 Sch=HDB18
#set_property -dict { PACKAGE_PIN Y10  IOSTANDARD LVCMOS33 } [get_ports { sfp_tx_disable }]; #SOM240_2 A47 Sch=HDB19
#set_property -dict { PACKAGE_PIN A10  IOSTANDARD LVCMOS33 } [get_ports { sfp_tx_fault }]; #SOM240_1 C23 Sch=HDA19
#set_property -dict { PACKAGE_PIN J12  IOSTANDARD LVCMOS33 } [get_ports { sfp_los }]; #SOM240_1 A16 Sch=HDA10
#set_property -dict { PACKAGE_PIN G8   IOSTANDARD LVCMOS18 } [get_ports { sfp_led[0] }]; #SOM240_1 A12 Sch=HPA13P
#set_property -dict { PACKAGE_PIN F7   IOSTANDARD LVCMOS18 } [get_ports { sfp_led[1] }]; #SOM240_1 A13 Sch=HPA13N

## I2C to the Euresys IP EEPROM (schematic page 15); SCL/SDA as in the schematic (the board files, iic0_main, map them the other way round)
#set_property -dict { PACKAGE_PIN G11  IOSTANDARD LVCMOS33 } [get_ports { iic_scl }]; #SOM240_1 D16 Sch=HDA00_CC
#set_property -dict { PACKAGE_PIN F10  IOSTANDARD LVCMOS33 } [get_ports { iic_sda }]; #SOM240_1 D17 Sch=HDA01

## Fan control (schematic page 3)
#set_property -dict { PACKAGE_PIN A12  IOSTANDARD LVCMOS33 } [get_ports { fan_ctrl }]; #SOM240_1 C24 Sch=HDA20

## Framos SLVS-EC connector, low-speed signals (schematic page 13)
#set_property -dict { PACKAGE_PIN N9   IOSTANDARD LVCMOS18 } [get_ports { framos_reset_b }]; #SOM240_2 C14 Sch=HPB14P through reset logic U19 (page 16)
#set_property -dict { PACKAGE_PIN L7   IOSTANDARD LVCMOS18 } [get_ports { framos_hpb10_ccp_clk }]; #SOM240_2 B12 Sch=HPB10_CCP_CLK
#set_property -dict { PACKAGE_PIN M6   IOSTANDARD LVCMOS18 } [get_ports { framos_hpb11p }]; #SOM240_2 B21 Sch=HPB11P
#set_property -dict { PACKAGE_PIN L5   IOSTANDARD LVCMOS18 } [get_ports { framos_hpb11n }]; #SOM240_2 B22 Sch=HPB11N
#set_property -dict { PACKAGE_PIN N7   IOSTANDARD LVCMOS18 } [get_ports { framos_hpb12p }]; #SOM240_2 A17 Sch=HPB12P
#set_property -dict { PACKAGE_PIN N6   IOSTANDARD LVCMOS18 } [get_ports { framos_hpb12n }]; #SOM240_2 A18 Sch=HPB12N
#set_property -dict { PACKAGE_PIN P7   IOSTANDARD LVCMOS18 } [get_ports { framos_hpb13p }]; #SOM240_2 C20 Sch=HPB13P
#set_property -dict { PACKAGE_PIN P6   IOSTANDARD LVCMOS18 } [get_ports { framos_hpb13n }]; #SOM240_2 C21 Sch=HPB13N
#set_property -dict { PACKAGE_PIN N8   IOSTANDARD LVCMOS18 } [get_ports { framos_hpb14n }]; #SOM240_2 C15 Sch=HPB14N
#set_property -dict { PACKAGE_PIN J5   IOSTANDARD LVCMOS18 } [get_ports { framos_hpb15_ccp_clk }]; #SOM240_2 A11 Sch=HPB15_CCP_CLK
#set_property -dict { PACKAGE_PIN J7   IOSTANDARD LVCMOS18 } [get_ports { framos_hpb16p }]; #SOM240_2 A23 Sch=HPB16P
#set_property -dict { PACKAGE_PIN H7   IOSTANDARD LVCMOS18 } [get_ports { framos_hpb16n }]; #SOM240_2 A24 Sch=HPB16N
#set_property -dict { PACKAGE_PIN K8   IOSTANDARD LVCMOS18 } [get_ports { framos_hpb17p }]; #SOM240_2 D24 Sch=HPB17P
#set_property -dict { PACKAGE_PIN K7   IOSTANDARD LVCMOS18 } [get_ports { framos_hpb17n }]; #SOM240_2 D25 Sch=HPB17N
#set_property -dict { PACKAGE_PIN K9   IOSTANDARD LVCMOS18 } [get_ports { framos_hpb18p }]; #SOM240_2 C23 Sch=HPB18P
#set_property -dict { PACKAGE_PIN J9   IOSTANDARD LVCMOS18 } [get_ports { framos_hpb18n }]; #SOM240_2 C24 Sch=HPB18N
#set_property -dict { PACKAGE_PIN H9   IOSTANDARD LVCMOS18 } [get_ports { framos_hpb19p }]; #SOM240_2 A26 Sch=HPB19P
#set_property -dict { PACKAGE_PIN H8   IOSTANDARD LVCMOS18 } [get_ports { framos_hpb19n }]; #SOM240_2 A27 Sch=HPB19N

## GTH transceivers: no IOSTANDARD, to be used through a transceiver IP
#set_property -dict { PACKAGE_PIN Y6   } [get_ports { gth_refclk0_p }]; #SOM240_2 C3 Sch=GTH_REFCLK0_C2M_P 156.25 MHz (SFP+)
#set_property -dict { PACKAGE_PIN Y5   } [get_ports { gth_refclk0_n }]; #SOM240_2 C4 Sch=GTH_REFCLK0_C2M_N
#set_property -dict { PACKAGE_PIN V6   } [get_ports { gth_refclk1_p }]; #SOM240_2 A7 Sch=GTH_REFCLK1_C2M_P 74.25 MHz (SLVS-EC)
#set_property -dict { PACKAGE_PIN V5   } [get_ports { gth_refclk1_n }]; #SOM240_2 A8 Sch=GTH_REFCLK1_C2M_N
#set_property -dict { PACKAGE_PIN T2   } [get_ports { sfp_rx_p }]; #SOM240_2 B1 Sch=GTH_DP2_C2M_P
#set_property -dict { PACKAGE_PIN T1   } [get_ports { sfp_rx_n }]; #SOM240_2 B2 Sch=GTH_DP2_C2M_N
#set_property -dict { PACKAGE_PIN R4   } [get_ports { sfp_tx_p }]; #SOM240_2 B5 Sch=GTH_DP2_M2C_P
#set_property -dict { PACKAGE_PIN R3   } [get_ports { sfp_tx_n }]; #SOM240_2 B6 Sch=GTH_DP2_M2C_N
#set_property -dict { PACKAGE_PIN Y2   } [get_ports { slvsec_rx_p[0] }]; #SOM240_2 B9 Sch=GTH_DP0_C2M_P
#set_property -dict { PACKAGE_PIN Y1   } [get_ports { slvsec_rx_n[0] }]; #SOM240_2 B10 Sch=GTH_DP0_C2M_N
#set_property -dict { PACKAGE_PIN V2   } [get_ports { slvsec_rx_p[1] }]; #SOM240_2 D1 Sch=GTH_DP1_C2M_P
#set_property -dict { PACKAGE_PIN V1   } [get_ports { slvsec_rx_n[1] }]; #SOM240_2 D2 Sch=GTH_DP1_C2M_N
