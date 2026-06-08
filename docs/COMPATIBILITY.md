<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Compatibility Policy

**Audit reference:** Software §S8.2
**Date:** 2026-06-06

## API Stability

### Stable (no breaking changes within v1.x)
- `sdk/include/azmuth/xcew.h` — libxcew C API
- `sdk/include/azmuth/csr.h` — CSR address definitions
- Custom instruction encodings (opcodes, funct3 values)
- CSR addresses 0x7C0–0x7CC
- Memory map (Boot ROM, SRAM, EML/SNN/NVM CSR regions)
- ABI (ilp32, calling convention)

### Unstable (may change in v1.2)
- CSR addresses 0x7CD–0x7CF (DEV-004: not yet implemented)
- Debug Module register map (new in v1.1, subject to refinement)
- Internal SNN tile parameters (neuron count, virtualization ratio)
- EML DAG cache internals
- Power domain UPF topology

## Deprecation Policy

1. Deprecated APIs are marked with `__attribute__((deprecated))` for ≥1 minor
   version before removal
2. Deprecated CSR addresses continue to read/write correctly for ≥1 minor version
3. Breaking changes documented in CHANGELOG.md with migration instructions

## Hardware/Software Version Matrix

| Silicon | SDK | Status |
|---------|-----|--------|
| v1.1 | v1.1.x | Current |
| v1.2 (planned) | v1.2.x | Future — adds M/C extension, production Debug Module |
