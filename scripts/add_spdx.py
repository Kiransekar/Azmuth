#!/usr/bin/env python3
# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Copyright (c) 2026 Kiransekar. All rights reserved.
"""Idempotently prepend SPDX + copyright headers to Azmuth source files.

Usage: python3 scripts/add_spdx.py [--check]
  (no args) : insert headers in place
  --check   : report files that are MISSING a header, exit 1 if any (CI gate)

Tapeout audit §0.7 / software audit §S0.4: every .v/.tcl/.sh/.py/.md (and C/asm)
source file must carry the project SPDX identifier.
"""
import os
import sys

SPDX = "SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary"
COPYRIGHT = "Copyright (c) 2026 Kiransekar. All rights reserved."

# extension -> comment style
SLASH = {".v", ".sv", ".svh", ".vh", ".c", ".cpp", ".cc", ".h", ".hpp", ".S"}
HASH = {".sh", ".py", ".tcl", ".sdc", ".ys", ".f"}
BLOCK = {".ld"}            # GNU ld scripts: only /* */ comments are valid
MD = {".md"}

# directories never to touch (generated, vendored, build output)
SKIP_DIRS = {".git", "build", "runs", "__pycache__", "node_modules",
             "reports", "evidence"}
# specific generated files to skip
SKIP_SUFFIX = ("_netlist.v",)

ROOTS = ["rtl", "tb", "syn", "pnr", "dft", "sim", "sby", "mpw", "bringup",
         "pkg", "golden_tests", "scripts", "flow", "firmware", "toolchain",
         "docs"]


def header_for(ext):
    if ext in SLASH:
        return f"// {SPDX}\n// {COPYRIGHT}\n"
    if ext in HASH:
        return f"# {SPDX}\n# {COPYRIGHT}\n"
    if ext in BLOCK:
        return f"/* {SPDX} */\n/* {COPYRIGHT} */\n"
    if ext in MD:
        return f"<!-- {SPDX} -->\n"
    return None


def has_header(text):
    return "SPDX-License-Identifier" in text[:1024]


def insert(path, ext):
    with open(path, "r", encoding="utf-8", errors="surrogateescape") as fh:
        text = fh.read()
    if has_header(text):
        return False
    hdr = header_for(ext)
    if hdr is None:
        return False
    lines = text.split("\n", 1)
    # preserve shebang on line 1 for hash-comment scripts
    if ext in HASH and text.startswith("#!"):
        rest = lines[1] if len(lines) > 1 else ""
        new = lines[0] + "\n" + hdr + rest
    else:
        new = hdr + text
    with open(path, "w", encoding="utf-8", errors="surrogateescape") as fh:
        fh.write(new)
    return True


def iter_files():
    for root in ROOTS:
        if not os.path.isdir(root):
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
            for name in filenames:
                ext = os.path.splitext(name)[1]
                if header_for(ext) is None:
                    continue
                if name.endswith(SKIP_SUFFIX):
                    continue
                yield os.path.join(dirpath, name), ext
    # top-level markdown
    for name in os.listdir("."):
        if name.endswith(".md") and os.path.isfile(name):
            yield name, ".md"


def main():
    check = "--check" in sys.argv
    changed, missing, total = 0, [], 0
    for path, ext in iter_files():
        total += 1
        with open(path, "r", encoding="utf-8", errors="surrogateescape") as fh:
            if has_header(fh.read()[:1024]):
                continue
        if check:
            missing.append(path)
        elif insert(path, ext):
            changed += 1
            print(f"  + {path}")
    if check:
        if missing:
            print(f"MISSING SPDX header in {len(missing)} file(s):")
            for m in missing:
                print(f"  - {m}")
            return 1
        print(f"OK: all {total} source files carry an SPDX header.")
        return 0
    print(f"\nInserted headers in {changed} file(s) (scanned {total}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
