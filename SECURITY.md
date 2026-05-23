<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Security Policy

**Project:** Azmuth — Xcew RISC-V Processor v1.1

This document defines how security issues in Azmuth (RTL, firmware, toolchain,
and SDK) are reported and handled. It is also the `AGD_OPE` / security-advisory
evidence anchor for the Common Criteria EAL2 package (see
`docs/AZMUTH_TAPEOUT_AUDIT.md` §4 and `docs/AZMUTH_SOFTWARE_TOOLCHAIN_AUDIT.md`
§S8.3).

## Supported scope

| Component | In scope |
|-----------|----------|
| RTL hardware description (`rtl/`) | Yes |
| Firmware & startup (`firmware/`) | Yes |
| Toolchain contributions (`toolchain/`) | Yes |
| Security claims: constant-time EML, deterministic policy, ECC/SECDED, watchdog, debug-disable strap | Yes |
| Third-party upstream tools (LLVM, Yosys, OpenROAD, etc.) | Report to the respective upstream project |

## Reporting a vulnerability

Report privately. **Do not open a public issue for security defects.**

1. Preferred: GitHub private vulnerability reporting on
   <https://github.com/Kiransekar/Azmuth/security/advisories/new>.
2. Alternative: email the maintainer at the address listed on the GitHub
   profile of the repository owner.

> **TODO (maintainer):** publish a dedicated security contact address and, if
> desired, a PGP key, then replace this note.

Please include: affected component and version/commit, reproduction steps or a
proof-of-concept, observed vs. expected behavior, and any suggested mitigation.

## Response SLA

| Stage | Target |
|-------|--------|
| Acknowledgement of report | 7 calendar days |
| Triage + severity assignment | 14 calendar days |
| Fix or mitigation plan | 30 calendar days |
| Coordinated public disclosure | ≤ 90 calendar days from report |

## Severity rating

Severity is scored using **CVSS v3.1**. Hardware-specific issues that CVSS does
not model well (e.g. side-channel leakage, fault-injection susceptibility) are
additionally classified as Low / Medium / High / Critical with a written
rationale tied to the threat model in the (planned) Security Target
(`docs/evidence/cc/SECURITY_TARGET.md`).

## Disclosure & advisories

Fixed vulnerabilities are published as GitHub Security Advisories and recorded
in `CHANGELOG.md` under a `### Security` heading, referencing the assigned
identifier and the fixing commit.

### Past advisories

_None to date._
