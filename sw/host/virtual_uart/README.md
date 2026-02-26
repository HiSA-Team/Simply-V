# Virtual Uart Host Application
### To build
```
make
```
### Usage
```
cd bin;
sudo ./host_virtual_uart <uart_paddr> [uart_length] [u_poll_period]
```
* uart_paddr: physical address of the virtual uart peripheral in the PCIe BAR
* uart_length: length of the mapping (CSR space of the peripheral) - default 20
* u_poll_period: poll period in microseconds - default 10

The application starts a prompt to interact with the SoC.
Each char you digit is sent to the SoC through the virtual uart peripheral.

The expected behaviour depends on the application running on the SoC.
As a reference, our examples using the uart behave as follow:
* `sw/SoC/examples/hello_world`: it simply prints the "Hello world" string.
* `sw/SoC/examples/echo`: it waits for a string then replies with the same string.





