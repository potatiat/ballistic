<h1 align="center">
  The Ballistic JIT Engine
</h1>

<p align="center"><em>„The world's fastest ARM recompiler“</em></p>

# Overview

This is a rewrite of the dynarmic recompiler, with the goal of fixing its many flaws.

# CPU Cache Constraints

Ballistic is being designed to have an extremely low Cache Footprint:

1. L1d: 4 KB
2. L2: 30 KB

# Version 1.0 Goals

- [X] Create Tier 1 backend compiler.
- [ ] Create Tier 2 backend compiler.
- [ ] Support `MOVZ`, `MOVK`, `MOVN` instructions on both compilers.
- [ ] Treat `PACISAP` and `AUTISAP` as `NOP` then strip the upper bits of `X30`.
- [ ] Add more peephole optimizations.
- [ ] Have 100% branch coverage.
- [X] Have a config to change Ballistic behavior at runtime.
- [ ] Support Block linking.
- [X] Map ARM flags to x86 flags.
- [ ] Support 128-bit types and x86 SSE/AVX instructions.
- [ ] Add exception handling and recover guest CPU state.
- [ ] Add register spilling.
- [ ] Add Software Page Tables for MMIO and expose the page table memory layout.
- [ ] Handle Guest W^X and Guest RO/RW.
- [ ] Support Guest Write permissions and MMIO write traps for `bal_translate_write_function_t`.
- [ ] Allow the Guest to inform the memory subsystem that a Guest page has changed state.
- [ ] Invalidate JIT caches when Guest memory is modified using `bal_invalidate_git_cache_function_t`.
- [ ] Trap cache maintanence instructions then invalidate the block cache at that GVA.
- [ ] Track multiple address spaces with ASIDs.
- [ ] Handle memory aliasing and cache attributes (CPU: Cached, GPU: Cached/Write-Combining)
- [ ] Rewrite `tools/cdoc.c`
- [X] Rewrite all Python scripts in Lua.
- [ ] Add code examples on how to use a header file like in `bal_x86_sliding_window.h`.
- [ ] Reorganize all functions in alphabetical order in `.c` and `.h` files.
- [ ] Add benchmarks measuring compilation speed compared to other JIT compilers.

# Building Ballistic

Ballistic actively supports `clang` and `MSVC` only.

## Install Dependencies

### macOS

```bash
brew install cmake luajit
```

### Debian/Ubuntu

```bash
sudo apt update
sudo apt install build-essential cmake luajit
```

### Fedora

```bash
sudo dnf install cmake clang luajit 
```

### Windows

1. Install [Choco](https://chocolatey.org/install).
2. Run the following commands in PowerShell administrator mode:

```
# Allow running local PowerShell scripts 
Set-ExecutionPolicy RemoteSigned

./tools/ci/setup_dependencies.ps1
```

## Configure CMake

```bash
make ballistic-configure
```

## Build Binaries

```bash
make ballistic-build
```

If you are using Visual Studio and get the error:

```c++
#error "Ballistic requires a 64-bit ARM or x86 environment."
```

make sure you are running your developer terminal in 64-bit mode.

The compiled executables will be created in the `build/debug/bin` and `build/debug/lib` directories.

# CLion

You can generate Makefile Run targets with `tools/scripts/setup_clion_workspace.sh` and CLion will automatically detect
them.
