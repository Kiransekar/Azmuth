<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# GDB Server Configuration for Azmuth

**Audit reference:** Software §S5.2
**Date:** 2026-06-06

## Quick Start

### Start OpenOCD
```bash
openocd -f toolchain/openocd/azmuth.cfg
```

### Connect with GDB
```bash
riscv64-unknown-elf-gdb my_program.elf
(gdb) target extended-remote :3333
(gdb) load
(gdb) break main
(gdb) continue
```

## GDB Commands for Azmuth

### Standard RISC-V debugging
```
(gdb) info registers          # Show all GPRs
(gdb) info registers pc       # Show PC
(gdb) x/10i $pc               # Disassemble from PC
(gdb) stepi                   # Single instruction step
```

### Xcew CSR access
```
(gdb) monitor reg xcew_cfg    # Read xcew_cfg CSR
(gdb) monitor reg 0x7C0       # Read CSR by address
(gdb) monitor reg 0x7CC       # Read fault_status
```

### Memory examination
```
(gdb) x/4xw 0x10000000       # UART TX register
(gdb) x/16xw 0x00010000      # SRAM base
(gdb) x/4xw 0x4000           # NVM window
```

### Watchpoints and breakpoints
```
(gdb) watch *(uint32_t*)0x7CC  # Break on fault status change
(gdb) break *0x00000100        # Break at address
(gdb) hbreak main              # Hardware breakpoint
```

## Semihosting

Azmuth supports ARM-style semihosting via EBREAK:

```bash
# Enable in OpenOCD
openocd -f toolchain/openocd/azmuth.cfg -c "arm semihosting enable"
```

```c
// In firmware — printf redirected to host terminal
#include <stdio.h>
printf("Hello from Azmuth!\n");
```

## Flash Programming

```bash
# Program NVM via OpenOCD
openocd -f toolchain/openocd/azmuth.cfg \
    -c "program my_firmware.elf verify reset exit"
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `Error: JTAG scan chain interrogation failed` | Check JTAG wiring, adapter speed |
| `Error: unable to halt` | Check mtvec is set, try `reset halt` |
| `Error: Timed out` | Reduce adapter speed to 100 kHz |
| CSR reads return 0 | Verify DEBUG_EN strap is high |
