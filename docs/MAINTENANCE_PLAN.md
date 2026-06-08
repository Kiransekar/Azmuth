<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Maintenance Plan

**Audit reference:** Software §S8.4
**Date:** 2026-06-06

## Upstream Dependency Tracking

| Dependency | Current Version | Update Cadence | Owner |
|-----------|----------------|----------------|-------|
| riscv-gnu-toolchain | See `toolchain/VERSIONS.md` | Quarterly | Pair E |
| LLVM/Clang (Xcew patches) | — (planned) | Per LLVM release | Pair E |
| picolibc | — (planned) | Per release | Pair E |
| OpenOCD (Azmuth target) | — (planned) | Per release | Pair F |
| RISCOF | See `toolchain/riscof/` | Per riscv-arch-test release | Pair B |
| Spike reference model | See `toolchain/VERSIONS.md` | Per release | Pair B |

## Security Patch Process

Per `SECURITY.md`:
1. Vulnerabilities reported via private disclosure
2. Triage within 48 hours
3. Fix within 7 days for CVSS ≥7.0
4. Advisory published with CVE (if applicable)
5. SDK hotfix release per §S8.1

## Long-Term Support

- **v1.1:** Supported until 12 months after v1.2 silicon ships
- **v1.2+:** 18-month support window per minor version
- Support includes: security patches, critical bug fixes, documentation updates
- No feature backports to prior minor versions

## Documentation Maintenance

- All docs live alongside source in `docs/` and `sdk/docs/`
- API docs generated from header comments (Doxygen or similar)
- Updated on every PR that changes public API
- Annual full review of all documentation
