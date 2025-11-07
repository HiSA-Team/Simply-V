# UninaSoC Software Compilation and Usage

This repository contains the software infrastructure needed to build bare-metal applications for UninaSoC.
All example applications, as well as custom projects, are built upon the `projects/template` project.
Projects rely on a common set of files in the `common` directory.

* The `startup.s` that implements the very basic initialization operations.
* The `UninaSoC.ld`, automatically generated during the configuration flow (see the root [README](../../README.md)).
* The `Makefile`, that implements all basic targets for building, shared among bare-metal applications.

It is expected that libraries and projects depend at least on the common files.

**Notes**
* For Linux-based configurations, please refer to the appropriate documentation, as this tree does not apply.
* We assume that the RISC-V toolchain, selected with the config flow (XLEN parameter), is in your PATH.

## Build examples

to build the `examples`, run
``` bash
make examples
```
The existing examples include:
- `blinky` - Blink board leds Supported only on the `embedded` configuration.
- `echo` - echo server for strings.
- `hello_world` - basic Hello World on UART.
- `interrupts` - PLIC reference example.

Some examples use the [tinyio](https://github.com/Granp4sso/TinyIO-library-for-printf-and-scanf-) library for `printf()` and `scanf()` on UART.

You can build individual examples or create new projects as described in the following sections.
Each directory under examples or projects includes a `common/Makefile` that provides baseline commands for building code.
For instance, let’s explore the `examples/hello_world` example and build it:

These simple steps will produce the `hello_world.bin` and `hello_world.elf` files in the `bin` directory.
``` bash
cd examples/hello_world
make
```

In general, the targets available in the `common/Makefile` are as follows:

Generate `.bin` and `.elf` files in the newly created bin directory.
``` bash
make
```

This removes all previously generated build files.
``` bash
make clean
```

This outputs the binary content of your program.
``` bash
make dump
```


## Create a new project

To create a new application project, make a copy of the `template` directory and rename it accordingly to your application name.

The tree must have the following structure:
```
project_name
├── ld
│   └── user.ld
├── Makefile
├── inc
└── src
    └── main.c
```

To add user-defined code, place source files in the `src` directory and header files in the `inc` directory.

### User-defined Makefile

The `Makefile` in the project folder is a user-defined Makefile, that imports the `common/Makefile`.
In this Makefile the user can customize its project structure, compilation flags alongside toolchain selection and also the external libraries dependencies.
A user can add new target rules in the user-defined Makefile. However, despite changes inside the user-defined `Makefile`, all targets
described in **Build examples** ca be applied.

### User-defined linker script

The shared linker script is automatically generated during the configuration phase of the UninaSoC project, based on the specified SoC configuration.
By default, only a few symbols and sections are defined:

- **Symbols**: Include the vector table base address, stack pointer value, and peripheral symbols (which can be imported into user code).
- **Sections**: Only the text section is defined. The vector table must be placed at the boot address, where entry 0 corresponds to a jump to the reset handler.

Users can define custom linker script sections and symbols by editing the `ld/user.ld` file in the project directory.

### Importing new libraries

Libraries, whether external or internal, are stored in the `lib` directory. To include libraries in your custom project, update the Makefile by specifying them in the libraries section.
Each library must provide:

- A static library object file (`.a`).
- Any necessary header files for integration.

For a practical example of integrating libraries into a project, refer to the `examples/hello_world` example.

**Note**: currently tinyio is compiled with M and C extensions. If you want to run examples or projects depending on it, ensure to use a compatible CPU.
