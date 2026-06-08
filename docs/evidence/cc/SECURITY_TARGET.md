<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Azmuth Security Target (CC EAL2)

**Audit reference:** Tapeout §4.6
**Date:** 2026-06-06
**Standard:** ISO/IEC 15408 Common Criteria Part 1

---

## 1. ST Introduction

### 1.1 TOE Reference
- **TOE Name:** Azmuth Xcew RISC-V Processor v1.1
- **TOE Version:** v1.1 (silicon revision)
- **Developer:** Kiransekar / Azmuth Team

### 1.2 TOE Overview
Azmuth is an RV32IMC RISC-V processor with custom Xcew extensions for
edge-AI workloads (cognitive electronic warfare). The TOE encompasses the
processor silicon die including: RISC-V core, EML accelerator, SNN classifier,
NVM controller, power management, fault monitoring, and (planned) debug module.

### 1.3 TOE Description
The processor implements five security-relevant subsystems:
1. **Constant-time EML** — timing-side-channel resistance for expression evaluation
2. **Deterministic policy execution** — fixed-cycle-count enforcement for policy updates
3. **SECDED ECC** — single-error-correct, double-error-detect on NVM storage
4. **Fault monitor** — watchdog, error latching, pipeline halt on fault
5. **Debug security** — debug-enable strap, sticky debug-occurred flag (planned)

## 2. Conformance Claims

- **CC Version:** Common Criteria v3.1 Release 5
- **Part 2 Conformance:** Part 2 conformant (functional requirements)
- **Part 3 Conformance:** Part 3 conformant (assurance requirements)
- **Assurance Package:** EAL2 (Structurally tested)

## 3. Security Problem Definition

### 3.1 Threats

| ID | Threat | Description |
|----|--------|-------------|
| T.TIMING | Timing side-channel | Attacker observes execution time of EML operations to infer secret inputs |
| T.POWER | Power side-channel | Attacker observes power consumption to infer processed data (out of EAL2 scope) |
| T.FAULT_INJ | Fault injection | Attacker induces bit-flips in NVM or SRAM to corrupt data or bypass security |
| T.DENY | Denial of service | Malformed Xcew operands cause pipeline hang or infinite loop |
| T.ECC_BYPASS | ECC bypass | Attacker corrupts NVM data beyond ECC correction capability |
| T.DEBUG_EXFIL | Debug exfiltration | Attacker uses debug interface to read secrets from NVM/SRAM |
| T.POLICY_TIMING | Policy timing leak | Variable execution time of policy updates leaks decision information |

### 3.2 Assumptions

| ID | Assumption |
|----|-----------|
| A.PHYS | Physical access to the chip is restricted in deployment |
| A.BOOT | Boot ROM is read-only and contains trusted code |
| A.RESET | Reset circuit is trustworthy and cannot be spoofed |
| A.DEBUG_STRAP | Debug-enable strap is tied low in production deployment |

### 3.3 Organizational Security Policies

| ID | Policy |
|----|--------|
| P.AUDIT | All security-relevant events (faults, debug access) are logged |
| P.INTEGRITY | NVM data integrity is maintained via SECDED ECC with periodic scrub |

## 4. Security Objectives

### 4.1 For the TOE
- **O.CONST_TIME:** EML operations execute in constant time regardless of input
- **O.DET_POLICY:** Policy updates execute in deterministic cycle count
- **O.ECC:** NVM data protected by SECDED; single-bit errors corrected, double-bit detected
- **O.FAULT_DET:** Hardware faults detected, latched, and reported
- **O.WATCHDOG:** Runaway execution detected and halted
- **O.DEBUG_CTRL:** Debug access controlled by hardware strap (planned)

### 4.2 For the Operational Environment
- **OE.DEPLOY:** Deployer ties DEBUG_EN low and verifies sticky debug flag at boot
- **OE.NVM_SCRUB:** Firmware enables periodic NVM scrub via CSR 0x7CE

## 5. Security Functional Requirements (SFR)

| SFR | Class | Requirement | Implementation |
|-----|-------|-------------|----------------|
| FDP_IFF.1 | Info Flow | Constant-time EML | `eml_constant_time.v` cycle padding + `ct_mux` |
| FDP_ACC.1 | Access Control | Debug-enable strap | Planned: `i_debug_en` pin |
| FDP_SDI.2 | Stored Data Integrity | SECDED ECC | `nvm_ctrl.v` Hamming(38,32) |
| FPT_FLS.1 | Fail Secure | Fault monitor | `fault_monitor.v` pipeline halt |
| FPT_TST.1 | Self Test | ROM CRC check | Boot ROM firmware |
| FMT_MSA.1 | Security Attribute Mgmt | CSR access control | Field masking in `xcie_csr.v` |

## 6. TOE Summary Specification

Each SFR is implemented as described in the micro-architecture specification
(`MICRO_ARCH_SPEC.md`) and verified by the test suite documented in
`VERIFICATION_PLAN.md`. Empirical validation reports for timing side-channel
(§4.1), deterministic policy (§4.2), fault injection (§4.3), and ECC (§4.4)
provide the evidence base.
