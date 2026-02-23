# Virtual Uart Host Application
### To build
```
make
```
### Usage
You need to be sudo to use this application:
```bash
sudo .bin/host_virtual_uart <uart_paddr> [uart_length] [u_poll_period]
```
Arguments
* `uart_paddr`: physical address of the virtual UART peripheral + the PCIe BAR
* (optional) `uart_length`: length of the mapping (CSR space of the peripheral) - default 20
* (optional) `u_poll_period`: poll period in microseconds - default 10

E.g. for PCIe BAR `0x92000000` and UART offset `0x20000`:
```bash
sudo bin/virtual_uart 0x92020000
```

The application starts a prompt to interact with the SoC.
Each char you digit is sent to the SoC through the virtual uart peripheral.

The expected behaviour depends on the application running on the SoC.
As a reference, our examples using the uart behave as follow:
* `sw/SoC/examples/hello_world`: it simply prints the "Hello World!" string.
* `sw/SoC/examples/echo`: it waits for a string then replies with the same string.





