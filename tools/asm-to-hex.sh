#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Copyright (c) 2026 Kiransekar. All rights reserved.
#
# PURPOSE:    Assemble an RV32I(+Zicsr) .S into a $readmemh hex (one 32-bit
#             little-endian instruction word per line) for testbench ROMs.
#             Uses gcc-as + objdump (no objcopy/link needed). Generated hex is
#             committed so tests run even without the toolchain.
# USAGE:      tools/asm-to-hex.sh <src.S> <out.hex>
# EXIT CODES: 0 ok; 1 toolchain missing; 2 assemble error.
set -euo pipefail
SRC="${1:?usage: asm-to-hex.sh <src.S> <out.hex>}"
OUT="${2:?usage: asm-to-hex.sh <src.S> <out.hex>}"
GCC=riscv64-unknown-elf-gcc
OBJDUMP=riscv64-unknown-elf-objdump
command -v "$GCC" >/dev/null 2>&1 && command -v "$OBJDUMP" >/dev/null 2>&1 || {
    echo "RV toolchain ($GCC / $OBJDUMP) not found; keeping existing $OUT" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
"$GCC" -march=rv32i_zicsr -mabi=ilp32 -c -o "$tmp/a.o" "$SRC" || exit 2
{
  echo "// generated from $(basename "$SRC") by tools/asm-to-hex.sh"
  "$OBJDUMP" -d "$tmp/a.o" | grep -E '^[[:space:]]+[0-9a-f]+:[[:space:]]+[0-9a-f]{8}[[:space:]]' \
    | awk '{print $2}'
} > "$OUT"
echo "wrote $OUT ($(($(wc -l < "$OUT")-1)) words)"
