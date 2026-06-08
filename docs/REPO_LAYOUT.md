<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Toolchain Repository Layout

**Audit reference:** Software §S0.1
**Date:** 2026-06-06

## Directory Structure

```
NeuroRiscV/
├── rtl/                    # RTL source (Verilog-2001)
│   ├── core/               # RISC-V core + Xcew control
│   ├── eml/                # EML accelerator
│   ├── snn/                # SNN classifier + STDP
│   ├── security/           # Fault monitor, ECC, watchdog
│   ├── power/              # Orchestrator, body-bias, retention
│   ├── soc/                # AXI interconnect
│   └── rtl_list.f          # Synthesis file list
│
├── tb/                     # Testbenches (simulation only)
│   ├── asm/                # Assembly test programs
│   └── *_tb.v              # Per-module testbenches
│
├── sby/                    # Formal verification (SymbiYosys)
│   ├── *.sby               # SBY configuration files
│   └── *_fv.sv             # SVA property wrappers
│
├── firmware/               # Bare-metal firmware
│   ├── crt0.S              # C runtime startup
│   ├── trap_handler.S      # M-mode trap handler
│   └── boot.S              # Boot ROM source (planned)
│
├── sdk/                    # Software Development Kit
│   ├── include/azmuth/     # Public API headers
│   │   ├── xcew.h          # libxcew C API
│   │   └── csr.h           # CSR definitions
│   ├── src/                # libxcew implementation
│   │   ├── xcew_eml.c      # EML subsystem
│   │   ├── xcew_snn.c      # SNN subsystem
│   │   └── xcew_sys.c      # NVM, policy, power, fault
│   ├── examples/           # Example programs
│   ├── lib/                # Built libraries (generated)
│   └── Makefile            # SDK build
│
├── toolchain/              # Toolchain configuration
│   ├── ldscripts/          # Linker scripts
│   │   └── azmuth_minimal.ld
│   ├── riscof/             # RISCOF configuration
│   ├── LICENSES.md         # Upstream license inventory
│   └── VERSIONS.md         # Tool version pinning
│
├── flow/                   # EDA flow scripts
│   ├── lint.sh             # Linting (iverilog)
│   ├── sim.sh              # Simulation
│   ├── synth.sh            # Synthesis (Yosys)
│   ├── pnr.sh              # Place & Route (OpenROAD)
│   ├── signoff.sh          # Signoff (STA, DRC, LVS)
│   ├── formal.sh           # Formal verification (SBY)
│   ├── compliance.sh       # RISCOF compliance
│   └── README.md           # Flow documentation
│
├── syn/                    # Synthesis constraints
│   ├── upf_v1.1_final.tcl  # UPF power intent
│   └── *.sdc               # Timing constraints
│
├── reports/                # Verification evidence
│   ├── latest -> YYYY-MM-DD # Symlink to latest run
│   └── YYYY-MM-DD/
│       ├── sim/            # Simulation logs
│       ├── formal/         # Formal proof results
│       ├── synth/          # Synthesis QoR
│       └── compliance/     # RISCOF signatures
│
├── docs/                   # Documentation
│   ├── MICRO_ARCH_SPEC.md  # Microarchitecture specification
│   ├── TRACEABILITY.csv    # Requirements traceability
│   ├── TRACEABILITY.md     # Human-readable traceability
│   ├── VERIFICATION_PLAN.md # Verification plan
│   ├── CDC_ANALYSIS.md     # Clock domain crossing analysis
│   ├── RESET_ARCH.md       # Reset architecture
│   ├── POR_SEQUENCE.md     # Power-on reset sequence
│   ├── BOOT_ROM_SPEC.md    # Boot ROM specification
│   ├── DEBUG_ARCH_SPEC.md  # Debug Module spec
│   ├── AUDIT_PROGRESS.md   # Audit progress tracker
│   ├── DECISIONS.md        # Design decisions log
│   ├── BUG_RETROSPECTIVE.md # Bug analysis
│   ├── AZMUTH_TAPEOUT_AUDIT.md     # Tapeout audit (READ ONLY)
│   ├── AZMUTH_SOFTWARE_TOOLCHAIN_AUDIT.md  # SW audit (READ ONLY)
│   ├── sw/                 # Software-specific docs
│   │   ├── xcew_inline_asm.md
│   │   ├── PROGRAMMING_MODEL.md
│   │   └── ABI.md
│   └── evidence/           # Certification evidence
│       ├── cc/             # Common Criteria
│       ├── compliance/     # RISC-V compatibility
│       ├── power/          # UPF reconciliation
│       ├── security/       # Security test reports
│       └── snn/            # SNN analysis
│
├── scripts/                # Utility scripts
│   └── add_spdx.py         # SPDX header management
│
├── Makefile                # Top-level build
├── CLAUDE.md               # Project context
├── CHANGELOG.md            # Version history
├── SECURITY.md             # Security policy
├── LICENSE                 # Proprietary license
└── README.md               # Project overview
```

## Key Conventions

1. **RTL is Verilog-2001 only.** SystemVerilog is used only in `sby/*_fv.sv`
   (formal property wrappers), never in synthesizable RTL.
2. **Audit documents are READ-ONLY.** Progress is tracked in `AUDIT_PROGRESS.md`.
3. **Evidence goes in `reports/YYYY-MM-DD/`.** The `reports/latest` symlink
   always points to the most recent run.
4. **SDK headers are the stable public API.** Changes to `sdk/include/azmuth/`
   follow the compatibility policy in `COMPATIBILITY.md`.
5. **SPDX headers on every source file.** Enforced by `scripts/add_spdx.py --check`.
