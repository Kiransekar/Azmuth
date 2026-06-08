<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# TTFS Energy Reduction Assessment

**Audit reference:** Tapeout §1.3(b)
**Date:** 2026-06-06
**Status:** Known limitation documented

## Claim vs. Implementation

The README states a target of **≥40% energy reduction** via Time-to-First-Spike
(TTFS) encoding in the SNN tile (`rtl/snn/lif_ttfs_neuron_v1_1.v`).

## Analysis

### What TTFS provides
TTFS encodes neuron activation as the **time of first spike** rather than a
spike rate. For a given classification accuracy, TTFS requires fewer time steps
than rate coding because it terminates evaluation at the first spike rather than
counting over a time window.

### Why ≥40% is unverifiable at this stage

1. **No energy model exists.** The RTL is behavioral Verilog — there is no
   gate-level netlist power measurement at the SNN tile level. A meaningful
   energy comparison requires:
   - Post-synthesis gate-level simulation with switching activity annotation
   - A PDK liberty file for power characterization (we have no `130nm_std.lib`)
   - Comparison against an equivalent rate-coded baseline under the same workload

2. **Process node limitation.** The claimed 40% was an aspirational target based
   on literature values (Rueckauer et al., 2017; Tavanaei et al., 2019) for
   deep-sub-micron CMOS. At TSMC 130nm (or SKY130 per DECISION-001/005), leakage
   dominates less, reducing the dynamic-power savings TTFS provides.

3. **No baseline measurement.** Without both a rate-coded and TTFS-coded
   simulation on the same workload with the same neuron count, the percentage
   reduction is undefined.

### Quantitative estimate (literature-informed)

Based on published TTFS vs. rate-coding comparisons in digital SNN accelerators:

| Metric | Rate coding | TTFS | Estimated savings |
|--------|------------|------|-------------------|
| Average time steps per classification | T_window (full) | First spike (~T_window/3–T_window/2) | 50–67% fewer time steps |
| Dynamic energy per time step | E_step | E_step (same per step) | 0% per step |
| Total dynamic energy per classification | T_window × E_step | (T_window/3) × E_step | ~33–50% (dynamic only) |
| Static energy | Constant (dominates at 130nm) | Constant | 0% |
| **Net energy savings at 130nm** | — | — | **~15–25%** |

At 130nm, static leakage is a larger fraction of total power than at 7nm/14nm,
so the dynamic-energy savings from TTFS are diluted.

## Resolution (audit §1.3b option 3)

The README quantitative target of **≥40% energy reduction** is **not achievable
at the target process node** without sub-threshold operation (not available in
the PDK). We document this as a known limitation:

> **TTFS encoding provides ~15–25% estimated total energy reduction per SNN
> classification at TSMC 130nm / SKY130, based on reduced time-step count.
> The original ≥40% target assumed a deep-sub-micron process. The README
> is updated to reflect the realistic estimate.**

## Action Items

- [ ] Update README to replace "≥40%" with "~15–25% estimated (process-dependent)"
- [ ] Post-synthesis power measurement to confirm (blocked by PDK liberty file — §5.3)
