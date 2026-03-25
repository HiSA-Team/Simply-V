# Simply-V Software Compilation and Usage

This repository contains the software infrastructure needed to build bare-metal applications for Simply-V.
> NOTE: We assume that the RISC-V toolchain, selected with the config flow (XLEN parameter), is in your PATH.

Examples rely on a common set of files in the `common` directory:

* The `startup.s` that implements the very basic initialization operations.
* The `simplyv.ld`, automatically generated during the configuration flow (see the root [README](../../README.md)).
* The `Makefile`, that implements all basic targets for building, shared among bare-metal applications.

The directory `example/` hosts simple bare-metal examples and tests to exercise the platform.

The directory `projects/` contains more advanced projects, such as Free-RTOS, OpenSBI, etc.

## Build Examples

To build the `examples`, run:
``` bash
make examples
```
The existing examples include:
- `blinky` - Basic and self-contained led blinking example. Requires no external libraries or devices. Supported only on the `embedded` profile.
- `hello_world` - basic Hello World on UART.
- `echo` - echo server for strings.
- `interrupts` - PLIC reference example.

Most examples use our light-weight HAL (`lib/simplyv`) and the [tinyio](https://github.com/Granp4sso/TinyIO-library-for-printf-and-scanf-) library for `printf()` and `scanf()` on UART.

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

### User-defined Makefile

The `Makefile` in the project folder is a user-defined Makefile, that imports the `common/Makefile`.
In this Makefile the user can customize its project structure, compilation flags alongside toolchain selection and also the external libraries dependencies.
A user can add new target rules in the user-defined Makefile. However, despite changes inside the user-defined `Makefile`, all targets
described in **Build examples** ca be applied.

### User-defined linker script

The shared linker script is automatically generated during the configuration phase of the Simply-V project, based on the specified SoC configuration.
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
