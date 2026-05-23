#!/usr/bin/env python3
# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Copyright (c) 2026 Kiransekar. All rights reserved.
"""Convert a flat binary (objcopy -O binary) into a $readmemh word file:
one 32-bit little-endian word per line, address 0 = byte 0.
Usage: bin2hex.py <in.bin> <out.hex>"""
import sys

with open(sys.argv[1], "rb") as f:
    b = f.read()
while len(b) % 4:
    b += b"\x00"
with open(sys.argv[2], "w") as o:
    for i in range(0, len(b), 4):
        w = b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24)
        o.write("%08x\n" % w)
