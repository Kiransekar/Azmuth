<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Azmuth Decision Log

Single source of truth for architectural and process decisions. Every PR that
hinges on a decision references its `DECISION-NNN` id. Required by tapeout audit
§8.4 and referenced throughout both audit documents.

**Status legend:** `ACCEPTED` (ratified) · `PROPOSED` (recommended in the audit,
pending team-lead ratification) · `SUPERSEDED` · `DEPRECATED`.

> Note: DECISION-001/-002/-003/-006 are transcribed from the recommendations in
> `AZMUTH_TAPEOUT_AUDIT.md` / `AZMUTH_SOFTWARE_TOOLCHAIN_AUDIT.md` and are marked
> PROPOSED until the team lead ratifies them (sign-off converts them to ACCEPTED
> with a date and reviewer). DECISION-004/-005 are presented as already decided
> in the tapeout audit and are recorded ACCEPTED on that basis. DECISION-007 was
> decided in this session.

---

## DECISION-001: PDK target is SKY130
- **Status:** PROPOSED
- **Date:** 2026-05-23
- **Decided by:** _pending — team lead + Pair D lead_
- **Context:** Open commercial market; fastest path to first silicon via the
  Efabless / OpenROAD-supported open ecosystem. ChipIgnite uses SKY130.
- **Decision:** Use SKY130A for v1.1 tapeout. IHP SG13G2 evaluated as a v2
  option for RF integration.
- **Consequences:** Library names, std-cell timing (`sky130_fd_sc_hd`), and
  memory compilers are fixed to SKY130A. Documented in `docs/PDK_DECISION.md`
  (to be created, audit §6 note).
- **Reviewed:** _pending_

## DECISION-002: Team pair structure
- **Status:** PROPOSED
- **Date:** 2026-05-23
- **Decided by:** _pending — team lead_
- **Context:** 6–8 contributors; integration discipline required (audit §8.1).
- **Decision:** Pairs A (spec/traceability), B (functional/compliance verif),
  C (formal/security/cross-cutting), D (physical/signoff), DM (Debug Module),
  E (toolchain/SDK), F (bootloader/runtime/debug). At 8 people this is ~5 pairs
  with software cross-cover; at 6, software merges into one pair and Pair D
  supports DM hardware.
- **Consequences:** Ownership columns in both audits resolve to these pairs.
- **Reviewed:** _pending_

## DECISION-003: LLVM/Clang as primary toolchain
- **Status:** PROPOSED
- **Date:** 2026-05-23
- **Decided by:** _pending — team lead + Pair E_
- **Context:** Software audit §S1.1. Xcew needs first-class compiler support.
- **Decision:** LLVM/Clang primary (TableGen extension model, permissive
  license, growing RISC-V vendor adoption); GCC secondary/community.
- **Consequences:** Xcew support implemented as `RISCVInstrInfoXcew.td`,
  intrinsics in `IntrinsicsRISCV.td`, plus AsmParser/InstPrinter patches.
  picolibc chosen as the C library (audit §S3.1).
- **Reviewed:** _pending_

## DECISION-004: Add Debug Module to v1.1 scope
- **Status:** ACCEPTED
- **Date:** 2026-05-23
- **Decided by:** Kiransekar + team
- **Context:** Initial RTL inventory had no Debug Module. Adopters cannot use
  GDB/OpenOCD on silicon without a DM. Shipping without it forces a v1.2 respin
  or a permanently degraded adopter experience.
- **Decision:** Implement RISC-V External Debug Spec 0.13.2, minimum-viable
  scope: halt/resume/step, GPR/CSR access, 2 hardware breakpoints, JTAG DTM.
- **Consequences:** +30–50K gates; +4–5 pad-ring pins (JTAG + strap); +1 power
  domain (`PD_DEBUG` always-on); +1 AXI master and +1 AXI slave on the
  interconnect; new TCK clock-domain crossing; new security threat surface
  requiring explicit treatment; ~6–10 weeks added to schedule.
- **Reviewed:** 2026-05-23 (active). Work tracked in tapeout audit §3.5.

## DECISION-005: Five-lever area optimization for ChipIgnite shuttle fit
- **Status:** ACCEPTED
- **Date:** 2026-05-23
- **Decided by:** Kiransekar + team
- **Context:** The 18 mm² original target is incompatible with any free open MPW
  shuttle. A paid 18 mm² slot (IHP SG13G2 ~€54k) is outside budget. Reducing
  architectural features is unacceptable per design intent.
- **Decision:** Target ChipIgnite SKY130 (Caravel harness, ~$9,750) with a
  single-chip 10 mm² fit via five compounding optimizations that preserve all
  architectural claims:
  - **L1** — External QSPI NVM (preserves controller IP; makes NVM scalable).
  - **L2** — Caravel piggyback (debug transport + flash interface reuse).
  - **L3** — SNN virtualization (128 physical / 256 logical, time-multiplexed).
  - **L4** — EML cache compression (256 logical preserved, compressed tags).
  - **L5** — Synthesis + floorplan area-targeted optimization.
- **Consequences:** SNN clock pushed 125→200 MHz; NVM bring-up needs an external
  QSPI part; debug uses Caravel housekeeping SPI as transport (DM unchanged);
  RTL becomes parameterizable, enabling an Azmuth-Full v2 from the same
  codebase; marketing language updated to present external NVM as a feature.
- **Reviewed:** 2026-05-23 (active). Work tracked in tapeout audit §1.5, §5.5, §6.

## DECISION-006: Shuttle commitment (target slot)
- **Status:** PROPOSED
- **Date:** 2026-05-23
- **Decided by:** _pending — team lead_
- **Context:** No PnR work (audit §6) starts until a shuttle slot is committed;
  the GDS deadline drives all earlier deadlines (audit §5.5.3).
- **Decision:** _To be set._ Standard ChipIgnite SKY130 (no internal-ReRAM tier,
  since NVM is external per DECISION-005, saving ~$2k) is the proposed primary;
  a backup slot must be named.
- **Consequences:** Locks pad ring, floorplan, IO assignment, and harness
  compliance. Must be signed by the team lead before Section 6 begins.
- **Reviewed:** _pending_

## DECISION-007: Project license is proprietary (All Rights Reserved)
- **Status:** ACCEPTED
- **Date:** 2026-05-23
- **Decided by:** Kiransekar (project owner)
- **Context:** Audit §0.7 recommended an open-commercial license (Apache-2.0 or
  MIT). The project owner elected a closed/proprietary model instead.
- **Decision:** Ship under a proprietary "All Rights Reserved" license
  (`LICENSE`, SPDX `LicenseRef-Azmuth-Proprietary`). All source files carry the
  SPDX identifier. Upstream toolchain components retain their own licenses,
  inventoried in `toolchain/LICENSES.md`.
- **Consequences:** Deviates from the audits' open-commercial assumption and
  from the "do not advertise AI tooling / publish CC package as-is" framing —
  distribution of RTL/SDK to adopters will be under separate commercial terms,
  not an open release. The CC EAL2 and RISC-V compatibility evidence work is
  unaffected (those concern claim-vs-evidence integrity, not license).
- **Reviewed:** 2026-05-23 (active).

## DECISION-009: M-mode trap gating + pipeline-correctness fixes
- **Status:** ACCEPTED
- **Date:** 2026-05-23
- **Decided by:** Kiransekar
- **Context:** `MICRO_ARCH_SPEC.md` DEV-005/008/009 — the core had no machine
  trap CSRs, `exception` was tied 0, and IRQs were not wired to the core. Adding
  spec-compliant trapping risked regressing existing tests that execute
  un-initialized instruction streams (relying on undefined opcodes being silent).
- **Decision:**
  1. Implement M-mode Zicsr (mstatus/mie/mip/mtvec/mepc/mcause/mtval/mscratch +
     misa/mhartid RO), exception detection (illegal, ECALL, EBREAK, load/store
     misalign), machine external/timer/software interrupt taking, and `mret`.
  2. **Gate trap-taking on `mtvec != 0`** (a handler is installed). This keeps
     pre-handler bring-up behavior identical (existing tests never set mtvec)
     while giving full trap behavior once firmware programs mtvec. Compatible
     with RISCOF (its tests install handlers).
  3. Fix `if_pc` (was `next_pc`, an off-by-4) so `id_ex_pc` is the instruction's
     real PC — corrects branch/jump targets **and** `mepc`.
  4. Add a 1-cycle wrong-path **flush** on any taken control transfer
     (branch/jump/trap/mret), fixing the pre-existing branch-shadow.
- **Consequences:** New core ports `i_meip/i_mtip/i_msip` (wired in both tops;
  `i_meip` = aggregate of live fault/timeout IRQs). Tests `tb/trap_tb.v` (6/6),
  `tb/irq_tb.v` (5/5). No regression: core_tb, cosim, soc, top all pass.
- **Reviewed:** 2026-05-23 (active).

## DECISION-008: Xcew custom opcode map = standard RISC-V custom-0..3
- **Status:** ACCEPTED
- **Date:** 2026-05-23
- **Decided by:** Kiransekar (on RISC-V-standards grounds)
- **Context:** `MICRO_ARCH_SPEC.md` DEV-001 — `rtl/core/riscv_core.v` (the active
  datapath) and `rtl/core/xcie_decoder.v` used disjoint Xcew opcode maps. The
  decoder's map (`1111011`..`1111111`) is non-compliant: `1111111`/`1111110`/
  `1111101` fall in the space the RISC-V base spec reserves for ≥48/≥80-bit
  instruction encodings, not the custom space. `xcie_decoder.v` was also found
  **vestigial** (not instantiated in any RTL/testbench source).
- **Decision:** The four **standard RISC-V custom opcode slots** are
  authoritative: custom-0 `0001011` = EML, custom-1 `0101011` = POL_UPD,
  custom-2 `1011011` = SNN classify, custom-3 `1111011` = MISC (CFG/MLOAD/MSTORE
  by `funct3`). `xcie_decoder.v` corrected to this map and POL_UPD made reachable
  (closes DEV-001, DEV-002); directed test `tb/xcie_decoder_tb.v` (10/10).
- **Consequences:** Decoder and core now agree. `xcie_decoder.v` / `xcie_ctrl.v`
  remain structurally vestigial relative to the v1.1 datapath (core decodes
  inline + dispatches via `o_xcew_req`/`i_xcew_done`); wiring them in or removing
  them is a separate tracked cleanup.
- **Reviewed:** 2026-05-23 (active).
