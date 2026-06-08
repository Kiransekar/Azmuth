<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Debug Module Architecture Specification

**Audit reference:** Tapeout §3.5.1
**Date:** 2026-06-06
**Standard:** RISC-V External Debug Support Version 0.13.2

## Overview

The Debug Module (DM) enables external debugging of the Azmuth processor via
standard tools (OpenOCD, GDB). It implements the minimum viable subset of the
RISC-V Debug Spec 0.13.2 required for halt-mode debugging.

## Scope (per DECISION-004)

### Implemented (v1.1)
- Hart halt, resume, single-step
- GPR access (32 × 32-bit integer registers)
- CSR access (all implemented CSRs)
- 2 hardware breakpoints (match on instruction address)
- Program buffer (2 words)
- JTAG Debug Transport Module (DTM)
- Abstract commands: Access Register

### Explicitly excluded (deferred to v1.2)
- Memory access via system bus (SBA)
- Multiple harts
- Trigger Module beyond simple instruction address match
- Quick access
- Abstract commands: Access Memory

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ External                                                 │
│  ┌──────┐    JTAG     ┌──────┐    DMI     ┌──────────┐  │
│  │ JTAG │──(TCK/TMS)─▶│ DTM  │──(bus)───▶│  Debug   │  │
│  │ Probe│◀──(TDO)─────│      │◀──────────│  Module   │  │
│  └──────┘             └──────┘           │  (DM)    │  │
│                                           └─────┬────┘  │
│                                                 │        │
│              ┌──────────────────────────────────┘        │
│              │ halt_req, resume_req, reg_access           │
│              ▼                                           │
│  ┌───────────────────┐    ┌────────────┐                 │
│  │   RISC-V Core     │    │ AXI Master │                 │
│  │  (riscv_core.v)   │    │  (m1 port) │                 │
│  │  + debug state    │    └────────────┘                 │
│  └───────────────────┘                                   │
└─────────────────────────────────────────────────────────┘
```

## Register Map (Debug Module)

| Offset | Name | R/W | Description |
|--------|------|-----|-------------|
| 0x04 | dmstatus | RO | Debug Module status (version, halt status) |
| 0x10 | dmcontrol | RW | Hart select, halt/resume request, ndmreset |
| 0x11 | hartinfo | RO | Hart information (data registers, nscratch) |
| 0x12 | haltsum0 | RO | Halt summary (1 bit per hart) |
| 0x16 | abstractcs | RO | Abstract command status (busy, cmderr) |
| 0x17 | command | WO | Abstract command (register access) |
| 0x20–0x21 | progbuf0–1 | RW | Program buffer (2 words) |
| 0x04–0x0F | data0–11 | RW | Abstract data registers |

## JTAG DTM

| Signal | Direction | Description |
|--------|-----------|-------------|
| TCK | Input | Test clock (≤20 MHz) |
| TMS | Input | Test mode select |
| TDI | Input | Test data in |
| TDO | Output | Test data out |
| TRST_n | Input | Test reset (active low, optional) |

- **IDCODE:** `0x00000001` (placeholder; final value per DECISION-006)
- **DMI address width:** 7 bits (128 addressable DM registers)
- **DTM version:** 0.13.2

## Core Integration

The debug module connects to `riscv_core.v` via the following interface:

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| dbg_halt_req | DM→Core | 1 | Request core to halt |
| dbg_resume_req | DM→Core | 1 | Request core to resume |
| dbg_step | DM→Core | 1 | Single-step mode |
| dbg_halted | Core→DM | 1 | Core is halted |
| dbg_running | Core→DM | 1 | Core is running |
| dbg_reg_addr | DM→Core | 16 | Register address (GPR 0x1000+, CSR addr) |
| dbg_reg_wdata | DM→Core | 32 | Register write data |
| dbg_reg_we | DM→Core | 1 | Register write enable |
| dbg_reg_rdata | Core→DM | 32 | Register read data |

## Security Model (§3.5.7)

- **DEBUG_EN strap:** External pin; when low (production), DM is permanently
  disabled — TCK is gated, DMI bus is tied off, debug state machine is reset
- **Sticky debug-occurred flag:** CSR bit set on any debug halt event; only
  cleared by full POR. Firmware checks at boot to detect debug tampering
- **NVM access blocked in debug mode:** When `dbg_halted`, NVM CSR writes are
  suppressed (prevents IP extraction via debug)

## CDC Considerations (§3.5.6)

TCK is asynchronous to i_clk_core. All DMI bus signals crossing TCK→core must
pass through 2-FF synchronizers. MTBF at 20 MHz TCK, 250 MHz core:
~10^15 hours (exceeds product lifetime).

## Files (planned)

| File | Purpose |
|------|---------|
| `rtl/debug/dm_top.v` | Debug Module top |
| `rtl/debug/dm_regfile.v` | DM register file |
| `rtl/debug/dm_abstract_cmd.v` | Abstract command engine |
| `rtl/debug/dm_progbuf.v` | Program buffer |
| `rtl/debug/dm_trigger.v` | Hardware breakpoint logic |
| `rtl/debug/debug_rom.v` | Debug ROM (halt/resume sequences) |
| `rtl/debug/dtm/jtag_tap.v` | JTAG TAP controller |
| `rtl/debug/dtm/jtag_dr.v` | JTAG data register (DMI) |
| `rtl/debug/dtm/dtm_top.v` | DTM top-level |
