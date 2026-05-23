#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Copyright (c) 2026 Kiransekar. All rights reserved.
#
# PURPOSE:    Run SymbiYosys formal property checks (eml/snn/security/power).
# INPUTS:     sby/*.sby and the RTL they reference.
# OUTPUTS:    SBY proof logs under sby/<task>/; pass/fail on stdout.
# EXIT CODES: 0 = all present properties proved; nonzero = counterexample or sby missing.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v sby >/dev/null 2>&1; then
  echo "ERROR: SymbiYosys (sby) not installed. Install per tapeout audit §1.3(c)."
  exit 1
fi
make formal
