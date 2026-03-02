# Configuring OpenSBI for Simply-V

Users can directly edit the `simply-v/configs/defconfig` instead of using menuconfig and install the platform again:

```sh
make install
```

In the following, we show how to configure the `CONFIG_SIMPLYV_USE_XILINX_SERIAL` parameter.

## CONFIG_SIMPLYV_USE_XILINX_SERIAL

For instance, this project supports both the tinyIO UART driver and the OpenSBI AXI-lite driver.

To select the latter, change `simply-v/configs/defconfig` to:
```sh
CONFIG_SIMPLYV_USE_XILINX_SERIAL=y
```

To select the tinyIO implementation, first rebuild the tinyIO library with `-fPIC` support.
From the top directory of the Simply-V project, run:
```sh
make -C sw/SoC/lib/tinyio clean all RV_PREFIX=riscv64-unknown-linux-elf- FPIC=Y

```

Then, change `simply-v/configs/defconfig` to:
```sh
CONFIG_SIMPLYV_USE_XILINX_SERIAL=n
```

Finally, install the configuration and rebuild the firmware:
```sh
make install # install updated config
make opensbi # rebiuild firwmare
```


