# Adding a New Bus to the System

This document describes the steps required to integrate a new bus into the system configuration.

---

## Overview

To add a new bus, you must:

1. Add a new configuration `.csv` file
2. Adapt the configuration Makefile with new INPUT and OUTPUT files related to the new bus
3. Implement a new Python bus class
4. Register the new bus in the bus factory
5. (Optional) Extend the parser hierarchy for complex buses

### Naming Conventions

The {BUSNAME} name of the new bus must follow the `FULL_NAME` semantic, this applies to:
- configuration files (.csv and Makefile)

other informations must follow the `BASE_NAME` semantic 

This applies to:
- Python class names
- Factory registration names
- Legal buses/peripherals supported by the bus

`FULL_NAME` and `BASE_NAME` semantic are specified in [Naming convention](./names.md)

---

## 1. Add the Bus Configuration File

Create a new CSV configuration file named:

config_{BUSNAME}.csv

### Location

The file must be placed in:

{CONFIG_ROOT}/configs/embedded

and 

{CONFIG_ROOT}/configs/hpc

Where {CONFIG_ROOT} is the root configuration directory

---

## 2. Update the Makefile

The Makefile of the {CONFIG_ROOT} must be extended to:
- Declare the INPUT_{BUSNAME}\_CSV variable containing the path of the new bus .csv file
- Declare the OUTPUT_{BUSNAME}\_CROSSBAR, OUTPUT_{BUSNAME}\_SVINC and OUTPUT_{BUSNAME}\_CLK_ASSIGNMENTS (NonLeafBus only) variables containing the paths of the new bus configuration files to generate
- Add the corresponding build target in the form "config_{BUSNAME}"

All names must follow the `FULL_NAME` semantic.


---

## 3. Add a New Bus Python Class

Create a new Python file in:

{CONFIG_ROOT}/simply_v_conf/buses/

### Class Inheritance

The bus class must inherit from one of the following base classes:

- LeafBus
- NonLeafBus

Choose the base class according to the type of bus being implemented.



### Legal Attribute Extensions

#### NonLeafBus

If the bus is a NonLeafBus, the class must extend:

- LEGAL_PERIPHERALS
- LEGAL_BUSES
- LEGAL_PROTOCOLS

These must extend the corresponding attributes of the parent class.

#### LeafBus

If the bus is a LeafBus, the class must extend:

- LEGAL_PERIPHERALS
- LEGAL_PROTOCOLS



### Example: HBUS Implementation

Example from the already implemented HBUS class:

LEGAL_PERIPHERALS = Bus.LEGAL_PERIPHERALS + ("DDR4CH",)  
LEGAL_BUSES = NonLeafBus.LEGAL_BUSES + ("MBUS",)  
LEGAL_PROTOCOLS = Bus.LEGAL_PROTOCOLS + ("AXI4",)  





---

## 4. Register the Bus in the Bus Factory

Update the create_bus method in `buses_factory.py`.

Add a new case that:
- Matches the bus `BASE_NAME`
- Instantiates and returns the new bus class

This ensures the bus can be created correctly when requested.

---

## 5. More complex Buses and Parser Extensions

For buses that require new configuration parameters not supported by existing implementations:

- The parser hierarchy must be extended
- New parsing and validation logic must be added

Refer to the header documentation in parser.py for Parser hierarchy design, extension guidelines and intended input parameters validation flow
