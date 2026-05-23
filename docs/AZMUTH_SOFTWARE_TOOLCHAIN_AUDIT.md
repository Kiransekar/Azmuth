<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Azmuth Software Toolchain & SDK Readiness Audit

**Project:** Azmuth — Xcew RISC-V Processor v1.1
**Companion document to:** `AZMUTH_TAPEOUT_AUDIT.md` (hardware tapeout readiness)
**Status:** Working document (LIVE — update on every check completion)
**Owner:** Kiransekar (team lead)
**Cert anchors:** RISC-V toolchain compatibility (LLVM/GCC patch quality, intrinsics ABI stability) + CC EAL2 software-side evidence (development environment integrity, delivery procedures)

---

## Executive Summary

A processor without a usable software toolchain has no market. The hardware audit covers silicon readiness; this document covers everything an adopter needs between writing C code and running it on Azmuth.

**Current state of Azmuth software, inferred from repo:**

- `toolchain/` directory exists — contents not yet reviewed in this audit; status unknown.
- `firmware/` contains `boot.S` and `main.c` per README.
- README declares `riscv64-unknown-elf-gcc` as a prerequisite — i.e. **standard upstream GCC for RV32**, with no demonstrated patching for Xcew custom instructions.
- Python golden model exists for EML expressions.
- Co-simulation harness exists.

**Architectural decisions affecting software** (from hardware audit DECISION-005, five-lever optimization for ChipIgnite shuttle fit):

- **NVM is now external QSPI** (Lever L1). The libxcew NVM API stays unchanged; underneath, the controller drives an external part. Software-visible change: bring-up procedure includes QSPI flash initialization. Capacity claim grows ("up to 16 MB external ReRAM/flash" vs original "64 KB internal").
- **Debug transport is Caravel housekeeping SPI** (Lever L2) in the default v1.1 build. OpenOCD config uses an SPI bridge rather than direct JTAG. Adopter-facing experience identical (GDB attach over `:3333`); transport layer differs.
- **SNN is virtualized** (Lever L3, 128 physical / 256 logical, 200 MHz). No software impact — the libxcew SNN API still presents 256 neurons; underlying time-multiplexing is invisible. Cycles-per-classification documented honestly in performance guide.
- **EML cache is compressed** (Lever L4). No software impact — still 256-entry logical, adopter-visible hit rate within 2% of original.
- **Build via OpenLane within Caravel `user_project_wrapper`** (Lever L2 + ChipIgnite requirement). Firmware loads via Caravel's flash interface at boot; boot ROM handoff to user firmware sequenced through Caravel's management SoC.

**What this means:** Xcew custom opcodes (`0001011`, `0101011`, `1011011`, `1111011`) are currently invisible to the toolchain. Any program using Xcew operations today must use raw `.insn` directives or hand-encoded bytes. That works for internal testbench bring-up; it is not a usable adopter experience. An external user wanting to call `XCEW_EML` from C cannot do so without first patching their toolchain — which they will not do.

**Gap classes to close:**

1. **Compiler support** — Xcew instructions assembleable by mnemonic, callable as C intrinsics.
2. **Bootloader & startup** — Boot ROM contents specified; POR sequence software fully implements body-bias settling, ROM CRC, SRAM init, vector table.
3. **C library & runtime** — picolibc or newlib port with syscall stubs, soft-float library (no FPU in RV32IMC), printf/io routes.
4. **Xcew C API** — A `libxcew` providing high-level access to EML, SNN, NVM, policy, power — not just raw intrinsics.
5. **Debug infrastructure** — RISC-V Debug Module **is now in v1.1 scope** (hardware audit Section 3.5, decision DECISION-004). Software side: OpenOCD config, GDB integration, debug-mode workflows.
6. **SDK & examples** — a downloadable SDK with a "Hello, Azmuth" example, an EML demo, an SNN classifier demo, an NVM example, a debug workflow demo, and a CEW-domain reference application.
7. **Verification** — compiler regression suite, library unit tests, ABI compliance.
8. **Distribution** — versioned releases, reproducible builds, upstream patch strategy.

---

## How To Use This Document

Same conventions as the hardware audit:

- **[ ] HARD GATE** — must PASS before SDK v1.0 release.
- **[ ] EVIDENCE** — written artifact in `docs/evidence/software/`.
- **[ ] REVIEW** — design or process review with written outcome.

**Pair assignments** (added for software):

- **Pair E — Software Toolchain & SDK** (compiler/assembler patches, libxcew, examples)
- **Pair F — Bootloader, Runtime & Debug** (boot ROM, libc port, debug infrastructure)

If the team is at 8 students, this expands to 5–6 pairs and one or two students will cross-cover. If at 6, two students take software as their full charter (Pair E+F merged into one Software Pair owning S1–S8 with hardware Pair D supporting on debug-module hardware).

The team lead should decide pair structure and document in `docs/DECISIONS.md` as DECISION-002 (after the PDK decision).

---

## Section S0 — Toolchain Hygiene & Reproducibility

**Why first:** Same reason as hardware Section 0. A toolchain with un-pinned versions, manual build steps, or "works on my machine" reproducibility is a non-starter for commercial adopters and for CC EAL2 delivery-procedures evidence.

### S0.1 [ ] HARD GATE — Toolchain repository structure

**Current state:** `toolchain/` exists; contents not surveyed in this audit. Likely either GCC fork, LLVM patches, or build scripts pointing at upstream.

**Action:** Survey current contents. Reorganize into the following structure:

```
toolchain/
├── README.md              # What this is, how to build it
├── llvm/                  # LLVM/Clang patches (recommended primary)
│   ├── patches/           # Numbered .patch files against pinned upstream commit
│   ├── upstream.txt       # Upstream commit SHA being patched
│   └── build.sh           # Reproducible build script
├── gcc/                   # GCC patches (secondary, optional)
│   ├── patches/
│   ├── upstream.txt
│   └── build.sh
├── binutils/              # Assembler / linker patches
│   ├── patches/
│   ├── upstream.txt
│   └── build.sh
├── picolibc/              # C library port (or newlib/)
│   ├── port/              # Azmuth-specific files
│   └── build.sh
├── openocd/               # Debug adapter config
│   ├── azmuth.cfg
│   └── build.sh
└── docker/
    └── Dockerfile         # Full reproducible toolchain image
```

**PASS:** Directory structure as above. README describes purpose of each subdirectory. No floating scripts at `toolchain/` root.
**Owner:** Pair E

### S0.2 [ ] HARD GATE — Pinned upstream versions

**Action:** Every external dependency pinned by exact commit SHA, not tag or branch. Document in `toolchain/VERSIONS.md`:

| Component | Upstream URL | Pinned SHA | Date pinned | Rationale |
|-----------|-------------|------------|-------------|-----------|
| LLVM | github.com/llvm/llvm-project | abc123... | YYYY-MM-DD | Latest stable with riscv-custom support |
| binutils | sourceware.org/git/binutils-gdb.git | def456... | YYYY-MM-DD | Latest with `.insn` improvements |
| picolibc | github.com/picolibc/picolibc | 789ghi... | YYYY-MM-DD | v1.8.x stable |
| OpenOCD | github.com/openocd-org/openocd | jkl012... | YYYY-MM-DD | Includes RISC-V Debug 0.13 support |

**PASS:** `VERSIONS.md` present with all four (or more) entries. Each pin has a build that succeeds in CI.
**Owner:** Pair E

### S0.3 [ ] HARD GATE — Reproducible toolchain build via Docker

**Action:** `toolchain/docker/Dockerfile` builds the full toolchain from scratch starting from a pinned base image (e.g. `ubuntu:24.04@sha256:...`). Anyone running `docker build` produces a byte-identical toolchain image.

The image is the **single delivery vehicle** for the toolchain. Adopters never build from source themselves; they pull the image.

**PASS:** `docker build` succeeds on a clean machine. Resulting image's `riscv32-azmuth-elf-clang --version` and `riscv32-azmuth-elf-as --version` both report Azmuth tag. CI workflow builds and tags the image on every release.
**FAIL:** Build requires manual steps. Image build is non-reproducible (different SHA on different days from same Dockerfile).
**Owner:** Pair E

### S0.4 [x] EVIDENCE — Toolchain license audit

**Action:** Document the license of every component in `toolchain/LICENSES.md`. GCC is GPL-3; LLVM is Apache-2.0 with LLVM exception; binutils is GPL-3; picolibc is BSD-3; newlib is mixed (BSD/GPL). The Azmuth patches inherit each upstream's license.

For commercial adoption: confirm no AGPL/copyleft contamination in any path an adopter would link against. picolibc is preferred over newlib partly for this (cleaner license).

**PASS:** License of every dependency documented. No surprises for an adopter.
**Owner:** Pair A + Pair E

---

## Section S1 — Compiler & Assembler Support

**Why critical:** Xcew is what makes Azmuth different. If Xcew is unreachable from C without `.insn` magic, no adopter will use it. The compiler is the first interaction with your processor.

### S1.1 [ ] REVIEW — LLVM vs GCC primary toolchain decision

**Recommendation:** LLVM/Clang as primary, GCC as secondary.

Rationale:

- LLVM has cleaner extension architecture (TableGen-based instruction definitions). Adding a custom RISC-V extension means writing a `RISCVInstrInfoXcew.td` file, defining intrinsics in `IntrinsicsRISCV.td`, and patches to `RISCVInstPrinter.cpp` and `RISCVAsmParser.cpp`. Order of hundreds of lines for full support.
- GCC requires changes to multiple subdirectories (`gcc/config/riscv/`, `binutils/opcodes/`), more invasive, harder to maintain across upstream rebases.
- LLVM's permissive license is friendlier for downstream commercial use than GCC's GPL-3 runtime exception complexity.
- Most RISC-V commercial toolchain vendors (SiFive, Codasip via picolibc-on-LLVM, Andes for newer products) prioritize LLVM.

**Action:** Decide. Document in `docs/DECISIONS.md` as DECISION-003. If team has stronger GCC experience, GCC primary is also acceptable — the rest of this section adapts symmetrically.

**PASS:** Decision documented with rationale.
**Owner:** Team lead + Pair E

### S1.2 [ ] HARD GATE — Assembler mnemonic support for Xcew opcodes

**Action:** Patch binutils so the assembler accepts Xcew mnemonics:

```
xcew.eml      rd, rs1, rs2        # 0001011
xcew.pol_upd  rd, rs1, rs2        # 0101011
xcew.snn_cls  rd, rs1, rs2        # 1011011
xcew.misc     rd, rs1, rs2        # 1111011
```

Plus sub-encodings within each opcode for the 6 Xcew IDs (EML, CFG, MLOAD, MSTORE, SNN, POL_UPD). The decision on instruction format (R-type with funct3/funct7 sub-encoding) drives the assembler syntax.

**PASS:** A test file using all four mnemonics assembles cleanly via `riscv32-azmuth-elf-as`. Disassembler (`riscv32-azmuth-elf-objdump`) round-trips back to mnemonic form. Test committed at `toolchain/tests/assembler/xcew_mnemonics.s`.
**FAIL:** Any Xcew opcode requires `.insn` hand-encoding to use.
**Owner:** Pair E

### S1.3 [ ] HARD GATE — Compiler intrinsics

**Action:** Define Clang builtins (or GCC `__builtin_*`) for every Xcew operation:

```c
// In <azmuth/xcew.h>
unsigned int __builtin_xcew_eml(unsigned int expr_id, unsigned int operand);
unsigned int __builtin_xcew_snn_classify(unsigned int feature_vec_addr);
unsigned int __builtin_xcew_nvm_mload(unsigned int addr);
void         __builtin_xcew_nvm_mstore(unsigned int addr, unsigned int data);
void         __builtin_xcew_pol_update(unsigned int policy_id, unsigned int params);
void         __builtin_xcew_cfg(unsigned int cfg_word);
```

Each intrinsic compiles directly to the corresponding Xcew instruction with proper register allocation, no library call overhead, no memory access for the dispatch itself.

**PASS:** A C program calling each intrinsic compiles to one Xcew instruction per call. Verified by disassembly. Test cases at `toolchain/tests/intrinsics/`.
**Owner:** Pair E

### S1.4 [ ] HARD GATE — Inline assembly support via `.insn` fallback

**Action:** For environments where Azmuth toolchain isn't available, document `.insn` directives that emit Xcew instructions using stock upstream binutils. Example:

```c
#define XCEW_EML_RAW(rd, rs1, rs2) \
    asm volatile (".insn r 0x0B, 0, 0, %0, %1, %2" \
                  : "=r"(rd) : "r"(rs1), "r"(rs2))
```

Document each pattern in `docs/sw/xcew_inline_asm.md` for adopters who want to evaluate without committing to the full toolchain.

**PASS:** Inline asm macros documented and tested.
**Owner:** Pair E

### S1.5 [ ] HARD GATE — Compiler regression suite passing

**Action:** Run the upstream LLVM (or GCC) RISC-V test suite against the patched toolchain. Specifically:

- `llvm/test/CodeGen/RISCV/` — full pass rate maintained against upstream baseline.
- `llvm/test/MC/RISCV/` — assembler test rate maintained.
- New tests added for Xcew in `llvm/test/CodeGen/RISCV/xcew/` and `llvm/test/MC/RISCV/xcew/`.

**PASS:** Upstream pass rate ≥99% (allowing for known upstream flaky tests). All Xcew tests pass. Test log at `docs/evidence/software/llvm_regression_log.txt`.
**FAIL:** Patched toolchain regresses upstream behavior.
**Owner:** Pair E

### S1.6 [ ] EVIDENCE — Upstream patch strategy

**Action:** Document in `toolchain/UPSTREAM_STRATEGY.md`:

- Patches are organized for eventual upstream submission.
- Each patch has a commit message in upstream-acceptable form.
- Patches are rebased onto upstream main monthly (or quarterly minimum).
- A roadmap entry for when each patch will be proposed upstream (or held back as proprietary).

Even if you don't upstream Xcew (it's your IP), maintaining patches in upstream-acceptable form means a low-friction rebase whenever LLVM moves.

**PASS:** Strategy documented. First rebase scheduled.
**Owner:** Pair E

---

## Section S2 — Bootloader & Startup Code

**Why:** Boot ROM is 4KB. Every byte counts. POR sequencing involves hardware-software coordination (body-bias settling, ECC scrub, SRAM init) that must be correct or the chip never reaches main().

### S2.1 [ ] HARD GATE — Boot ROM specification

**Action:** Create `docs/BOOT_ROM_SPEC.md` covering:

- Memory layout of the 4KB ROM (reset vector, vector table, boot code, constants, CRC trailer)
- **Caravel handoff sequence** (per DECISION-005, Azmuth ships in Caravel's user_project_wrapper):
  1. Caravel's management SoC powers up first, runs its own bootloader from QSPI flash
  2. Caravel writes user-area enable / user firmware load instructions via wishbone
  3. Caravel releases reset to user area (Azmuth)
  4. PC = `0x0000` in Azmuth user-area boot ROM
- Boot sequence step-by-step (Azmuth side):
  1. PC = `0x0000` after Caravel-side reset release
  2. Wait for body-bias DAC calibration complete (poll bit in `bias_ctrl` CSR 0x7C9)
  3. Verify ROM CRC-32 against stored value (last 4 bytes of ROM)
  4. **Initialize external QSPI NVM** (Lever L1): issue READ_ID to verify part presence, configure dummy cycles, read NVM device status. Failure → halt with NVM_NOT_DETECTED fault code.
  5. Initialize SRAM (clear or load from NVM)
  6. Configure interrupt vectors
  7. Configure default CSRs (xcew_cfg, sec_ctrl)
  8. Jump to `_start` in user firmware (loaded into SRAM from external NVM, or entry point at 0x1000 if running from SRAM image preloaded by Caravel)
- Failure handling: if ROM CRC fails → halt and assert fault. If body-bias cal times out → halt and assert fault. If external NVM doesn't respond → halt with NVM_NOT_DETECTED, but boot continues to a minimal monitor in ROM allowing debug attach.

This pairs with hardware Section 3.5 (POR sequence) and hardware Section 6.4 (Caravel integration).

**PASS:** Spec written, reviewed. Each step traces to a REQ-ID in the micro-arch spec.
**Owner:** Pair F

### S2.2 [ ] HARD GATE — Boot ROM source code

**Current state:** `firmware/boot.S` exists. Contents unknown to this audit.

**Action:** Review or rewrite `firmware/boot.S` to fully implement the boot sequence in S2.1. Target ≤2KB to leave headroom in the 4KB ROM. Use efficient RV32IMC encoding (compressed instructions where possible).

The boot code is itself an asset — write it cleanly, comment thoroughly, treat as IP.

**PASS:** Boot code implements every step from S2.1. Assembles cleanly. Disassembled listing reviewed line-by-line. Final binary size ≤2KB.
**Owner:** Pair F

### S2.3 [ ] HARD GATE — Linker scripts

**Action:** Provide linker scripts for typical configurations:

```
toolchain/ldscripts/
├── azmuth_minimal.ld         # Code-in-ROM, data-in-SRAM, no NVM
├── azmuth_nvm.ld             # Code loaded from external QSPI NVM at boot, runs from SRAM
├── azmuth_xip.ld             # Execute-in-place from external QSPI NVM (slow but possible)
└── azmuth_caravel.ld         # Caravel-deployed: firmware loaded by Caravel management SoC into Azmuth SRAM at startup; user_project_wrapper-aware memory map
```

Each script defines memory regions matching the chip memory map (Boot ROM 0x0000-0x0FFF, SRAM 0x1000-0x1FFF, external NVM via CSR-mapped controller at 0x4000-0x4FFF). Sections placed: `.text`, `.rodata`, `.data`, `.bss`, `.heap`, `.stack`, `.xcew_init` (for Xcew configuration tables).

The `azmuth_caravel.ld` variant accounts for: limited SRAM after Caravel-loaded code/data, no .text-in-ROM (Caravel loaded everything into SRAM), explicit reset vector at SRAM start.

**PASS:** All four linker scripts present, each builds a working hello-world example. Documented in `docs/sw/linker_scripts.md`. The Caravel variant verified through Caravel-level simulation.
**Owner:** Pair F

### S2.4 [ ] HARD GATE — crt0 startup code

**Action:** Provide `crt0.S` performing:

- Set up stack pointer to top of SRAM
- Clear `.bss`
- Copy `.data` from ROM/NVM to SRAM
- Run static C++ constructors (`__init_array` walk, if C++ support enabled)
- Set up trap handler vector base (`mtvec`)
- Call `main()`
- On `main()` return: trap to halt handler

**PASS:** `crt0.S` present, integrated with linker scripts. Hello-world example using `printf` runs end-to-end on Verilator co-simulation.
**Owner:** Pair F

### S2.5 [ ] HARD GATE — Vector table and trap handlers

**Action:** Provide a complete trap handler stub:

- Synchronous exceptions (illegal instruction, misaligned access, ECC double-bit, etc.)
- External interrupts (`o_irq_eml`, `o_irq_snn`, `o_irq_nvm`, `o_irq_fault`, `o_timeout_irq`)
- Each IRQ has a weak symbol the user can override (`__attribute__((weak)) void irq_eml_handler(void) { while(1); }`)
- Trap handler reads `mcause`, dispatches to the right handler, restores state, returns via `mret`

**PASS:** Trap handler exercised by a test program that triggers an illegal instruction, an EML IRQ, and an ECC fault — each correctly dispatched and recovered.
**Owner:** Pair F

### S2.6 [ ] EVIDENCE — Bootloader self-test

**Action:** A dedicated firmware image that exercises every step of the boot sequence and self-reports success/failure via UART or memory-mapped status register. Run on Verilator co-sim and ideally on silicon during bring-up.

**PASS:** Self-test passes on co-sim. Result format reusable on silicon bring-up.
**Owner:** Pair F

---

## Section S3 — C Library & Runtime

**Why:** Adopters write C. C needs `printf`, `memcpy`, `malloc`, `assert`. Without a libc port, users live in `void __builtin_*()` land. That's not adopter-grade.

### S3.1 [ ] HARD GATE — picolibc port

**Recommendation:** picolibc over newlib.

Rationale: smaller footprint (matters with 4KB SRAM), cleaner BSD license, modern build system, active maintainer, designed for embedded RISC-V from the outset.

**Action:** Port picolibc to Azmuth:

- Add target tuple `riscv32-azmuth-elf`
- Provide `.specs` file pointing the compiler at picolibc + Azmuth crt0 + Azmuth linker script
- Configure soft-float (no FPU in RV32IMC)
- Configure with `-mabi=ilp32` (or `-mabi=ilp32f` if FPU added later)
- Verify size: a "hello world" using printf should fit in <8KB (forcing NVM/SRAM-loaded execution model)

**PASS:** `riscv32-azmuth-elf-clang hello.c -specs=picolibc.specs -o hello.elf` produces a working binary. Hello-world via UART/semihosting works on co-sim.
**Owner:** Pair F

### S3.2 [ ] HARD GATE — Syscall stubs

**Action:** Implement minimal POSIX syscalls for picolibc:

- `_write(fd, buf, n)` — routes to UART (or semihosting if no UART on v1.1)
- `_read(fd, buf, n)` — UART input or semihosting
- `_sbrk(incr)` — heap pointer advance with stack overflow check
- `_exit(status)` — write status to a known register and halt
- `gettimeofday()` — read from a system timer (CSR `mcycle`-based stub if no RTC)

Place in `firmware/syscalls.c`.

**PASS:** All syscalls implemented. `printf` works on co-sim. `malloc` works without corruption (heap fragmentation test passes).
**Owner:** Pair F

### S3.3 [ ] HARD GATE — Soft-float library

**Current state:** RV32IMC has no F or D extension. Floating-point operations must be software-emulated.

**Action:** Use Compiler-RT (LLVM) or libgcc (GCC) soft-float. Verify it's linked correctly when `-mabi=ilp32` is set. Run a representative numerical benchmark — single-precision matrix-vector multiply, double-precision Newton iteration — verify correctness against host-machine reference.

**PASS:** Soft-float operations correct to IEEE-754 single-precision tolerance. Performance documented (cycles per float op) for adopter expectation-setting.
**Owner:** Pair F

### S3.4 [ ] EVIDENCE — Library footprint analysis

**Action:** Measure size impact of:

- Minimal program (return 0)
- Adding printf (likely +6–10KB)
- Adding malloc (+1–2KB)
- Adding soft-float (varies by usage; +2–8KB)
- Adding all of the above

Document in `docs/sw/footprint.md`. Adopters need this to plan their NVM layout.

**Owner:** Pair F

---

## Section S4 — Xcew Extension Software Support

**Why:** Intrinsics are the low-level access. Most adopters want a high-level C API: "classify this image with SNN," "evaluate this expression with EML," not "call `__builtin_xcew_snn_classify(0x...)` with the address of a struct you marshaled by hand."

### S4.1 [ ] HARD GATE — `libxcew` library design

**Action:** Create `sdk/libxcew/` providing a clean C API:

```c
// EML
typedef struct { uint32_t expr_id; uint32_t flags; } xcew_eml_t;
int  xcew_eml_init(xcew_eml_t *eml, uint32_t mode);
int  xcew_eml_compute(xcew_eml_t *eml, float input, float *output);
void xcew_eml_close(xcew_eml_t *eml);

// SNN
typedef struct { uint32_t tile_id; uint32_t neuron_count; } xcew_snn_t;
int  xcew_snn_init(xcew_snn_t *snn, uint32_t neuron_count);
int  xcew_snn_load_weights(xcew_snn_t *snn, const int8_t *weights, size_t len);
int  xcew_snn_classify(xcew_snn_t *snn, const int8_t *input, uint32_t *class_id);
int  xcew_snn_enable_stdp(xcew_snn_t *snn, uint32_t policy);
void xcew_snn_close(xcew_snn_t *snn);

// NVM
int  xcew_nvm_read(uint32_t addr, void *buf, size_t len);
int  xcew_nvm_write(uint32_t addr, const void *buf, size_t len);
int  xcew_nvm_get_stats(uint32_t *scrub_count, uint32_t *corrected_count);

// Policy
int  xcew_policy_set_deterministic(uint32_t max_cycles);
int  xcew_policy_update(uint32_t policy_id, uint32_t params);

// Power
int  xcew_pwr_tile_sleep(uint32_t tile_id);
int  xcew_pwr_tile_wake(uint32_t tile_id);
int  xcew_pwr_set_bias(int8_t bias_code);

// Fault
int  xcew_fault_get_status(uint32_t *fault_code);
int  xcew_fault_clear(uint32_t fault_mask);
```

This is the API adopters will write code against. Stable across hardware versions (so v1.2 doesn't break adopter code).

**PASS:** API headers under `sdk/include/azmuth/`. Implementation under `sdk/libxcew/src/`. Compiles and links.
**Owner:** Pair E

### S4.2 [ ] HARD GATE — `libxcew` implementation

**Action:** Implement each function. The pattern for most is: configure CSRs via inline asm + intrinsics, issue the Xcew instruction(s), poll completion or wait for IRQ, read results.

For EML specifically: handle the fixed-point conversion (Q16.16 used internally per bug list — wrap that in the API so adopters work in float).

For SNN: weight loading needs to traverse the NVM-mapped weight region; provide a high-level "load model from file" function. Note that SNN virtualization (hardware audit 1.5.2, Lever L3) is transparent to the API — the 256-neuron classify call behaves identically; underlying time-multiplexing is invisible.

For NVM: **per DECISION-005 Lever L1, NVM is external QSPI in v1.1.** The API contract is unchanged — `xcew_nvm_read` / `xcew_nvm_write` still work the same way, ECC is still SECDED, wear-leveling still tracked. The controller transparently drives external storage. Provide:

- Auto-detection of attached QSPI part at boot (READ_ID command in boot ROM, exposed via a libxcew status function)
- Support for common QSPI flash (Winbond W25Q, Cypress S25FL) and QSPI ReRAM (Adesto/Dialog) parts
- Capacity report function `xcew_nvm_get_capacity(uint32_t *bytes)` that reads from the controller's detected size — adopter no longer hard-codes 64 KB

**PASS:** Every API function implemented. Unit test per function passing on co-sim (with QSPI flash model). NVM tests pass against at least two distinct QSPI models to demonstrate part-flexibility.
**Owner:** Pair E

### S4.3 [ ] HARD GATE — EML expression DSL or compiler

**Why this exists:** EML evaluates expressions of form `exp/ln/sub`. Hand-writing these as raw expression IDs is awful. Provide a tool that takes a math expression in human-readable form and emits the EML configuration:

```
# Source (human writes this)
expr = ln(1 + exp(x - threshold))

# Tool runs:
$ xcew-eml-compile expr.eml -o expr.bin

# Adopter loads expr.bin into NVM, calls xcew_eml_compute with the bound ID.
```

Implementation can be a Python script in `sdk/tools/xcew-eml-compile/`. Output is the configuration bytes for the EML DAG cache and the constants needed.

**PASS:** Compiler accepts a small grammar (sum, product, exp, ln, sub, parens, identifiers, constants), outputs configuration bytes that, when loaded, produce correct expression evaluation. Round-trip tested against the Python golden model.
**Owner:** Pair E

### S4.4 [ ] HARD GATE — SNN model converter

**Action:** Provide `xcew-snn-convert` that takes a model from a common format (Norse / SpikingJelly / Lava / ONNX subset) and emits weight tables for the 256-neuron tile.

Without this, adopters have to manually rearrange weights to fit the tile architecture, which kills adoption for the SNN use case.

**PASS:** Converter takes at least one common-format model (recommend ONNX with custom spiking ops, or Norse format), produces working SNN weight tables. Demonstrated end-to-end with an MNIST-style benchmark on co-sim.
**Owner:** Pair E

### S4.5 [ ] EVIDENCE — Xcew programming model document

**Action:** Write `docs/sw/PROGRAMMING_MODEL.md` covering:

- When to use each Xcew unit (decision tree: dense compute → EML, classification → SNN, persistent state → NVM)
- Performance characteristics of each (cycles per operation, throughput, latency)
- Memory layout for each (where weights live, where inputs/outputs go)
- Power implications (which tiles sleep when not in use)
- Code examples for each major use case

**Owner:** Pair E

---

## Section S5 — Debug & Development Infrastructure

**Why:** Without GDB integration, debugging on Azmuth is "print statements and hope." For commercial adoption, JTAG-debugger support is table stakes.

### S5.1 [ ] HARD GATE — RISC-V Debug Module software integration

**Hardware status (as of DECISION-004):** Debug Module is included in Azmuth v1.1 silicon. Hardware audit Section 3.5 covers the RTL, JTAG DTM, hart-debug-state integration, security model, and end-to-end flow validation. This software item covers the adopter-facing tooling.

**Action:** Provide a complete debug software stack:

- OpenOCD configuration file (`toolchain/openocd/azmuth.cfg`) — see S5.3 for detailed requirements
- GDB integration via OpenOCD's GDB server on port 3333
- Documented workflow: build firmware → flash to NVM (or load to SRAM) → halt-on-reset → attach GDB → debug
- Worked examples in the SDK (Section S6) showing common debug scenarios: setting breakpoints, single-stepping through EML compute, inspecting Xcew CSRs, observing the SNN tile state
- Debug-mode operational notes: which CSRs are readable in debug mode, how to inspect NVM contents safely (in DEBUG_EN=high configuration), how to interpret `fault_status` after a fault

**PASS:** Full debug stack operational. Adopter can run `openocd -f azmuth.cfg` on Verilator-simulated JTAG, attach GDB, debug a real example program. Documented in `docs/sw/DEBUG_GUIDE.md`.
**FAIL:** Any step requires undocumented manual intervention.
**Owner:** Pair F (software) + DM pair (hardware audit 3.5.15) coordination required

### S5.2 [ ] HARD GATE — Verilator-based debug flow

**Action:** Provide a script `tools/debug-verilator` that:

- Builds the firmware
- Runs it on the Verilator model with full waveform capture
- Provides a GDB-style interface to inspect register state at each cycle
- Maps `printf` output through DPI to the developer's terminal

**PASS:** A developer can build a C program, run `debug-verilator hello.elf`, see printf output, set breakpoints (by PC), inspect registers.
**Owner:** Pair F

### S5.3 [ ] HARD GATE — OpenOCD configuration

**Action:** Per DECISION-005 (Lever L2: Caravel piggyback), the default v1.1 debug transport is **Caravel housekeeping SPI**, not standalone JTAG. The OpenOCD configuration adapts accordingly:

**Default v1.1 — Caravel SPI bridge transport:**

- Write `toolchain/openocd/azmuth_caravel.cfg` using OpenOCD's `bitbang` or custom SPI adapter driver
- Adapter talks to Caravel housekeeping SPI via a USB-SPI bridge (e.g. FT232H, Bus Pirate, or any USB-to-SPI)
- Caravel's housekeeping SPI bridge module (from hardware audit 3.5.10) translates SPI transactions to DMI
- DMI access remains spec-compliant; only the transport differs from a textbook JTAG TAP
- Memory map for debugger awareness: Boot ROM 0x0000–0x0FFF, SRAM 0x1000–0x1FFF, DM 0x5000–0x5FFF, external NVM via QSPI (logical capacity per `dmstatus`)
- Trigger Module configuration (2 hardware breakpoints per hardware audit 3.5.2)
- Abstract command timeout values calibrated to actual hart response time

**Alternate v2 — Standalone JTAG (Azmuth-Full custom MPW):**

- `toolchain/openocd/azmuth_jtag.cfg` using OpenOCD's standard `jtag` adapter driver
- TAP IR length, ID code expected (from hardware audit 3.5.10 / pad ring spec)
- Reset config using optional TRST pin or system reset

Both configurations connect to the same GDB server on `:3333`. Adopter chooses based on board.

**PASS:** Caravel SPI bridge config (`azmuth_caravel.cfg`) connects via simulated Caravel SPI, halts the core, reads registers, single-steps, writes a register, resumes. All from GDB attached over `:3333`. Worked example committed to `examples/08_debug_workflow/`. Standalone JTAG config exists as the v2 alternate and is verified against the parameterized `DEBUG_TRANSPORT="JTAG"` RTL build.
**FAIL:** Any standard GDB command produces an error or unexpected behavior on either transport.
**Owner:** Pair F

### S5.4 [ ] EVIDENCE — Semihosting fallback

**Action:** For environments without UART, support RISC-V semihosting: a magic `ebreak` sequence that the debugger or simulator intercepts to provide host file I/O. This is the standard "debug output without dedicated hardware" mechanism.

**PASS:** Semihosting implemented in syscall stubs. Hello-world via semihosting works in Verilator.
**Owner:** Pair F

### S5.5 [ ] HARD GATE — GDB integration test

**Action:** End-to-end GDB debugging workflow test, committed as a scriptable test in `tests/debug/gdb_workflow.exp` (expect script):

1. Build firmware with debug symbols (`-g -O0`)
2. Launch Verilator with JTAG bridge
3. Launch OpenOCD with `azmuth.cfg`
4. Launch GDB, connect to `:3333`
5. Set breakpoint on `main` → run → verify breakpoint hit
6. Step through 5 lines of source → verify PC advances correctly
7. Print local variable value → verify correct
8. Modify register `x10` via `set $x10 = 0x42` → continue → verify program observes modified value
9. Set hardware breakpoint on a memory write to a Xcew CSR → trigger → verify halt
10. Disconnect cleanly

Each step has a PASS/FAIL assertion in the expect script. The script is part of CI (S7.3).

**PASS:** Expect script runs end-to-end, all 10 steps pass.
**Owner:** Pair F

---

## Section S6 — SDK, Examples & Documentation

**Why:** A processor is sold via examples. "Here's how to do X on Azmuth" wins adopters; "here's a 200-page architecture spec" doesn't.

### S6.1 [ ] HARD GATE — SDK package structure

**Action:** Organize delivery:

```
azmuth-sdk-vX.Y.Z/
├── README.md                    # Quick start
├── LICENSE
├── CHANGELOG.md
├── docker-image-tag.txt         # Pinned toolchain image tag
├── include/
│   └── azmuth/                  # All headers
│       ├── xcew.h
│       ├── csr.h
│       ├── nvm.h
│       └── ...
├── lib/
│   ├── libxcew.a
│   ├── crt0.o
│   └── ldscripts/
├── bin/                         # Host tools (compiled or scripts)
│   ├── xcew-eml-compile
│   └── xcew-snn-convert
├── examples/
│   ├── 01_hello/
│   ├── 02_eml_basic/
│   ├── 03_snn_mnist/
│   ├── 04_nvm_storage/
│   ├── 05_power_management/
│   ├── 06_security_demo/
│   ├── 07_cew_threat_classifier/   # Headline demo
│   └── 08_debug_workflow/          # GDB + OpenOCD + breakpoints + step
├── docs/
│   ├── getting_started.md
│   ├── programming_model.md
│   ├── api_reference.html       # Doxygen output
│   └── tutorials/
└── tests/                       # SDK self-test
```

**PASS:** Structure exists. `make sdk-package` produces a tarball matching this layout.
**Owner:** Pair E

### S6.2 [ ] HARD GATE — Required examples (all working on co-sim)

Each example: own directory, `README.md` explaining purpose, source `.c` files, `Makefile`, expected output as a checked-in golden file.

**01_hello** — print "Hello, Azmuth" via UART/semihosting. Smoke test.

**02_eml_basic** — compute `ln(1 + exp(x))` for 10 input values, compare against host reference. Validates EML.

**03_snn_mnist** — load a pre-trained small MNIST classifier (4–8 classes), classify 100 test images, report accuracy. Validates SNN.

**04_nvm_storage** — write 1KB to NVM, read back, verify. Inject single-bit and double-bit errors via the test interface, verify ECC behavior.

**05_power_management** — sleep all tiles except core, wake on IRQ, verify cycle-counter advances expected.

**06_security_demo** — exercise constant-time EML, deterministic policy, watchdog trip, fault recovery.

**07_cew_threat_classifier** — the headline example. Reads a stream of mock RF signature data, classifies threats via SNN, updates policy via deterministic Xcew op, logs to NVM. This is the demo that goes in your pitch deck.

**08_debug_workflow** — adopter-facing tutorial. Run firmware with halt-on-reset, attach GDB via OpenOCD, set breakpoints in EML compute and SNN classify functions, single-step through Xcew dispatch, inspect xcew_status CSR, modify policy CSR live, observe behavior change. Includes a written walkthrough in `examples/08_debug_workflow/README.md` and a screencast in `docs/evidence/software/debug_walkthrough.md`.

**PASS:** All 8 examples build and run on co-sim with documented expected behavior matching golden output.
**Owner:** Pair E (examples 01–07), Pair F (example 08)

### S6.3 [ ] HARD GATE — API reference documentation

**Action:** Document every public API function with Doxygen comments. Build with `make docs`. Output is HTML in `docs/api_reference.html`.

**PASS:** Doxygen build succeeds with zero warnings. Every public function documented with parameters, return value, error codes, and a usage snippet.
**Owner:** Pair E

### S6.4 [ ] HARD GATE — Getting Started guide

**Action:** `docs/getting_started.md` — assumes a developer who has never seen Azmuth. Steps from "pull the Docker image" to "first program running on Verilator" in <30 minutes.

**PASS:** A teammate who hasn't touched the project follows the guide and gets `01_hello` running. They report friction points; the guide is updated.
**Owner:** Pair E

### S6.5 [ ] EVIDENCE — Performance tuning guide

**Action:** `docs/performance_tuning.md` — covers cycles-per-operation for each Xcew op, EML cache hit/miss implications, SNN batch size implications, NVM access patterns that cause wear-leveling churn, power-state transition costs.

Adopters need this to evaluate Azmuth vs alternatives.

**Owner:** Pair E

---

## Section S7 — Software Verification & CI

### S7.1 [ ] HARD GATE — Compiler patch regression suite

Already covered in S1.5; restated here for the CI gate. Every PR touching `toolchain/llvm/` runs the suite. Failure blocks merge.

**Owner:** Pair E

### S7.2 [ ] HARD GATE — `libxcew` unit tests

**Action:** Every function in `libxcew` has a unit test under `sdk/libxcew/tests/`. Tests run under Verilator co-sim. Pass rate 100%.

**PASS:** 100% of unit tests pass. Reports under `reports/latest/sdk/`.
**Owner:** Pair E

### S7.3 [ ] HARD GATE — End-to-end CI

**Action:** `.github/workflows/sdk-ci.yml` runs on every PR:

1. Build Docker toolchain image (cache hits when unchanged).
2. Build SDK.
3. Build and run all 7 examples on Verilator.
4. Run libxcew unit tests.
5. Run compiler regression suite.
6. Build Doxygen docs (must succeed without warnings).
7. Package SDK tarball, attach as PR artifact.

**PASS:** Workflow file present. Last 10 main-branch builds green.
**Owner:** Pair E

### S7.4 [ ] EVIDENCE — ABI compliance

**Action:** Document the Azmuth ABI in `docs/sw/ABI.md`:

- Calling convention (inherits RISC-V ilp32 for the base; Xcew operations are dispatched through standard registers)
- Stack layout
- Endianness (little-endian per RISC-V)
- Type sizes
- Reserved registers (if Xcew uses any beyond standard rs1/rs2/rd)
- Interrupt return state

If any deviation from standard RISC-V ilp32, call it out explicitly.

**PASS:** ABI documented. Test program verifies calling convention by interop between separately-compiled object files.
**Owner:** Pair E

---

## Section S8 — Distribution & Maintenance

### S8.1 [ ] HARD GATE — Versioned SDK releases

**Action:** Semantic versioning (`MAJOR.MINOR.PATCH`). Initial release is `1.0.0` paired with silicon v1.1. Each release:

- Git tag (signed)
- GitHub release with packaged tarball
- Docker image tagged `azmuth-toolchain:1.0.0`
- CHANGELOG.md entry
- Compatibility matrix: "SDK 1.0.x ↔ Silicon v1.1.x"

**PASS:** Release process documented in `docs/RELEASE_PROCESS.md`. First release executed end-to-end as a dry run.
**Owner:** Pair E

### S8.2 [ ] HARD GATE — Hardware ↔ SDK compatibility matrix

**Action:** Maintain `docs/COMPATIBILITY.md`. Columns: SDK version, silicon version, status (supported / EOL / unsupported), notes.

When silicon v1.2 ships, SDK 1.1.x and SDK 2.0.x both work; SDK 2.0.x adds new features; SDK 1.x is supported for 18 months minimum.

**PASS:** Matrix present and accurate for v1.0 release.
**Owner:** Pair A + Pair E

### S8.3 [x] EVIDENCE — Security advisory process

**Action:** `SECURITY.md` at repo root. Standard GitHub format. Describes:

- How to report a vulnerability (private channel)
- Response SLA (e.g. 7 days acknowledgment, 90 days disclosure)
- Severity rating scheme (CVSS recommended)
- Past advisories (initially empty, populated as needed)

CC EAL2 evidence `AGD_OPE` (operational user guidance) overlaps with this.

**Owner:** Pair A

### S8.4 [ ] EVIDENCE — Long-term maintenance plan

**Action:** `docs/MAINTENANCE_PLAN.md` covering:

- Rebase cadence for upstream LLVM/GCC/binutils (quarterly minimum)
- Bug triage policy
- Adopter support model (community-only? paid tier? consulting?)
- End-of-life policy for old SDK versions

This is what commercial adopters read first when evaluating whether to bet on Azmuth.

**Owner:** Team lead

---

## Appendix S-A — Tool Versions Matrix

Recommended pinned versions as of the audit baseline (update at every release):

| Component | Recommended Version | Notes |
|-----------|---------------------|-------|
| LLVM | 18.x or 19.x stable | RISC-V custom extension support mature in 18+ |
| GCC (secondary) | 14.x | If used alongside LLVM |
| binutils | 2.42+ | Improved `.insn` syntax |
| picolibc | 1.8.x | Stable, RISC-V proven |
| OpenOCD | 0.12+ | RISC-V Debug 0.13 support |
| Verilator | 5.020+ | Required for current RTL |
| RISCOF | 1.25+ | RISC-V compliance harness |
| Sail-RISCV | latest | Reference golden model |
| Spike | latest | Alternative golden model |
| Docker | 24+ | For reproducible builds |

---

## Appendix S-B — Architecture Decision: LLVM vs GCC

Default recommendation: LLVM primary. If adopting team has strong GCC experience, GCC primary is acceptable. Maintaining both as first-class is not recommended for a 6–8 person team — pick one and provide the other as community-maintained.

| Criterion | LLVM | GCC |
|-----------|------|-----|
| Extension architecture | Cleaner (TableGen) | Multi-file patching |
| License complexity | Apache-2 + LLVM exception (permissive) | GPL-3 + runtime exception |
| Commercial RISC-V vendor adoption | Higher and growing | Established but declining share |
| Community RISC-V tooling | Strong | Strong, longer history |
| Picolibc default | Yes | Optional |
| ARM/Apple/Embedded ecosystem | LLVM dominant | Mixed |
| Upstream contribution friction | Lower (modern review) | Higher (older review process) |

---

## Appendix S-C — Cross-Reference to Hardware Audit

Software items that depend on or interact with hardware audit items:

| Software item | Hardware audit dependency |
|---------------|--------------------------|
| S2.1 Boot ROM specification | HW 3.5 POR sequence, **HW 6.4 Caravel integration**, **HW 1.5.1 external NVM** |
| S2.2 Boot ROM source | HW 3.4 ROM CRC signature, HW 3.5 POR, **HW 1.5.1 external NVM init** |
| S2.3 Linker scripts | **HW 6.4 Caravel integration (azmuth_caravel.ld variant)** |
| S4.1 libxcew | HW 1.1 micro-arch spec (instruction semantics) |
| S4.2 libxcew NVM functions | **HW 1.5.1 external QSPI NVM controller** |
| S4.2 libxcew SNN functions | HW 1.5.2 SNN virtualization (transparent to API) |
| S5.1 Debug Module software integration | HW 3.5 Debug Module Subsystem (full section) |
| S5.3 OpenOCD config | **HW 3.5.10 Caravel SPI bridge for debug transport** |
| S5.5 GDB integration test | HW 3.5.12 end-to-end debug flow validation (shared CI) |
| S6.2.08 Debug workflow example | HW 3.5 + HW 3.5.10 Caravel SPI transport |
| S6.2.06 Security demo | HW 4.x security empirical tests (TVLA, fault injection, etc.) |
| S7.4 ABI compliance | HW 1.1 micro-arch spec (calling convention) |

When closing software items, verify the hardware dependency status. Software cannot advance past the hardware checks it depends on. Note specifically:

- **S5 and S6.2.08** are gated by HW Section 3.5 reaching at least 3.5.5 (functional verification PASS) before software-side end-to-end work begins.
- **S2.1 and S4.2 NVM functions** are gated by HW 1.5.1 (external QSPI architecture) being merged. The software bootloader cannot finalize until the QSPI interface is stable.
- **S5.3** is gated by HW 3.5.10 (Caravel SPI bridge) being merged. Until then, the standalone-JTAG fallback config is the working development path.

---

## Appendix S-D — Definition of "SDK Release Ready"

SDK v1.0 is releasable when:

- Section S0: All 4 items PASS
- Section S1: All 6 items PASS
- Section S2: All 6 items PASS
- Section S3: All 4 items PASS
- Section S4: All 5 items PASS
- Section S5: All 5 items PASS (S5.1 now reflects DM in silicon per HW 3.5; S5.5 added for GDB integration test)
- Section S6: All 5 items PASS (includes 8 examples now, not 7)
- Section S7: All 4 items PASS
- Section S8: All 4 items PASS

Total: **39 HARD GATEs + 9 EVIDENCE items**. SDK release ships paired with silicon v1.1 ship.

When all are checked, the team lead writes a one-page "SDK Release Authorization" memo signed by Pair E + Pair F leads (and DM pair lead for debug-related items) and the team lead, committed to `docs/SDK_RELEASE_AUTHORIZATION.md`. Only then does the SDK tarball go to public release and the Docker image gets the production tag.

---

*End of software toolchain audit. Living document — update on every check completion. Pair this with `AZMUTH_TAPEOUT_AUDIT.md` for full project completeness.*
