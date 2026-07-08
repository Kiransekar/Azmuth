<!-- ============================================================================
  AZMUTH TARGET-INDUSTRY ANALYSIS & BENCHMARK DEFINITION — v1.1
  ============================================================================
  STATUS: READ-ONLY analysis document. v1.1 (2026-07-08) rebuilds v1.0 on a
  verified evidence base (docs/RESEARCH_FINDINGS.md — 6-angle web research,
  25 claims adversarially verified). Every non-obvious market/feasibility
  fact links to a finding ID (F-n) there; anything without one is `[verify]`
  and must NOT be asserted as fact. Positioning tasks that act on this
  analysis live in RISK_PLAN.md; the executable benchmark lives in
  FPGA_PLAN.md Phase F7.

  v1.0 → v1.1 changelog (what the research overturned):
   - Xylo IMU is a DIRECT shipping competitor in this exact niche (F-1) —
     framing shifts from "empty niche" to "occupied niche we out-complete."
   - CWRU standard splits LEAK (same physical bearings train+test, F-5);
     the ≥95% 10-class gate is UNSUPPORTED (F-8) — reframed around
     leakage-safe splits + novelty detection.
   - "simple features suffice" was REFUTED (F-7) — feature adequacy is open.
   - bearing-failure % is CONTESTED (24-42%, denominator-dependent, F-14) —
     no single number asserted.
   - market-size/CAGR/price/battery-norm figures did NOT verify (F-15) —
     kept as [verify].
  ============================================================================ -->

# Azmuth — Target Industry, Breakdown, and Benchmark Definition (v1.1)

## 0. What changed and why it still holds

The research **did not refute** the target choice — industrial vibration
condition monitoring is a real market that neuromorphic silicon is
explicitly built for. But it refuted the *comfortable* version of the story.
The niche is **already occupied by a shipping competitor** (SynSense Xylo
IMU, <500 µW, launched 2023 — F-1), the go-to **benchmark protocol is a
data-leakage trap** (F-5), and the **≥95% accuracy hope has no evidence**
(F-8). The target survives because Azmuth's defensible ground is not "an SNN
for vibration" (taken) but **a complete, auditable, sovereign RISC-V SoC**
that happens to include one. Everything below is rebuilt on that harder,
truer footing.

## 1. Decision

**Primary target: industrial machine-condition monitoring / predictive
maintenance — always-on vibration anomaly detection at battery-powered
wireless sensor nodes on rotating machinery** (motors, pumps, fans,
compressors, gearboxes, bearings). VALIDATED as a real neuromorphic-silicon
market (F-1), CONTESTED by an incumbent (F-1).

**Secondary (documented fallback): wearable/ambulatory biosignal monitoring**
(ECG arrhythmia flagging) — architecturally similar, kept warm, not pursued
in parallel.

**Benchmark: CWRU bearing-fault classification under bearing-INDEPENDENT
(leakage-safe) train/test splits** (F-4, F-5), with novelty/anomaly
detection as the primary metric and 10-class accuracy as a secondary,
honestly-reported figure (F-8). Paderborn / NASA IMS as generalization sets
`[verify]`.

## 2. Why this industry — the decision matrix (unchanged direction, corrected competition row)

Scored against what the architecture is (RV32IMC ~100 MHz-target core +
constant-time Q16.16 EML math + 256-neuron TTFS SNN with on-chip STDP + NVM
controller + per-tile power/body-bias + fault monitor/SECDED/watchdog + real
RISC-V Debug Module, on a SKY130 MPW shuttle):

| Criterion | Industrial CM | Wearable biosignal | Agri/aqua sensing | Consumer audio (KWS) | Defense/space edge AI |
|---|---|---|---|---|---|
| Signal band fits kHz sensing + ~100 MHz | ✅ vibration ≤20 kHz | ✅ ECG ≤1 kHz | ✅ | ✅ 16 kHz | ✅ |
| Event-driven/always-on fits SNN+TTFS | ✅ | ✅ | ✅ | ✅ | ✅ |
| On-chip STDP a real differentiator | ✅✅ per-machine baselines differ | ✅ per-patient | ◐ | ✗ fixed models win | ◐ |
| Tolerates 130nm economics | ✅ node BOM $100-1000 `[verify]` | ✗ cost/mm² pressure | ◐ | ✗✗ | ✅ |
| Mature node is an ASSET (temp/longevity) | ✅✅ | ◐ | ✅ | ✗ | ✅✅ |
| Fault/SECDED/watchdog valued | ✅ | ✅ | ◐ | ✗ | ✅✅ |
| Cert burden reachable for a small team | ✅ often advisory-only | ✗ medical clearance | ✅ | ✅ | ✗ program-gated |
| **Competition at the node level** | **◐ CONTESTED — Xylo IMU ships here (F-1)** | ✗ brutal (22nm MCU+NPU) | ✅ low | ✗✗ | ◐ incumbent primes |
| Founder synergy (Upcheck/SAVAI, India base) | ✅ | ✗ | ✅✅ | ✗ | ◐ (AEGIS occupies it) |
| Public benchmark dataset exists | ✅✅ CWRU (F-4) | ✅ MIT-BIH | ✗ | ✅ GSC | ✗ |

Industrial CM still wins — it is the only column where on-chip learning,
event-driven power, and mature-node robustness are all *bought*. The honest
change from v1.0: the competition cell dropped from ✅ to ◐. That is not a
reason to abandon it; it is the reason the positioning (RISK R-03) must be
"complete SoC + auditable evidence + sovereignty," never "we have an SNN."

## 3. Industry breakdown

### 3.1 The problem
Unplanned downtime of rotating machinery. Bearings are consistently the
largest single failure category in the classic IEEE-IAS / EPRI motor-
reliability surveys — **but the exact share is contested: ≈24–42% depending
on denominator (% of failed motors vs % of failures) and study** (F-14). Do
not quote a single percentage; quote the range and the ambiguity. The raw
EPRI counts (4,797 utility motors; 1,227 failures across 872 motors) are
real. Predictive-maintenance market size and CAGR: **`[verify]` — no figure
survived verification (F-15)**; RISK R2-T3 sources them from named firms
before any pitch.

### 3.2 Value chain and where Azmuth sits
```
MEMS/piezo accelerometer → [SENSOR-NODE SoC ← AZMUTH] → LPWAN/BLE gateway
      → plant historian/CMMS → analytics dashboard → maintenance decision
```
Azmuth is the smart-sensor-node SoC between accelerometer and radio; its job
is to make the radio (dominant energy consumer) almost never transmit —
compute locally, transmit only classifications/anomalies. Multi-year battery
life on a duty-cycled 130nm-class part is **plausible by precedent**: the
MSP430 (130nm-era ULP MCU) hits 1.3 µA standby / 0.1 µA off and a documented
10-year RTC at 1.52 µA average (F-13) — but that is precedent that the class
works, not a measurement of Azmuth; Azmuth's own sleep floor must be proven
by its power evidence (TAPEOUT P3-T5 / RISK R2-T4).

### 3.3 Buyer and requirements profile
- **Buyer:** sensor-node OEMs and industrial-IoT integrators (not end
  plants). India angle: Make-in-India automation suppliers; founder-adjacent
  aquaculture pump/aerator monitoring as a captive first deployment.
- **Hard requirements:** −40…+85 °C; multi-year battery at duty-cycled
  operation (avg node power ~1 mW-class `[verify]`); 10+-year part
  availability (130nm longevity is an asset); deterministic sample-to-
  decision latency; watchdog/self-test (unattended nodes); firmware update
  integrity.
- **Differentiators:** per-machine baseline learning without cloud round-
  trips (STDP); on-node event logging surviving power loss (NVM controller +
  SPI flash). Feature-front-end quality is an OPEN question — the confirmed
  SNN-bearing literature uses Local Mean Decomposition, NOT simple features
  (F-6, F-7), so "EML exp/ln features are sufficient" is unproven and must be
  demonstrated, not claimed.
- **Standards context (advisory monitoring, not control):** ISO 20816 /
  ISO 10816 vibration severity, ISO 13373 practice, ISO 15243 bearing damage
  taxonomy — **all `[verify]` against ISO directly (F-17)**; the
  10816→20816 supersession was not verifiable from a primary source. IEC
  61508 only if the node gates an interlock ("designed to" phrasing only).

### 3.4 Competitive landscape (the corrected core)
| Alternative | What it is | Where it beats Azmuth | Where Azmuth differs | Evidence |
|---|---|---|---|---|
| **SynSense Xylo IMU** | **Digital SNN + HDK, ships since 2023, explicitly for vibration CM at <500 µW** | **Shipping silicon on advanced node; funded; the target's incumbent** | Xylo is an SNN *inference* accelerator; Azmuth is a *complete RISC-V SoC* (CPU+SNN+math+NVM+debug), open-flow auditable, on-chip STDP learning, sovereign path | **F-1 (CONFIRMED)** |
| ST ISM330DHCX + MLC | MEMS + on-sensor ML core | Cost, maturity, ecosystem | Stock MLC example = 26 Hz, 3 coarse classes only (F-2); can't do kHz fault diagnosis turnkey (though NanoEdge AI can, custom) | F-2 (CONFIRMED) |
| Innatera Pulsar / BrainChip Akida | Commercial neuromorphic | Shipping, funded | Same completeness/sovereignty argument as Xylo | specs `[verify]` (F-3) |
| GAP9 / Cortex-M55+U55 | DSP/NPU edge-AI (22-40nm) | Energy/MAC, tooling | Frame-based, no per-node learning, no constant-time story | `[verify]` (F-3) |
| Gateway analytics on raw streams | Compute at the gateway | No node silicon | Battery/radio economics of streaming; latency; connectivity dependence | — |

**Honest weaknesses (published, per the trust doctrine):** (1) a funded
competitor already ships in the exact niche (F-1) — Azmuth's edge is
completeness+auditability+sovereignty, not novelty; (2) no silicon yet;
(3) 130nm loses energy-per-op to 22nm rivals on *active* compute — the
counter (sleep dominance + duty cycle) is plausible (F-13) but must be
*measured*, not asserted; (4) SNN accuracy on leakage-safe bearing splits is
unproven (F-8) and the feature front-end may need more than EML provides
(F-7); (5) single-person vendor (RISK R-04).

### 3.5 Architecture-to-requirement map (the pitch skeleton)
| Azmuth feature | Requirement served | Caveat |
|---|---|---|
| SNN-256 TTFS + WTA | Always-on fault classification at low duty | accuracy TBD under leakage-safe splits (F-8) |
| On-chip STDP (6 policies) | Per-machine baseline adaptation without cloud | the *differentiator vs Xylo*; must be demonstrated (R2-T2) |
| EML Q16.16 exp/ln, constant-latency, memoized | Log-band energies, envelope features at fixed cost | feature sufficiency unproven (F-7) |
| Deterministic core + constant-time + policy determinism | Bounded sample-to-decision latency; WCET evidence | core fmax target unvalidated (F-12) |
| NVM controller (SECDED, wear-leveling) + SPI flash | Event/trend logging surviving power loss | ships on SRAM-emu, not ReRAM (F-9; DECISION-011) |
| Per-tile power + body-bias | Multi-year battery posture | precedent-plausible (F-13); prove with UPF evidence |
| Fault monitor + watchdog + SECDED + MBIST | Unattended-node self-integrity | — |
| RISC-V + real Debug Module + pinned toolchain | OEM firmware ecosystem, gdb-into-the-chip demo | a real edge vs closed neuromorphic parts |

## 4. The benchmark (definition — executable spec in FPGA_PLAN F7)

**Dataset:** CWRU Bearing Data Center corpus — drive-end accelerometer,
12 kHz (48 kHz variant available), SKF 6205, seeded inner-race/outer-race/
ball faults × 0.007″/0.014″/0.021″, 0–3 hp loads. Confirmed de-facto standard
(F-4). Commit the exact file list + preprocessing + split to
`docs/references/cwru_manifest.md`.

**Two non-negotiable protocol rules from the research:**
1. **Bearing-independent splits (F-5):** training and test use *different
   physical bearings*. The common ≥99% numbers are leakage-inflated; Azmuth
   reports leakage-safe accuracy or the number is not credible.
2. **Novelty detection is the primary metric (F-8):** train on normal-only
   data, measure fault-detection ROC after simulated baseline drift — this
   is the STDP-differentiated, actually-bought capability. 10-class accuracy
   is secondary and reported at whatever value it lands, with the model-size
   context, never gated at a hoped ≥95%.

**Pipeline under test (all on Azmuth):** 12 kHz frame ingest → EML feature
extraction (log band energies over bearing characteristic frequencies
BPFO/BPFI/BSF/FTF from rpm, RMS, kurtosis, crest) → TTFS spike encoding →
SNN-256 WTA classify → NVM event log, under the S7 executive. **Feature-
adequacy caveat (F-7):** if EML primitives prove insufficient vs an
LMD-class front-end, that gap is a finding to publish, and either an
engineering task or an honest limitation — not something to paper over.

**Published metrics (evidence files, per TAPEOUT §A.7):**
- Novelty ROC (primary) + 10-class accuracy (secondary) under **bearing-
  independent splits**, vs the Python golden model (RTL must match — P3-T3)
  and a documented MCU software baseline.
- Cycles per frame, per stage; frames/s headroom at the achieved fmax
  (cycles first, always).
- Jitter = 0 across frames (legitimate only because BUG-A3's fix made memo
  hits constant-latency — cite the P3-T1 campaign).
- Xcew value: cycles across three builds (pure RV32IMC software / EML-accel /
  EML+SNN) — TOOLCHAIN S9-T1.
- Energy posture: FPGA can't measure ASIC power — publish activity proxies
  (spike counts, sleep residency, memo-hit rates) + UPF simulation estimates
  vs the <500 µW Xylo bar (F-1), each labelled as estimate.

**Success framing (honest, not gated on hope):** report the leakage-safe
novelty ROC and 10-class accuracy at whatever value they land; zero cycle
jitter; the EML/SNN cycle deltas. If accuracy trails heavier models, publish
it with the 256-neuron context and let the novelty-detection result + the
determinism + the completeness story carry the pitch. `[verify]` any target
number against F7.1's measured golden-model result before it enters the
trust ledger.

## 5. What this analysis binds
- FPGA_PLAN F7 implements §4 verbatim, INCLUDING the bearing-independent-
  split and novelty-primary rules — no leakage-inflated numbers.
- RISK_PLAN R2/R3 cite this document and docs/RESEARCH_FINDINGS.md; every
  `[verify]` is replaced with sourced data before any external use, and the
  positioning leads with completeness/sovereignty vs Xylo, not novelty.
- Any pivot (e.g. to the biosignal fallback) is a DECISIONS.md entry.
