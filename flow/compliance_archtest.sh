#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Copyright (c) 2026 Kiransekar. All rights reserved.
#
# PURPOSE:    Differential RISC-V arch-test runner (tapeout audit §2.4). For each
#             test: assemble, run on Spike (reference) and the Azmuth core (DUT),
#             and diff the signatures. A "mini-RISCOF" using the official suite
#             and golden model without the full framework's plugin machinery.
# INPUTS:     $RISCV_ARCH_TEST (default ~/azmuth-deps), the suite subdir as $1
#             (default rv32i_m/I), source toolchain/env.sh first.
# OUTPUTS:    PASS/FAIL per test + tally; signatures under reports/<date>/compliance/.
# EXIT CODES: 0 = all pass; 1 = at least one fail/error.
set -uo pipefail
cd "$(dirname "$0")/.."

SUITE_REL="${1:-rv32i_m/I}"
ARCH="${RISCV_ARCH_TEST:-$HOME/azmuth-deps}"
SRC="$ARCH/riscv-test-suite/$SUITE_REL/src"
AENV="$ARCH/riscv-test-suite/env"
PENV="toolchain/riscof/azmuth/env"
GCC=riscv64-unknown-elf-gcc
OBJCOPY="${RISCV_OBJCOPY:-riscv64-linux-gnu-objcopy}"
OBJDUMP=riscv64-unknown-elf-objdump
OUT="reports/$(date +%F)/compliance/$(echo "$SUITE_REL" | tr / _)"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

command -v spike >/dev/null || { echo "spike not found (source toolchain/env.sh)"; exit 1; }
[ -d "$SRC" ] || { echo "suite not found: $SRC"; exit 1; }

# Determine GCC -march and Spike -isa dynamically based on the suite name
GCC_MARCH="rv32im_zicsr"
SPIKE_ISA="rv32im_zicsr"
IVERILOG_FLAGS=""
if [[ "$SUITE_REL" == *"/C"* ]] || [[ "$SUITE_REL" == *"_c/"* ]] || [[ "$SUITE_REL" == *"rv32i_m/C"* ]]; then
  GCC_MARCH="rv32imc_zicsr"
  SPIKE_ISA="rv32imc_zicsr"
  IVERILOG_FLAGS="-DSUPPORT_C=1"
fi

# Build the DUT simulator once
SIM="$WORK/azmuth_sim"
iverilog -g2001 $IVERILOG_FLAGS -o "$SIM" tb/riscof/azmuth_riscof_tb.v rtl/core/riscv_core.v 2>/dev/null \
  || { echo "sim build failed"; exit 1; }

pass=0; fail=0; err=0; results="$OUT/results.txt"; : > "$results"
for t in "$SRC"/*.S; do
  name=$(basename "$t" .S); w="$WORK/$name"; mkdir -p "$w"
  # Extract extra defines needed for compliance/privilege tests
  EXTRA_DEFS=""
  for var in rvtest_mtrap_routine rvtest_strap_routine HARDWARE_UPDATE_A_D SOFTWARE_UPDATE_A_D; do
    if grep -q "$var" "$t"; then
      EXTRA_DEFS="$EXTRA_DEFS -D$var=True"
    fi
  done

  if ! $GCC -march="$GCC_MARCH" -mabi=ilp32 -static -mcmodel=medany -fno-pic -fvisibility=hidden \
        -nostdlib -nostartfiles -Wl,--build-id=none -T "$PENV/link.ld" -I "$PENV" -I "$AENV" \
        -DXLEN=32 -DTEST_CASE_1=True $EXTRA_DEFS "$t" -o "$w/my.elf" 2>"$w/cc.log"; then
    echo "ERROR(compile) $name" | tee -a "$results"; err=$((err+1)); continue
  fi
  $OBJCOPY -O binary "$w/my.elf" "$w/my.bin"
  python3 toolchain/riscof/bin2hex.py "$w/my.bin" "$w/my.hex"
  beg=$($OBJDUMP -t "$w/my.elf" | awk '/ begin_signature$/{print $1; exit}')
  end=$($OBJDUMP -t "$w/my.elf" | awk '/ end_signature$/{print $1; exit}')
  toh=$($OBJDUMP -t "$w/my.elf" | awk '/ tohost$/{print $1; exit}')
  ent_sym=$($OBJDUMP -t "$w/my.elf" | awk '/ rvtest_entry_point$/ || / rvtest_entrypoint$/{print $1; exit}')
  ent=0x$ent_sym
  timeout 30 spike --isa="$SPIKE_ISA" --pc=0x80000000 +signature="$w/ref.sig" \
        +signature-granularity=4 "$w/my.elf" >/dev/null 2>&1
  timeout 300 vvp "$SIM" +hex="$w/my.hex" +sig="$w/dut.sig" \
        +begin="$beg" +end="$end" +tohost="$toh" >/dev/null 2>&1
  if [ ! -s "$w/ref.sig" ]; then echo "ERROR(ref) $name" | tee -a "$results"; err=$((err+1)); continue; fi
  if [ ! -s "$w/dut.sig" ]; then echo "ERROR(dut) $name" | tee -a "$results"; err=$((err+1)); continue; fi
  if diff -q "$w/ref.sig" "$w/dut.sig" >/dev/null 2>&1; then
    echo "PASS  $name" | tee -a "$results"; pass=$((pass+1))
    cp "$w/dut.sig" "$OUT/$name.signature"
  else
    echo "FAIL  $name" | tee -a "$results"; fail=$((fail+1))
    diff "$w/ref.sig" "$w/dut.sig" > "$OUT/$name.diff" 2>&1
  fi
done

echo "----"
echo "arch-test $SUITE_REL : PASS=$pass FAIL=$fail ERROR=$err" | tee -a "$results"
[ "$fail" -eq 0 ] && [ "$err" -eq 0 ]
