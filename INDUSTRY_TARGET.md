<!-- ============================================================================
  AZMUTH TARGET-INDUSTRY ANALYSIS & BENCHMARK DEFINITION — v1.0
  ============================================================================
  STATUS: READ-ONLY analysis document. Positioning tasks that act on this
  analysis live in RISK_PLAN.md; the executable benchmark lives in
  FPGA_PLAN.md Phase F7. Market figures marked [verify] are order-of-
  magnitude planning inputs; RISK_PLAN R2-T3 replaces them with cited data.
  ============================================================================ -->

# Azmuth — Target Industry, Breakdown, and Benchmark Definition

## 1. Executive decision

**Primary target: industrial machine-condition monitoring (predictive
maintenance) — always-on vibration/acoustic anomaly detection at the sensor
node**, on rotating machinery (motors, pumps, fans, compressors, gearboxes,
bearings).

**Secondary (documented fallback): wearable/ambulatory biosignal
monitoring** (ECG arrhythmia flagging) — architecturally similar workload,
kept warm as a pivot, not pursued in parallel.

**Benchmark workload: rolling-element bearing fault classification on the
CWRU (Case Western Reserve University) bearing dataset** — the de-facto
public standard for this industry — running end-to-end on Azmuth
(EML feature extraction → spike encoding → SNN-256 classification →
NVM event logging), validated on FPGA per FPGA_PLAN.md Phase F7.

## 2. Why this industry — the decision matrix

Candidates were scored against what the architecture actually is
(RV32IMC + constant-time EML fixed-point math + 256-neuron TTFS SNN with
on-chip STDP learning + NVM-ready controller + per-tile power orchestration
+ fault monitor/SECDED/watchdog + honest 100 MHz @ 130nm):

| Criterion | Industrial condition monitoring | Wearable biosignal | Smart-agri/aqua sensing | Consumer audio (KWS) | Defense/space edge AI |
|---|---|---|---|---|---|
| Signal bandwidth fits 100 MHz + kHz-band sensing | ✅ vibration ≤20 kHz | ✅ ECG ≤1 kHz | ✅ | ✅ 16 kHz | ✅ |
| Event-driven/always-on fits SNN+TTFS | ✅ anomaly = rare event | ✅ | ✅ | ✅ | ✅ |
| **On-chip STDP learning is a real differentiator** | ✅✅ every machine's baseline differs; per-node adaptation avoids cloud retraining | ✅ per-patient adaptation | ◐ | ✗ fixed models win | ◐ |
| Tolerates 130nm economics (node BOM $50–500, not $1–5) | ✅✅ industrial sensor nodes are $100–1,000 [verify] | ✗ cost/mm² pressure | ◐ | ✗✗ | ✅ |
| Mature node is an ASSET (temp range, latch-up robustness, longevity/obsolescence guarantees) | ✅✅ | ◐ | ✅ | ✗ | ✅✅ |
| Fault monitor/SECDED/watchdog valued | ✅ IEC 61508-adjacent | ✅ IEC 62304 | ◐ | ✗ | ✅✅ |
| Constant-time/security story valued | ◐ (firmware integrity, tamper) | ✅ (privacy) | ◐ | ✗ | ✅✅ |
| Certification burden reachable for a small team | ✅ SIL-2-adjacent, often none for advisory monitoring | ✗ medical device clearance | ✅ | ✅ | ✗ program-gated |
| Competitive pressure at the node level | ◐ (see §3.4) | ✗ brutal (22nm MCU+NPU) | ✅ low | ✗✗ | ◐ incumbent primes |
| Founder synergy (Upcheck/SAVAI sensing ecosystem, India industrial base) | ✅ | ✗ | ✅✅ | ✗ | ◐ (AEGIS occupies it) |
| Public benchmark dataset exists for credible proof | ✅✅ CWRU/IMS/Paderborn | ✅ MIT-BIH | ✗ | ✅ GSC | ✗ |

Industrial condition monitoring wins on the three axes that are *hard* for
competitors to copy and *native* to this architecture: per-node on-chip
learning, always-on event-driven power posture, and mature-node industrial
robustness. Agri/aqua sensing is deliberately folded in as a *deployment
channel* (an Upcheck pond aerator or pump is a rotating machine — the same
SoC and firmware apply verbatim), not a separate target.

## 3. Industry breakdown

### 3.1 The problem being bought
Unplanned downtime of rotating machinery. Bearing failures are the single
largest cause of motor failure (~40–50% of induction-motor failures in the
classic IEEE/EPRI surveys [verify]). Plants pay for early warning:
detect a bearing defect weeks before failure → schedule maintenance instead
of losing a production line. Predictive-maintenance spend is a
$10B+-class market growing at ~25–30% CAGR [verify]; the sensing tier
(wireless vibration nodes) is the fastest-growing slice as plants
retrofit brownfield equipment that has no built-in instrumentation.

### 3.2 Value chain and where Azmuth sits
```
MEMS/piezo accelerometer → [SENSOR-NODE SoC ← AZMUTH] → LPWAN/BLE gateway
      → plant historian/CMMS → analytics dashboard → maintenance decision
```
Azmuth is the **smart-sensor-node SoC**: it sits between the accelerometer
and the radio, and its entire job is to make the radio (the dominant energy
consumer) almost never transmit. Raw 12 kHz vibration streaming murders a
battery; a node that computes locally and transmits only classifications/
anomalies achieves the 3–5-year battery life the industry demands [verify].
This is precisely the always-on-compute/rare-event-output shape that the
SNN + power-orchestrator architecture exists for.

The deliverable product tiers (RISK_PLAN R3): evaluation kit (FPGA/board +
SDK + benchmark), silicon SoC, and the evidence package (the moat — see
RISK_PLAN R-01).

### 3.3 Buyer and requirements profile
- **Buyer:** sensor-node OEMs and industrial-IoT integrators (not end
  plants). India angle: Make-in-India industrial automation suppliers,
  plus founder-adjacent channels (aquaculture pump/aerator monitoring as a
  first captive deployment).
- **Hard requirements:** −40…+85 °C operation; multi-year battery life at
  duty-cycled operation (average node power budget ~1 mW-class [verify]);
  10+-year part availability (130nm longevity is an asset here);
  deterministic sample-to-decision latency (plant-safety interlocks);
  watchdog/self-test (nodes are unattended); firmware update integrity.
- **Soft requirements that become differentiators:** per-machine baseline
  learning without cloud round-trips (STDP), spectral feature quality
  (EML exp/ln for log-band energy and envelope analysis), on-node event
  logging that survives power loss (NVM controller + SPI flash).
- **Standards context (advisory monitoring, not control):** ISO 10816/20816
  vibration severity zones; ISO 13373 condition-monitoring practice;
  ISO 15243 bearing damage taxonomy; IEC 60068 environmental. Functional
  safety (IEC 61508) only if the node gates an interlock — positioned as
  "designed to" methodology per TAPEOUT §D-12.

### 3.4 Competitive landscape (fact base to be cited in RISK R2-T3)
| Alternative | What it is | Where it beats Azmuth | Where Azmuth differs |
|---|---|---|---|
| MCU + MEMS-with-MLC (ST ISM330 class) | Cortex-M + accelerometer with built-in decision tree | Cost, maturity, ecosystem | Decision trees can't do spectral/temporal patterns; no on-node learning |
| Modern MCU+NPU (GAP9, Cortex-M55+U55 class, 22–40nm) | DSP/NPU edge-AI | Energy per MAC (better node), tooling | Frame-based, always-on cost is duty-cycled polling, no per-node learning, no constant-time story |
| Neuromorphic startups (Innatera Pulsar, SynSense Xylo, BrainChip Akida) | Commercial SNN silicon | Shipping silicon, advanced nodes, funded ecosystems | Azmuth is a *complete RISC-V SoC* (CPU+SNN+math+NVM+debug in one), open-flow auditable, evidence-reproducible, India-sovereign path |
| Cloud/gateway analytics on raw streams | Compute at the edge gateway | No node silicon needed | Battery/radio economics of streaming; latency; connectivity dependence |

**Honest weaknesses (published, per the trust doctrine):** no silicon yet;
130nm loses energy-per-operation to 22nm rivals on *active* compute (the
counter is sleep-state dominance + event-driven duty cycle — must be
*proven* with the P3-T5/F7 energy evidence, not asserted); SNN accuracy on
industrial data must be demonstrated, not assumed (F7 exists to settle
this); single-person vendor risk (RISK R-04).

### 3.5 Architecture-to-requirement map (the pitch skeleton)
| Azmuth feature | Industry requirement it serves |
|---|---|
| SNN-256 TTFS + WTA | Always-on anomaly/fault classification at µW-class average duty |
| On-chip STDP (6 policies) | Per-machine baseline adaptation; drift tracking without cloud retraining |
| EML Q16.16 exp/ln, constant-latency, memoized | Log-band energies, envelope spectra, kurtosis/crest features at fixed cycle cost |
| Deterministic core + constant-time units + policy determinism | Bounded sample-to-decision latency; WCET evidence for interlock-adjacent use |
| NVM controller (SECDED, wear-leveling) + SPI-flash path | Event/trend logging that survives power loss in unattended nodes |
| Per-tile power orchestration + body-bias | Multi-year battery life posture; leakage control across −40…+85 °C |
| Fault monitor + watchdog + SECDED + MBIST | Unattended-node self-integrity; IEC 61508-methodology story |
| RISC-V + real Debug Module + pinned toolchain | OEM firmware ecosystem, no vendor-lock ISA |

## 4. The benchmark workload (definition — executable spec in FPGA_PLAN F7)

**Dataset:** CWRU Bearing Data Center corpus — drive-end accelerometer,
12 kHz sampling (48 kHz variant available), SKF 6205 bearings with
EDM-seeded faults (inner race / outer race / ball; 0.007″/0.014″/0.021″),
four load conditions (0–3 hp, 1730–1797 rpm). Standard 10-class task
(normal + 9 fault×size classes). Secondary generalization set: Paderborn
or NASA IMS run-to-failure corpus for the "did it detect degradation
early?" narrative.

**Pipeline under test (all on Azmuth):**
1. **Ingest** — 12 kHz frames (2048 samples/frame) into SRAM, executive-
   scheduled (TOOLCHAIN S7).
2. **Features (EML)** — per frame: log band energies over bearing-
   characteristic bands (BPFO/BPFI/BSF/FTF harmonics derived from rpm),
   RMS, kurtosis, crest factor — the exp/ln-heavy math the EML unit
   exists for, at contract-fixed cycle cost.
3. **Encode** — feature vector → TTFS spike latencies.
4. **Classify (SNN-256)** — WTA class output; STDP leg: baseline
   adaptation run demonstrating per-machine tuning on normal-only data
   (novelty detection framing) — the differentiator demo.
5. **Log (NVM)** — classification events + trend counters through the NVM
   controller.

**Published metrics (evidence files, per TAPEOUT §A.7):**
- Accuracy: 10-class % on the standard split; novelty-detection ROC for
  the STDP leg. Reported against the Python golden model (must match RTL
  — P3-T3 gate) and against a documented MCU software baseline.
- **Cycles per frame, per stage** (ingest/features/inference/log) and
  frames-per-second headroom at 100 MHz — cycles first, always.
- **Jitter = 0** across frames (the determinism headline; legitimate only
  because BUG-A3's fix made memo hits constant-latency — cite the P3-T1
  campaign).
- Xcew value: cycles in pure-RV32IMC-software vs EML-accelerated vs
  EML+SNN configurations (TOOLCHAIN S9-T1's three builds).
- Energy posture: FPGA cannot measure ASIC power — publish activity
  proxies (spike counts, sleep-state residency under the executive,
  memo-hit rates) + UPF-based simulation estimates, each labeled as such.

**Success gates (honest):** ≥95% 10-class accuracy on the standard CWRU
split (literature-typical for far heavier models — if the SNN lands lower,
publish the number, the model-size context, and the novelty-detection
result, which is the actually-bought capability); zero cycle jitter;
≥5× feature-stage speedup from EML vs soft-float [verify against
measurement — replace with the real number when it exists].

## 5. What this analysis binds

- FPGA_PLAN F7 implements §4 verbatim — no substitute datasets or tasks.
- RISK_PLAN R2/R3 positioning artifacts cite this document and replace
  every [verify] with sourced data.
- Any pivot (e.g. to the biosignal fallback) is a DECISIONS.md entry with
  rationale, not a silent re-aim.
