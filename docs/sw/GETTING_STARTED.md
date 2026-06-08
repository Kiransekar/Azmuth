<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Getting Started with Azmuth

**Audit reference:** Software §S7.3
**Date:** 2026-06-06

## What You'll Need

1. **RISC-V GNU Toolchain** — `riscv64-unknown-elf-gcc` with RV32I support
2. **Simulation tool** — `iverilog` + `vvp` (included) or Verilator
3. **GNU Make**

## Step 1: Install the Toolchain

### Ubuntu/Debian
```bash
sudo apt install gcc-riscv64-unknown-elf
```

### From Source
```bash
git clone https://github.com/riscv-collab/riscv-gnu-toolchain
cd riscv-gnu-toolchain
./configure --prefix=/opt/riscv --with-arch=rv32i --with-abi=ilp32
make -j$(nproc)
export PATH=/opt/riscv/bin:$PATH
```

## Step 2: Build the SDK

```bash
cd NeuroRiscV/sdk
make
# Creates lib/libxcew.a
```

## Step 3: Build Your First Program

Create `my_first_app.c`:

```c
#include "azmuth/xcew.h"

static volatile uint32_t *const UART = (volatile uint32_t *)0x10000000;

int main(void) {
    /* Write to UART */
    const char *msg = "Hello from Azmuth!\n";
    while (*msg) *UART = (uint32_t)*msg++;

    /* Try EML */
    xcew_eml_t eml;
    xcew_eml_init(&eml, 0);
    uint32_t result;
    xcew_eml_compute(&eml, 0x00010000, &result);  /* exp(1.0) */
    xcew_eml_close(&eml);

    return 0;
}
```

Build it:

```bash
riscv64-unknown-elf-gcc \
    -march=rv32i -mabi=ilp32 -Os -fno-pic -nostdlib -ffreestanding \
    -Iinclude \
    -T ../toolchain/ldscripts/azmuth_minimal.ld \
    ../firmware/crt0.S ../firmware/trap_handler.S \
    my_first_app.c \
    -Llib -lxcew \
    -o my_first_app.elf
```

## Step 4: Run in Simulation

```bash
# Convert to hex
riscv64-unknown-elf-objcopy -O verilog my_first_app.elf my_first_app.hex

# Run RTL simulation
cd ..
make sim_core  # Uses the default test program
# Or load your hex into the testbench memory
```

## Step 5: Examine the Output

Simulation output appears on stdout (UART writes). Look for your message.

## Next Steps

- Read the [SDK User Guide](SDK_USER_GUIDE.md) for full API documentation
- Study the [Programming Model](PROGRAMMING_MODEL.md) for architecture details
- Browse [examples/](../../sdk/examples/) for complete programs
- Check [ABI.md](ABI.md) for compiler flag reference

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `riscv64-unknown-elf-gcc: not found` | Install RISC-V toolchain (Step 1) |
| Linker errors about `_start` | Include `crt0.S` in compilation |
| Simulation hangs | Check `mtvec` is set before enabling interrupts |
| EML returns 0 | Verify `xcew_cfg` CSR is initialized |
| Build-id note at reset vector | Add `-Wl,--build-id=none` to CFLAGS |
