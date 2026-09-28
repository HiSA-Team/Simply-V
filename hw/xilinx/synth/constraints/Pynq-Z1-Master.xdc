## Pynq-Z1-Master.xdc
## Simply-V, embedded profile, PL-only. Pin locations from the PYNQ-Z1 board files (part0_pins.xml).

## Clock: 125 MHz PL oscillator (no PS needed)
set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { sys_clock_i }]; #Sch=sysclk
create_clock -add -name sys_clk_pin -period 8.000 -waveform {0.000 4.000} [get_ports { sys_clock_i }];

## Reset: BTN0 drives the clock wizard reset (its 'locked' output generates the system resets)
set_property -dict { PACKAGE_PIN D19   IOSTANDARD LVCMOS33 } [get_ports { sys_reset_i }]; #Sch=btn[0]

## GPIO in (4 bits): SW0, SW1, BTN1, BTN2
set_property -dict { PACKAGE_PIN M20   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[0] }]; #Sch=sw[0]
set_property -dict { PACKAGE_PIN M19   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[1] }]; #Sch=sw[1]
set_property -dict { PACKAGE_PIN D20   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[2] }]; #Sch=btn[1]
set_property -dict { PACKAGE_PIN L20   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[3] }]; #Sch=btn[2]

## GPIO out (4 bits): LD0..LD3
set_property -dict { PACKAGE_PIN R14   IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[0] }]; #Sch=led[0]
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[1] }]; #Sch=led[1]
set_property -dict { PACKAGE_PIN N16   IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[2] }]; #Sch=led[2]
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[3] }]; #Sch=led[3]

## UART: the onboard USB-UART is wired to the PS (MIO14/15), unreachable in PL-only.
## Use an external FTDI on Pmod JA: FTDI RX -> JA1 (uart_tx_o), FTDI TX -> JA2 (uart_rx_i). Do not connect VCC.
set_property -dict { PACKAGE_PIN Y18   IOSTANDARD LVCMOS33 } [get_ports { uart_tx_o }]; #Pmod JA1
set_property -dict { PACKAGE_PIN Y19   IOSTANDARD LVCMOS33 } [get_ports { uart_rx_i }]; #Pmod JA2
