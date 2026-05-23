#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Copyright (c) 2026 Kiransekar. All rights reserved.
#
# PURPOSE:    Run signoff checks. Default is the v1.1 unified signoff
#             (STA + DFT + security); pass "postpr" for post-PnR signoff.
# INPUTS:     synthesis/PnR outputs; syn/signoff_v1.1.tcl, pnr/signoff_postpr.tcl.
# OUTPUTS:    Signoff reports.
# EXIT CODES: 0 = signoff passed; nonzero = a check failed.
set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-v1.1}" in
  postpr) exec make signoff_postpr ;;
  v1.1|*) exec make signoff_v1.1 ;;
esac
