# Simply-V FreeRTOS

The FreeRTOS integration in Simply-V works by linking applications against the FreeRTOS kernel. The
directory structure is:
- kernel: the FreeRTOS-kernel. Provides the `tasks.c` `heap_*.c` `queue.c` etc. and platform specific ports
- app: user applications directory. Each application must live in each own directory. The application
    directory is structured like the following and have dedicated linkerscript, Makefile and configuration:
    - app/\<app-name-1\>/
    - app/\<app-name-2\>/
- Makefile: used to invoke application specific Makefiles
- common: contains common files to be used by applications:
  * `FreeRTOSConfig.h`: FreeRTOS configuration.
  * `startups.S`: startup file to setup `freertos_risc_v_trap_handler`, `_reset_handler` and jump to main.
  * `Makefile`: a Makefile to compile and link against the FreeRTOSKernel
  * `linker.ld`: linkerscript defining `.bss` and `.data` sections

## Documentation
This guide explains how to build and create a new FreeRTOS application for RISC-V. More detailed 
documentation can be found here:

- [Porting Guide](./doc/PORTING.md): how the port has been implemented and what is needed to integrate RISC-V on SoC

## Build an application

First make sure you get the FreeRTOS sources:
```sh
make freertos
```

> [!Note]
> Toolchain, architecture, ABI etc. are managed from `${ROOT_DIR}/sw/SoC/common/config.mk`. You can define your 
custom RV_PREFIX by running something `make RV_PREFIX=<path-to-prefix> XLEN=<32-64>`

Build an application with:
```
make <app-name> # omit <app-name> to build all applications in app/
```

The application will be in `app/<app-name>/build/`.

## FreeRTOS configuration

Users can configure applications by modifing the `FreeRTOSConfig.h` and specifying the heap profile 
with the HEAP_PROFILE variable.

### Configuration
The `FreeRTOSConfig.h` contains configuration for the FreeRTOS-Kernel and the applications. Based 
on the platform capabilities user can tune parameters like `configTOTAL_HEAP_SIZE, configMINIMAL_STACK_SIZE`.

Some usefule variables to enable extra debugging are:
```c
#define configUSE_MALLOC_FAILED_HOOK          1
#define configCHECK_FOR_STACK_OVERFLOW        2
```

When enabled they mandate to provide `void vApplicationMallocFailedHook(void)` and `
void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName)` functions that will get 
called when the malloc fails or when the stack overflows happens.

In order for timers to work, users will need to configure CPU clock and TickRate accordingly:
```c
/* This should align to the SoC CPU clock */
#define configCPU_CLOCK_HZ                        ( ( unsigned long ) 20000000 )
#define configTICK_RATE_HZ                         ( 50U )
```

#### Heap configuration
FreeRTOS has different heap implemenations, you can choose the heap implementation by specifying
the `HEAP_PROFILE` variable on the `make` command (from 1 to 5, default is 1). 
include file in the `Makefile` (default is `1`). For example to use `heap_3.c`:

```sh
make HEAP_PROFILE=3
```

## Creating a new application
An application must live in the `app/` directory. Users may use `common/` files (linkerscript, Makefile 
and configuration) and tailor them for their need. Main requirements are:
- build and link against the FreeRTOS kernel;
- specify RISC_V freertos port;
- define __stack_irq_top symbol;
