#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Copyright (c) 2026 Kiransekar. All rights reserved.
#
# PURPOSE:    Re-verify project claims against current repo state and check the
#             CSR map for collisions. Consolidates verify_xcew_v1_1.sh and
#             'make check_csr_v1.1'. Tool/file-absent checks degrade to SKIP.
# INPUTS:     RTL, golden models (sim/golden/), logs/, sby/, PnR results/ if present.
# OUTPUTS:    PASS/FAIL/SKIP summary on stdout.
# EXIT CODES: 0 = no hard FAIL; 1 = at least one claim FAILed.
set -uo pipefail
cd "$(dirname "$0")/.."

PASS=0; FAIL=0; SKIP=0
check() { # name, result-string
  case "$2" in
    *PASS*|*TRUE*) echo "  PASS: $1"; PASS=$((PASS+1));;
    *SKIP*)        echo "  SKIP: $1"; SKIP=$((SKIP+1));;
    *)             echo "  FAIL: $1"; FAIL=$((FAIL+1));;
  esac
}

echo "== flow/compliance: claim re-verification =="

# CSR namespace collisions (delegate to Makefile target)
if make -n check_csr_v1.1 >/dev/null 2>&1; then
  if make check_csr_v1.1 >/dev/null 2>&1; then check "CSR collisions = 0" PASS
  else check "CSR collisions = 0" FAIL; fi
else
  check "CSR collisions = 0" SKIP
fi

# RTL lint
if command -v verilator >/dev/null 2>&1 || command -v iverilog >/dev/null 2>&1; then
  if make lint >/dev/null 2>&1; then check "RTL lint (0 errors)" PASS
  else check "RTL lint (0 errors)" FAIL; fi
else
  check "RTL lint (0 errors)" SKIP
fi

# EML golden-model accuracy
if command -v python3 >/dev/null 2>&1 && [ -f sim/golden/eml_golden.py ]; then
  n=$(python3 sim/golden/eml_golden.py 2>&1 | grep -c 'PASS' || true)
  check "EML golden accuracy" "$([ "${n:-0}" -ge 5 ] && echo PASS || echo FAIL)"
else
  check "EML golden accuracy" SKIP
fi

# Formal proofs
if command -v sby >/dev/null 2>&1 && ls sby/*.sby >/dev/null 2>&1; then
  if make formal >/dev/null 2>&1; then check "Formal properties proved" PASS
  else check "Formal properties proved" FAIL; fi
else
  check "Formal properties proved" SKIP
fi

# Physical design signoff (post-PnR)
if [ -f results/final.gds ] || ls pnr/runs/*/results/*/*.gds >/dev/null 2>&1; then
  check "GDS produced" PASS
else
  check "Physical design (PnR)" SKIP
fi

echo "  ----"
echo "  PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
[ "$FAIL" -eq 0 ] && { echo "  All testable claims verified."; exit 0; }
echo "  $FAIL claim(s) failed."; exit 1
