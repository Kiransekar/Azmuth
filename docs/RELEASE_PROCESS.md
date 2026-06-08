<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# SDK Release Process

**Audit reference:** Software §S8.1
**Date:** 2026-06-06

## Version Numbering

SDK versions track the silicon revision: **SDK v1.1.x** ships paired with
silicon v1.1. Patch versions (x) for firmware/SDK-only fixes.

| Version | Meaning |
|---------|---------|
| v1.1.0 | Initial release paired with v1.1 silicon tapeout |
| v1.1.1+ | SDK patch releases (no silicon change) |
| v1.2.0 | Next silicon revision (M-ext, C-ext, Debug Module in production) |

## Release Checklist

```
1. All software audit gates PASS (§S0–§S8)
2. All firmware tests pass on Verilator model
3. RISCOF arch-test suite PASS
4. SDK examples compile and run on simulator
5. Documentation reviewed (no stale API references)
6. Changelog updated
7. Version tag created: git tag -s v1.1.0 -m "SDK v1.1.0 release"
8. SDK tarball generated: make sdk-dist
9. Docker image tagged: azmuth-sdk:v1.1.0
10. Release authorization memo signed (SDK_RELEASE_AUTHORIZATION.md)
```

## Distribution

- **Source:** Git repository (proprietary, per DECISION-007)
- **Binary:** Pre-built toolchain in Docker image
- **Docs:** HTML documentation generated from Markdown sources

## Hotfix Process

For critical post-release fixes:
1. Branch from release tag: `git checkout -b hotfix/v1.1.1 v1.1.0`
2. Apply minimal fix
3. Run full regression
4. Tag and release: `v1.1.1`
5. Merge back to main
