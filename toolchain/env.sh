# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Copyright (c) 2026 Kiransekar. All rights reserved.
#
# Source this to put the Azmuth verification/compliance toolchain on PATH:
#   source toolchain/env.sh
# Records the locally-installed tools so work is not re-bootstrapped each session
# (software audit §S0.2 — versions pinned in toolchain/VERSIONS.md).

# RISCOF lives in a dedicated venv (system Python is PEP-668 externally managed)
export AZMUTH_VENV="$HOME/.venvs/azmuth"
[ -d "$AZMUTH_VENV" ] && export PATH="$AZMUTH_VENV/bin:$PATH"

# Official RISC-V architectural test suite + reference/DUT plugins
export RISCV_ARCH_TEST="$HOME/azmuth-deps"
export RISCOF_PLUGINS="$RISCV_ARCH_TEST/riscof-plugins/rv32"

# Reference model for RISCOF (spike present system-wide); DUT = Azmuth (iverilog).
# binutils objcopy is under the linux-gnu prefix on this host:
export RISCV_OBJCOPY="${RISCV_OBJCOPY:-riscv64-linux-gnu-objcopy}"

echo "Azmuth toolchain ready:"
for t in riscof spike riscv64-unknown-elf-gcc riscv64-linux-gnu-objcopy iverilog verilator yosys sby; do
  if command -v "$t" >/dev/null 2>&1; then printf '  ok   %-30s %s\n' "$t" "$(command -v "$t")"; else printf '  MISS %s\n' "$t"; fi
done
