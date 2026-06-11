/* SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary */
/* Copyright (c) 2026 Kiransekar. All rights reserved. */
/* Azmuth RISCOF link script: base 0x80000000 (standard arch-test base; the core
   is parameterized with RESET_PC=0x80000000 and the testbench windows memory
   there). Sections packed tightly to keep the flat binary small. */
OUTPUT_ARCH( "riscv" )
ENTRY(rvtest_entry_point)

SECTIONS
{
  . = 0x80000000;
  .text.init : { *(.text.init) }
  . = ALIGN(0x40);
  .tohost : { *(.tohost) }
  . = ALIGN(0x40);
  .text : { *(.text) }
  . = ALIGN(0x40);
  .data : { *(.data) }
  .data.string : { *(.data.string) }
  . = ALIGN(0x40);
  .bss : { *(.bss) }
  _end = .;
}
