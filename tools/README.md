# Tools

This folder holds scripts needed to build Ballistic and standalone programs used for testing Ballistic.

## Standalone Programs

These programs will appear in the directory you compile Ballistic in.

### Decoder CLI

This program is used for decoding ARM64 instructions. The following example shows how to use it:

```bash
./decoder_cli 0b5f1da1 # ADD extended registers
Mnemonic: ADD - Mask: 0x7F200000 - Expected: 0x0B000000
```

## Scripts

These scripts are solely used for building Ballistic and are called by CMake.

### Generate A64 Table

This script parses the Official ARM Machine Readable Architecture Specification XML files in `spec/` and generates a
hash table that's used by Ballistic's decoder to lookup instructions.

### Doctest

This script extracts, compiles, and validates code examples written in the documentation. This replicates Rust's doctest
feature, where users can embed code in documentation using markdown. This script can be run in the `build/` directory
using `ctest --verbose -R DocTest`.
