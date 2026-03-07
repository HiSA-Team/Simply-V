# Factory

## Purpose

The `Factory` hierarchy is intended to act as a **centralized object creation point**
in order to:

- Enforce consistent naming conventions (defined in [Naming convention](./names.md))
- Perform general validation checks based on **Node name(s)**

This design intentionally differs from the classic *idiomatic factory method*
pattern. Instead of defining a concrete factory for each concrete object type,
a more compact approach using switch cases on {BASE_NAME}s
is used since the current object creation logic is very simple.


## Global Validation

All factories are implemented as **singletons**, meaning they
can track every created object using the `ALREADY_CREATED` variable.
This allows them to ensure no two peripherals or buses share the same `FULL_NAME` anywhere
in the configuration.
