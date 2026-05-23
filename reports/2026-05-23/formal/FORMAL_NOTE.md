<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# Formal Verification Note — 2026-05-23

Tapeout audit §1.3(c) / §3.5.11. Tool: SymbiYosys (`sby`) — **installed**
(`~/.local/bin/sby`).

## Result: the `.sby` files are malformed; no property can run

`sby -f sby/eml.sby` fails immediately:

```
ERROR: sby file syntax error: unexpected section 'defs',
       expected one of 'options, engines, script, autotune, file, files'
```

Inspection of `sby/eml.sby` (and the others) shows two invalid sections:

- `[defs]` — not a SymbiYosys section.
- `[property]` — not a SymbiYosys section. SBY does not declare properties in
  the `.sby` file; properties must be **SystemVerilog assertions embedded in the
  RTL** (or a bound `[file]`), which `prep`/`smtbmc` then check.

So the README's claim of "18 formal properties across eml/snn/security/power" is
**not provable as configured** — the harness has never been able to run. This is
the honest status behind audit §1.3(c).

## Why this was not hot-fixed

The intended assertions reference signals (`depth_cnt`, `i_cfg[14:12]`,
`overflow_detected`, `xcew_status`, `cache_hit`, `o_valid`) whose existence/width
in `rtl/eml/eml_unit.v` must be confirmed before binding. A `.sby` rewrite that
"passes" without verified, correctly-bound assertions would be a **vacuous
proof** — worse than no proof for an audit centered on claim-vs-evidence
integrity. Producing real proofs is Pair C verification work:

1. Author SVA in (or bound to) each unit against confirmed signal names.
2. Replace the invalid `[defs]`/`[property]` sections; keep `[options]`,
   `[engines]`, `[script]`, `[files]`.
3. Run `make formal`; commit proof logs to `sby/proofs/<task>.log`.

§1.3(c) remains **OPEN**. The README formal-verification claim should be
softened to "formal properties drafted; harness not yet operational" until then.
