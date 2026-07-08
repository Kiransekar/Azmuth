# Azmuth — Market & Feasibility Research Findings (evidence base)

Date: 2026-07-08 · Method: fan-out web research (6 angles, 27 sources fetched,
119 candidate claims, top 25 adversarially verified by 3-vote refutation —
22 confirmed, 3 refuted). This file is the cited evidence base the plan set
(INDUSTRY_TARGET.md, TAPEOUT_PLAN_v2.md, RISK_PLAN.md, FPGA_PLAN.md) draws
from. Per the evidence rule (TAPEOUT §A.7), any market/feasibility number in
those plans links here; anything not here is marked `[verify]` and must not
be asserted as fact.

Confidence tags are the verification vote (e.g. 3-0 = all three skeptics
failed to refute). CONTESTED / REFUTED / OPEN items are called out because
they change decisions.

---

## 1. Competition — the decisive finding

### F-1 (CONFIRMED 3-0) — SynSense Xylo IMU is a direct, shipping competitor
A fully-digital SNN inference chip with a dev kit (HDK) launched **Sept 25,
2023**, whose own launch page lists **"Preventative maintenance by detecting
imminent failure, continuously at low power"** and **"Vibration-based
analysis of machine operation"** as target applications, at **<500 µW**.
Source: synsense.ai launch page (primary); corroborated by Hackster.io and
Xylo datasheets (measured inference ~93–550 µW across the family).
**Impact:** Azmuth is NOT entering an empty niche. Xylo IMU occupies the
*exact* target (always-on vibration CM at sub-mW) with silicon that ships
today on an advanced node. The <500 µW figure is the power bar. Azmuth
cannot win on "a neuromorphic chip for vibration CM exists" — that box is
ticked by a funded competitor. It must win on the axes Xylo lacks
(completeness: full RV32IMC SoC + on-chip STDP learning + NVM + debug;
open-flow auditability; India-sovereign supply) — see RISK R-03.
Caveat: vendor positioning, not proven design wins; <500 µW is family-level
marketing.

### F-2 (CONFIRMED 3-0) — the conventional-MCU gap is real (but narrower than assumed)
ST's **official ISM330DHCX Machine Learning Core** vibration example runs at
only **26 Hz ODR / ±4 g** (Nyquist 13 Hz) and classifies **three coarse
intensity levels** (no/low/high vibration) — not bearing fault *types*.
Source: ST's own GitHub README (primary).
**Impact:** the stock MLC cannot do kHz-band bearing-fault envelope analysis
or a 10-class diagnosis — a genuine capability gap. BUT the same sensor
supports up to 6.66 kHz ODR, and ST's **NanoEdge AI Studio** can train
custom fault classes. So the honest framing is "the out-of-box MLC example
is a coarse alarm, not a diagnostic" — do NOT claim the ST part is
*incapable*, only that its turnkey path is.

### F-3 (context, not separately verified) — the other competitors
Innatera Pulsar, BrainChip Akida, GreenWaves GAP9, Cortex-M55+Ethos-U55
appeared in sources but their specific specs did NOT reach the verified set.
`[verify]` before quoting any number for them. GAP9 "AI in earbuds at 50 mW"
(jonpeddie, secondary) is the only datapoint seen and is unverified.

---

## 2. Benchmark — CWRU is standard but the protocol is a trap

### F-4 (CONFIRMED 3-0) — CWRU is the de-facto benchmark, with documented pitfalls
Smith & Randall 2015 (MSSP, ~2000 citations): CWRU "has become a standard
testing resource," yet "without any recognized benchmark it is difficult to
properly assess the performance of any proposed diagnostic methods." The
paper applied three established envelope-analysis techniques to the whole
dataset and documented per-record anomalies — **not all CWRU records are
equally diagnosable.**
Source: sciencedirect S0888327015002034 (primary).

### F-5 (CONFIRMED 3-0 / 2-0) — the standard split leaks; use bearing-independent partitioning
Hendriks et al. 2022 (MSSP): "the accepted procedure of constructing
training and testing datasets with different operating conditions does not
constitute a useful domain shift problem **since the same physical bearings
exist in both training and testing sets**"; they propose "an alternative
benchmarking framework that constructs training and testing datasets with
independent sets of bearings."
Source: sciencedirect S0888327021010499 (primary).
**Impact (decisive for FPGA_PLAN F7):** the common ≥99% CWRU numbers are
inflated by data leakage. Azmuth's benchmark MUST report **bearing-
independent (leakage-safe) splits** to be credible. Accuracy under that
regime is materially lower and is what goes in the trust ledger.

### F-6 (CONFIRMED 3-0, but narrow) — small SNNs on CWRU exist; STDP+simple-features unproven
The one verified SNN-bearing paper (Zuo et al. 2020, Measurement) uses a
**shallow single-layer SNN with the improved-tempotron rule on
LMD-decomposed spike encodings**. So a small on-chip SNN is in line with the
literature — BUT: (a) it uses **tempotron, not STDP**; (b) it uses **Local
Mean Decomposition**, a non-trivial signal decomposition, **not simple
features**.
Source: sciencedirect S0278612520301138 (primary).

### F-7 (REFUTED 0-3) — "simple features validate the plan"
The claim that the confirmed paper's features are "simple," supporting
Azmuth's "SNN + simple EML features" approach, was **refuted 0-3**: LMD is a
sophisticated decomposition. **Correction:** do not assert that simple
log-band/kurtosis/crest features suffice for the SNN to hit high accuracy.
The feature front-end may need more than the EML unit's exp/ln primitives
provide; treat feature adequacy as an OPEN engineering question the F7.1
host study must settle empirically.

### F-8 (OPEN — did not verify) — the ≥95% 10-class gate
**No SNN-on-CWRU accuracy figure at ~256-neuron scale under leakage-safe
splits survived verification.** Whether ≥95% 10-class is realistic for a
256-neuron STDP SNN with EML features is **unresolved**. **Correction:** the
≥95% success gate in the earlier draft is unsupported hope. Reframe the
benchmark to *measure and publish whatever the number is* under bearing-
independent splits, with the novelty-detection (one-class) result — the
actually-bought capability — as the primary metric, not 10-class accuracy.
Paderborn and NASA IMS as generalization sets: named in the brief but their
specifics did not verify — `[verify]`.

---

## 3. Silicon feasibility — two decisions change

### F-9 (CONFIRMED 3-0) — SKY130 ReRAM exists but is immature and frozen
`sky130_fd_pr_reram` is a real SkyWater/Google Apache-2.0 library (v2.0.3),
BUT its GitHub repo was **archived read-only on 2026-04-18** (27 total
commits, 16 open issues, no code since April 2022). Official docs:
**"This technology is still under development and the following procedures do
not guarantee the results indicated"**; "Initial documentation only
release." No shuttle track record on its landing page.
Sources: github.com/google/skywater-pdk-libs-sky130_fd_pr_reram +
readthedocs (both primary).
**Correction to DECISION-011 / BUG-A11:** my earlier justification — "SKY130
has no open ReRAM" — is **factually wrong**. Open ReRAM exists. The correct
reasoning is: it is **experimental, unmaintained (archived), and has no
demonstrated shuttle tapeout** — a high-risk, unproven path unfit for a
near-term tapeout. The re-scope (ship the NVM *controller* on SRAM
emulation + off-die SPI-flash persistence, document ReRAM as a future
licensing/experimental path) **stands, on corrected grounds.**

### F-10 (CONFIRMED 3-0 / 2-1) — a ReRAM shuttle path exists but "be among the first"
ChipFoundry supports ReRAM on its **ChipCreate SKY130 MPW shuttles**
(Nov 2025 CI2511 run confirmed via Tiny Tapeout ttsky25b), but its own page
frames customers as **"among the first to leverage this advanced memory
technology"** — implying no established track record. Yield/maturity/pricing
undisclosed.
Sources: chipfoundry.io/reram (primary), tinytapeout.com/chips/ttsky25b.

### F-11 (CONFIRMED, from sources) — Efabless / ChipIgnite is DEAD; successors exist
Efabless **shut down** (Tom's Hardware; EENewsEurope: "Tiny Tapeout sees
industrial boost as it recovers from Efabless closure"). Successors for
SKY130 MPW: **Tiny Tapeout** (tile-scale, cheap) and **ChipFoundry**
(ChipCreate MPW, full projects, ReRAM-capable).
**Correction to DECISION-006 / P6-T1:** "ChipIgnite-class shuttle" is stale.
The vehicle decision must be re-opened between ChipFoundry ChipCreate MPW
and Tiny Tapeout, with cost/area re-priced against real 2025-2026 offerings.
IHP SG13G2 (open 130nm BiCMOS, EU) is a named alternative to evaluate.

### F-12 (OPEN — did not verify) — 100 MHz SKY130 RV32IMC fmax
**No silicon datapoint for real SKY130 RV32IMC-class fmax survived
verification.** Whether a 3-stage RV32IMC closes at 100 MHz on SKY130 is
**unvalidated.** **Correction:** keep 100 MHz as a *target* explicitly
labelled unvalidated; the P5 STA baseline (first honest numbers) may force a
derate to ~40–60 MHz. Do not present 100 MHz as precedent-backed.

### F-13 (CONFIRMED 3-0) — multi-year battery life on a 130nm-class part is plausible
MSP430 (130nm-era ULP MCU precedent): **400 µA active, 1.3 µA standby
(LPM3, 32 kHz + RTC running), 0.1 µA off (LPM4, still interrupt-wakeable),
typ at 3 V**; TI documents a **10-year RTC at 1.52 µA average** (~133 mAh
over 10 yr — trivially within 2×AA lithium).
Source: ti.com MSP430 39113.pdf (primary, text-verified).
**Impact:** the duty-cycled-sleep energy premise is credible in principle.
Caveats: room-temp typicals, 400 µA active is ~1 MHz, and Azmuth's own sleep
floor depends on *its* power-gating/body-bias implementation — this is
precedent that the class works, not a measurement of Azmuth. The claim still
requires Azmuth's own UPF/power evidence (RISK R2-T4 / TAPEOUT P3-T5).

---

## 4. Market & failure statistics — mostly UNVERIFIED, one CONTESTED

### F-14 (REFUTED / CONTESTED) — the bearing-failure share statistic
The specific "EPRI ~24% of failures" claim was **refuted 0-3**, and the
literature is genuinely split: the **denominator matters** — ~24% is "of the
872 failed *motors*," while the widely-cited **~41–42%** is "of *failures*"
(Albrecht/EPRI and IEEE-IAS Gold Book lineage). The raw counts (4,797 utility
motors, 1,227 failures across 872 motors) are real; the *percentage* is not
citable as a single fact.
**Correction:** do NOT state a bearing-failure percentage as fact. Say
"bearings are consistently the largest single failure category in the
classic IEEE-IAS / EPRI motor-reliability surveys; the exact share (≈24–42%)
depends on denominator and study" and cite the ambiguity. `[verify against
the primary IEEE-IAS motor-reliability survey papers before quoting.]`

### F-15 (UNVERIFIED) — market size / CAGR / node price / battery norms
Grand View, MarketsandMarkets, Future Market Insights, endaq, kcftech, cbm
sources were fetched but **no market-size, CAGR, node-price, or battery-life
norm survived verification.** All such figures remain `[verify]`. RISK R2-T3
must source these from named firms with dates before any pitch uses them.

---

## 5. Standards & India funding

### F-16 (CONFIRMED 3-0) — DLI is real; C-DAC is the nodal agency; window currently CLOSED
ism.gov.in (primary, last updated 12.06.2026): "CDAC is responsible for
implementation of the DLI Scheme as Nodal Agency," offering "financial
incentives as well as design infrastructure support … over a period of 5
years" (deployment incentive 6%→4% of net sales, ceiling ₹30 Cr; PIB PRID
1790346). **Application status: the portal shows "Application Closed"**
(DLI 1.0 window Jan 2022–Dec 2024); DLI 2.0 is in redesign/relaunch. (Closure
passed 2-1: the page also retains an "Apply" link, so track the 2.0
relaunch rather than assume permanently shut.)
Sources: ism.gov.in/design-linked-incentive, chips-dli.gov.in.
**Correction to RISK R5-T1:** DLI is a real route but **not currently open** —
frame as "prepare the package, track DLI 2.0 relaunch," not "apply now."
Also: India ran **5 MPW runs over the past 12 months** via SCL/C-DAC
democratizing domestic fab access (circuitdigest, secondary) — a real
SCL-180 second-source signal for RISK R-09 / TAPEOUT P7-T3, worth verifying
for startup eligibility.

### F-17 (UNVERIFIED) — ISO 10816 → 20816 supersession
Only a blog source (engineering-update.co.uk) touched this; the ISO.org page
returned nothing usable. The 10816→20816 supersession and the ISO 13373 /
ISO 15243 governance claims are **`[verify]` against ISO directly** before
asserting.

---

## 6. Net effect on the plan set

| Earlier assertion | Verdict | Correction |
|---|---|---|
| Industrial vibration CM is the target niche | ✅ real market | But **contested** — Xylo IMU ships there today (F-1). Positioning shifts from "we found a niche" to "we out-complete an occupied one." |
| "SKY130 has no open ReRAM" (DECISION-011 basis) | ❌ wrong fact | ReRAM exists but is archived/experimental/unproven (F-9). Re-scope stands on corrected grounds. |
| ChipIgnite-class shuttle (DECISION-006) | ❌ stale | Efabless dead (F-11). Re-decide: ChipFoundry ChipCreate MPW vs Tiny Tapeout vs IHP SG13G2. |
| 100 MHz core target | ⚠️ unvalidated | Label as target; expect possible derate to 40–60 MHz at P5 STA (F-12). |
| ≥95% 10-class CWRU gate | ❌ unsupported | No verified SNN number; and standard splits leak (F-5,F-8). Use leakage-safe splits; publish measured number; lead with novelty detection. |
| "simple features suffice" | ❌ refuted | Feature adequacy is an open question (F-7). |
| bearing failures ~40-50% (my earlier text) | ⚠️ contested | Don't state a single %; cite the 24-42% denominator ambiguity (F-14). |
| Multi-year battery on 130nm | ✅ plausible | Precedent solid (F-13); still needs Azmuth's own power evidence. |
| DLI funding route | ✅ real, ⚠️ closed | Track DLI 2.0; not open now (F-16). |
| market size / CAGR numbers | ⚠️ unverified | Kept as `[verify]`; source before pitching (F-15). |
