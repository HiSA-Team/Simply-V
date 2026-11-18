## KR260-PL-Only-Master.xdc
## Kria KR260 (K26 SOM, Zynq UltraScale+), PL-only.
## Pins from the Vivado board files (kr260_carrier 1.1, kr260_som 1.1).

## Clock: 25 MHz from the carrier Si5332 (HPA_CLK0P_CLK, som240_1_a6), HP bank 66
set_property -dict { PACKAGE_PIN C3  IOSTANDARD LVCMOS18 } [get_ports { sys_clock_i }]; # HPA_CLK0P_CLK
create_clock -add -name sys_clk_pin -period 40.000 -waveform {0.000 20.000} [get_ports { sys_clock_i }];

## Reset: no PL button on the KR260, PMOD2 pin with pull-down (active high, as BTN0 on the Pynq-Z1)
set_property -dict { PACKAGE_PIN F11 IOSTANDARD LVCMOS33 PULLDOWN TRUE } [get_ports { sys_reset_i }]; # pmod2 bit 7

## User LEDs (HP bank 66, 1.8 V)
set_property -dict { PACKAGE_PIN F8  IOSTANDARD LVCMOS18 } [get_ports { gpio_out_o[0] }]; # User_led[0], DS7
set_property -dict { PACKAGE_PIN E8  IOSTANDARD LVCMOS18 } [get_ports { gpio_out_o[1] }]; # User_led[1], DS8

## PMOD2 (HD bank 45): GPIOs
set_property -dict { PACKAGE_PIN J11 IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[2] }]; # pmod2 bit 0
set_property -dict { PACKAGE_PIN J10 IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[3] }]; # pmod2 bit 1
set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS33 PULLDOWN TRUE } [get_ports { gpio_in_i[0] }]; # pmod2 bit 2
set_property -dict { PACKAGE_PIN K12 IOSTANDARD LVCMOS33 PULLDOWN TRUE } [get_ports { gpio_in_i[1] }]; # pmod2 bit 3
set_property -dict { PACKAGE_PIN H11 IOSTANDARD LVCMOS33 PULLDOWN TRUE } [get_ports { gpio_in_i[2] }]; # pmod2 bit 4
set_property -dict { PACKAGE_PIN G10 IOSTANDARD LVCMOS33 PULLDOWN TRUE } [get_ports { gpio_in_i[3] }]; # pmod2 bit 5

## PMOD1 (HD bank 45): UART through an external FTDI, as on the Pynq-Z1 PL-only (JA)
set_property -dict { PACKAGE_PIN H12 IOSTANDARD LVCMOS33 } [get_ports { uart_tx_o }]; # pmod1 bit 0
set_property -dict { PACKAGE_PIN E10 IOSTANDARD LVCMOS33 } [get_ports { uart_rx_i }]; # pmod1 bit 1
