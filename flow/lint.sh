#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Copyright (c) 2026 Kiransekar. All rights reserved.
#
# PURPOSE:    Lint the full RTL design (Verilator, iverilog fallback) and run a
#             per-file Verilog-2001 syntax sweep. Replaces verilog2001_compliance_check.sh
#             and fast_syntax_check.sh.
# INPUTS:     rtl/ sources (RTL_FILES in Makefile, rtl/rtl_list.f).
# OUTPUTS:    Lint result on stdout.
# EXIT CODES: 0 = clean; 1 = lint or syntax error.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== flow/lint: design lint =="
make lint

echo "== flow/lint: per-file Verilog-2001 syntax sweep =="
# Compile each file alone. "Unknown module type" is expected for hierarchical
# modules instantiating submodules from other files, so it is NOT a syntax
# error here — only genuine parse errors count.
if command -v iverilog >/dev/null 2>&1; then
  fail=0
  while IFS= read -r f; do
    err=$(iverilog -t null -g2001 "$f" 2>&1 >/dev/null) || true
    # drop expected isolation noise; anything left containing "error" is real
    real=$(printf '%s\n' "$err" | grep -i 'error' \
            | grep -viE 'Unknown module type|were missing|referenced [0-9]+ times|error\(s\) during elaboration' || true)
    if [ -n "$real" ]; then
      echo "  syntax error: $f"
      printf '%s\n' "$real" | sed 's/^/    /'
      fail=1
    fi
  done < <(find rtl -name '*.v')
  [ "$fail" -eq 0 ] && echo "  all files parse cleanly (Verilog-2001)" || exit 1
else
  echo "  iverilog not found - skipping per-file sweep"
fi
