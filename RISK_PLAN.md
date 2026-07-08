<!-- ============================================================================
  AZMUTH RISK-CLOSURE ROADMAP — MASTER PLAN v1.0
  ============================================================================
  STATUS: READ-ONLY. AGENTS MUST NOT MODIFY THIS FILE. NO EXCEPTIONS.

  Third plan in the set. Prerequisites: TAPEOUT_PLAN_v2.md P0–P5 DONE (P6
  silicon may run in parallel) and TOOLCHAIN_PLAN.md S0–S9 DONE. Inherits
  TAPEOUT_PLAN_v2.md §A AGENT OPERATING PROTOCOL verbatim. Risk tracking in
  docs/RISK_REGISTER.md (created R0-T1).

  HONESTY CLAUSE: several risks are only PARTIALLY closeable by engineering.
  Tasks are tagged:
    [OPUS]/[SONNET] — agent-closeable (artifacts, evidence, automation)
    [HUMAN]         — requires the founder: meetings, signatures, money.
                      Agents PREPARE these to the last inch; they do not
                      EXECUTE them, and never impersonate the founder.
  A risk is never marked CLOSED by an agent alone — the human confirms in
  docs/RISK_REGISTER.md.

  Repo owner: chmod 444 RISK_PLAN.md ;
              git update-index --skip-worktree RISK_PLAN.md
  ============================================================================ -->

# Azmuth — Risk-Closure Plan v1.1

**Premise (from INDUSTRY_TARGET.md v1.1 + docs/RESEARCH_FINDINGS.md):** a
~100 MHz (or even 40–60 MHz — F-12) 130nm part is not a survival risk for
the chosen market — vibration bands top out ~20 kHz; the node's job is
event-driven inference and radio silence, not throughput. But the research
sharpened the real risks: the target niche is **already occupied** by a
shipping competitor (SynSense Xylo IMU at <500 µW — F-1), so R-03 is upgraded
to CRITICAL; the CWRU benchmark must use **leakage-safe splits** (F-5) or its
numbers convince no one; the energy-posture claim (F-13 makes it plausible,
not proven) must be measured; and the India DLI funding window is **currently
closed** pending DLI 2.0 (F-16). This plan closes what is closeable and
shrinks what is not — leading always with completeness + auditability +
sovereignty, the ground Xylo cannot contest.

---

# §R — THE RISK REGISTER (authoritative list)

| ID | Risk | Severity | Closeable by agents | Residual after this plan |
|----|------|----------|--------------------:|--------------------------|
| R-01 | **Trust deficit** — no third party has reason to believe the chip works; the audit showed claims ran ahead of evidence | CRITICAL | ~70% (evidence machine) | Time-in-market |
| R-02 | **"Good-enough MCU" attack** — ST MLC-class sensors and 22nm MCU+NPU undercut a 130nm custom SoC | HIGH | ~60% (positioning + energy-posture proof) | Buyer rationality varies |
| R-03 | **Neuromorphic incumbent gravity — a competitor already ships in Azmuth's EXACT niche.** SynSense Xylo IMU (HDK Sept 2023) explicitly markets <500 µW always-on vibration-based predictive maintenance (RESEARCH_FINDINGS F-1); Innatera/BrainChip ship on modern nodes too. This is no longer "incumbents nearby" — it is "the target is occupied" | **CRITICAL** (upgraded from HIGH) | ~65% (compete on completeness + on-chip STDP + auditability + sovereignty, NOT on "an SNN for vibration") | Their funding/velocity; being second |
| R-04 | **Bus factor = 1** — OEMs won't design in a single-person vendor | CRITICAL | ~40% (survivability artifacts) | Team formation is human work |
| R-05 | **Market entry** — no anchor OEM, no grant, no pilot | CRITICAL | ~50% (packages, demo logistics) | Founder walks into rooms |
| R-06 | **No field heritage** — "has it run in a plant?" is the first OEM question | HIGH | ~50% (heritage ladder) | Calendar time |
| R-07 | **Energy-posture claim unproven** — the entire 130nm defense rests on sleep-state dominance + event-driven duty cycle, currently asserted not measured | HIGH | ~80% (UPF sim + FPGA activity evidence + silicon later) | Silicon measurement |
| R-08 | **IP/licensing** — DECISION-007 (all-proprietary) conflicts with the open-evidence trust strategy; unresolved tension | MEDIUM | ~90% (structure documents) | Legal counsel |
| R-09 | **Supply-chain single-source** — one shuttle story (ChipIgnite) = one point of failure | MEDIUM | ~80% (SCL-180 second-source study, TAPEOUT P7-T3) | Fab relationships |
| R-10 | **Support credibility** — IP without SLAs/errata is a hobby to procurement | MEDIUM | ~85% (infra + docs) | Answering the phone |

---

# §C — PHASES

Order: R0 → R1 → {R2, R3 parallel} → R4 → R5 → {R6, R7 ongoing}.

════════════════════════════════════════════════════════════════════════════
## PHASE R0 — Risk instrumentation  [SONNET, ~2 days]
════════════════════════════════════════════════════════════════════════════

### R0-T1 [SONNET] Create docs/RISK_REGISTER.md
Transcribe §R verbatim; add Owner, Status (OPEN / MITIGATING / HUMAN-GATE /
CLOSED-confirmed-by-human), Evidence links, monthly review date. CI cron
fails if the review date goes >45 days stale.

### R0-T2 [SONNET] The trust ledger
`docs/TRUST_LEDGER.md`: append-only page of every externally verifiable
claim, each with an evidence link — arch-test results (I/M/C/privilege),
lint-zero badge, constant-time campaign, EML accuracy report, SNN
model-equivalence, FI SDC rate, CWRU benchmark numbers, GLS logs, silicon
status (honestly: none), plant-hours (starts at 0 — write the 0). Nothing
enters without a link. This page IS the sales asset.

════════════════════════════════════════════════════════════════════════════
## PHASE R1 — Close R-01: trust deficit  [~2–3 weeks]
════════════════════════════════════════════════════════════════════════════

### R1-T1 [OPUS] The Evidence Book
`docs/evidence_book/` → one PDF: 1-page datasheet (honest numbers,
auto-imported), verification summary (arch-test, formal, coverage, lint),
constant-time campaign, EML accuracy, SNN equivalence, FI results with SDC
rate, CWRU benchmark with methodology, SW_TIMING, known-limitations section
(the trust weapon — incumbents hide theirs; ours lists: no silicon, NVM
re-scope per DECISION-011, 130nm active-energy deficit, model-size accuracy
context). CI rebuilds from source artifacts; hand-edited numbers fail the
build. An [OPUS] adversarial pass reads it as a skeptical OEM engineer and
files gaps as tasks.

### R1-T2 [SONNET] Reproducibility-as-proof
"Verify it yourself in 30 minutes": container + `verify/README.md` that
re-runs lint, the TB suite, an arch-test subset, one formal proof, one FI
batch, and the CWRU benchmark subset on the Verilator model, diffing
against committed baselines. Weekly CI keeps it from rotting. No
neuromorphic competitor offers this; the open flow makes it possible —
NOTE: this requires resolving the R-08 license tension first (an
all-proprietary repo cannot be independently verified; see R7-T2).

### R1-T3 [OPUS prep + HUMAN execution] Third-party eyeballs
Draft: (a) a technical paper on the constant-time-ML + on-chip-STDP
architecture with the CWRU numbers (VLSID / RISC-V Summit class venue);
(b) an open-silicon showcase entry; (c) RISC-V International working-group
participation. Agents draft; the human submits and presents.

════════════════════════════════════════════════════════════════════════════
## PHASE R2 — Close R-02: the good-enough-MCU attack  [~1–2 weeks]
════════════════════════════════════════════════════════════════════════════

### R2-T1 [OPUS] The defensible-ground doctrine
`docs/positioning/WHEN_AZMUTH.md` — an honest decision tree an OEM engineer
could follow: when an MLC-equipped MEMS part or a duty-cycled MCU is the
right call (simple threshold alarms, line-powered nodes, cloud-connected
sites) and when it is not (battery nodes needing spectral/temporal pattern
recognition, per-machine adaptation without cloud, latency-bounded
interlock-adjacent monitoring, sovereignty-constrained supply chains).
Conceding ground we can't win buys credibility on the ground we can.

### R2-T2 [OPUS] The adaptation demonstrator
The killer demo against fixed-model competitors: side-by-side (Verilator or
FPGA) of (a) a fixed classifier and (b) Azmuth with STDP enabled, on a
machine whose baseline drifts (simulated wear/load change) — (a) drowns in
false alarms or misses the fault; (b) adapts and still flags the true
bearing defect. Scripted, one command, screen-recordable. `make demo-adapt`.

### R2-T3 [SONNET] Competitive fact base
`docs/positioning/LANDSCAPE.md`: sourced, dated table of the real
alternatives (ST ISM330/MLC class, GAP9, Cortex-M55+U55 reference designs,
Innatera Pulsar, SynSense Xylo/Speck, BrainChip Akida, plus gateway-
analytics-on-raw-streams) — node, power class, learning capability, what
each certifies, price where public. Every row cited; no editorializing.
This task also replaces every [verify] figure in INDUSTRY_TARGET.md with
sourced data (market size, node BOM, battery-life norms, motor-failure
statistics).

### R2-T4 [OPUS] Energy-posture evidence (R-07)
The 130nm defense must become a number: (a) UPF-based power estimation of
the duty-cycled executive workload (sleep residency from FPGA_PLAN F7 runs
× per-state power from synthesis power reports at the vendored sky130
corners), (b) an honest sensitivity table (what leakage/body-bias must
achieve for a 3-year 2×AA node — and what happens if it doesn't), published
in the Evidence Book with every assumption visible.
**Acceptance:** `docs/evidence/power/energy_posture.md` generated; the
claim "battery-life competitive" appears nowhere without linking it.

════════════════════════════════════════════════════════════════════════════
## PHASE R3 — Close R-03: incumbent gravity  [~2 weeks]
════════════════════════════════════════════════════════════════════════════

Funded neuromorphic startups win on silicon and node. Azmuth must not fight
on "our SNN is better" — it fights on **completeness + evidence + sovereignty**.

### R3-T1 [OPUS] Productize the evidence package
`docs/business/OFFERING.md`, three tiers: (1) **Evaluation tier** — FPGA
board image + SDK + CWRU benchmark + Evidence Book (free or nominal; the
funnel); (2) **Evidence tier** (paid) — reproducible verification
environment, FI framework with customer-workload injection, WCET evidence
tailoring, integration support hours; (3) **Program tier** (paid,
per-design) — silicon licensing, customization (SNN size, feature set),
SCL/second-source tapeout support. Delivery checklist per tier so a sale is
executable, not improvised.

### R3-T2 [SONNET] Benchmark vs the alternatives
Scripted, FPGA-runnable comparison on the axes brochures never publish:
sample-to-decision latency distribution (jitter!), accuracy-per-model-size
on CWRU, adaptation-after-drift (R2-T2 scenario), always-on average duty.
Include at least one MCU software baseline (same C on a Cortex-M4 board)
and one published-numbers comparison for the neuromorphic parts (their own
datasheets, cited) — **explicitly benchmark against the SynSense Xylo IMU's
<500 µW figure (F-1) as the power bar**, honestly noting Azmuth is on a
mature node and competes on completeness/learning/auditability, not µW/MAC.
Accuracy comparisons MUST use leakage-safe bearing splits (F-5) — a win on a
leaky split convinces no informed reviewer. Publish methodology + raw data;
if we lose an axis, publish that too and file the engineering task.

════════════════════════════════════════════════════════════════════════════
## PHASE R4 — Shrink R-04: bus factor  [~2 weeks + ongoing]
════════════════════════════════════════════════════════════════════════════

### R4-T1 [SONNET] The successor test
Adversarial audit: a competent engineer with zero context takes the repo to
a new tapeout using ONLY committed docs. An [OPUS] agent role-plays that
engineer (one RTL fix, one firmware feature, one synth run), files every
stumble as a documentation bug; Sonnet agents fix them. `docs/START_HERE.md`
onboarding path tested in a clean container.

### R4-T2 [OPUS prep + HUMAN] Institutional anchoring dossiers
One deep, personalized technical brief each for the 5 highest-leverage
partners: an IIT SNN/neuromorphic research group (accuracy credibility +
students), C-DAC (India processor ecosystem), one industrial-IoT sensor OEM
engineering head, one plant-services/CBM company (channel partner), and
one MEMS accelerometer vendor (reference-design partnership). Each: their
published work, the specific technical fit, a first joint milestone small
enough to say yes to. Agents keep dossiers current; humans meet.

### R4-T3 [SONNET] Continuity mechanics
License/copyright hygiene (per R7-T2's structure), release artifacts
mirrored (Zenodo DOI per release), CI runnable without personal-account
secrets, maintainer docs, GOVERNANCE.md stating what happens to the
evaluation tier if the company stops.

════════════════════════════════════════════════════════════════════════════
## PHASE R5 — Close R-05: market entry engine  [~2–3 weeks, then ongoing]
════════════════════════════════════════════════════════════════════════════

### R5-T1 [OPUS prep + HUMAN] Grant/scheme package
India routes for an industrial-IoT chip: DLI (Design-Linked Incentive)
scheme — REAL and structured (C-DAC is the nodal agency under MeitY/ISM;
5-year incentives, deployment incentive 6%→4% of net sales, ceiling ₹30 Cr;
RESEARCH_FINDINGS F-16) — **but the application window is currently CLOSED**
(DLI 1.0 ran Jan 2022–Dec 2024; the ism.gov.in portal shows "Application
Closed" as of 12.06.2026; DLI 2.0 is in redesign). So: **prepare the package
now, monitor for the DLI 2.0 relaunch, do not assume it is open.** Also
track C-DAC/MeitY MPW programs (India ran 5 domestic MPW runs in the past 12
months — SCL/C-DAC, feeds R-09) and state industrial-automation funds; iDEX
only if a defense-adjacent CM use-case appears. Technical volume auto-
assembled from the Evidence Book; kept perpetually current so any opening is
answerable inside a week. Human registers, submits, pitches when a window
opens.

### R5-T2 [SONNET] The pitch stack
From the R2-T2 recording + Evidence Book: 10-slide technical pitch
(OEM engineers), 6-slide business pitch, 2-page leave-behind, demo-day
runbook (hardware checklist + failure recovery — a stage-dead demo costs
more trust than no demo). All regenerate from source data.

### R5-T3 [SONNET] Pilot-program kit
`docs/business/PILOT.md`: 90-day evaluation — we provide FPGA node kit +
SDK + support SLA; they provide one machine class + labeled history if any;
success criteria (detection lead time, false-alarm rate, battery-model
validation); conversion path to Program tier. **Founder-adjacent first
pilot:** an Upcheck aquaculture pump/aerator deployment is a captive,
zero-negotiation pilot channel — treat it as pilot #0 and write it up with
the same rigor (real field hours for R-06).

════════════════════════════════════════════════════════════════════════════
## PHASE R6 — Shrink R-06: field-heritage ladder  [ongoing, months]
════════════════════════════════════════════════════════════════════════════

- **R6-T1 [SONNET] Rung 0 — soak evidence.** 30-day continuous FPGA soak
  (FPGA_PLAN F8): CM pipeline under periodic fault injection, uptime and
  fault-response stats auto-appended to the trust ledger weekly.
- **R6-T2 [OPUS prep + HUMAN] Rung 1 — real-machine hours.** Instrumented
  bench rig (a motor + deliberately damaged bearings is a <₹50k build;
  seeded-fault kits exist) logging detection performance on physical
  vibration, not datasets. Then pilot #0 (R5-T3) field hours.
- **R6-T3 [SONNET] Rung 2 — the logbook.** Machine-hours logbook format +
  node black-box firmware so every monitored hour on any partner machine is
  captured, signed, ledger-appended. Shadow-mode design (monitoring but not
  alarming into the CMMS) slashes partner risk — build it explicitly.
- **R6-T4 [HUMAN] Rung 3 — reference plant.** A named OEM/plant reference
  with quotable results. Agents maintain the case-study template; humans
  earn the logo.

════════════════════════════════════════════════════════════════════════════
## PHASE R7 — R-07/R-08/R-09/R-10: the professionalization batch
════════════════════════════════════════════════════════════════════════════

- **R7-T1 [OPUS] (R-07)** Energy-posture evidence is R2-T4; this task adds
  the silicon-measurement plan (what gets measured on first silicon, with
  which instruments, against which prediction) so the claim graduates from
  simulated to measured the week parts arrive.
- **R7-T2 [OPUS] (R-08) License structure.** Resolve the DECISION-007
  tension explicitly: recommended structure = evaluation artifacts +
  verification environment publicly reproducible (trust engine) while core
  RTL stays proprietary-licensed with an evaluation clause; alternatively
  dual-license a reduced core. Draft license texts + file manifest +
  trademark check on "Azmuth" (note: collides with common "azimuth"
  spelling — check registrability). **[HUMAN]:** lawyer review before any
  paid deal. Record outcome as a DECISION superseding/refining 007.
- **R7-T3 [OPUS] (R-09)** Execute TAPEOUT P7-T3 (SCL-180 porting study) to
  a synthesized-and-STA'd netlist on a public 180nm-representative library
  — "portable in principle" becomes a report with numbers.
- **R7-T4 [SONNET] (R-10)** Support credibility: issue templates with
  response targets, public roadmap, versioned `docs/ERRATA.md` (the BUGLOG
  discipline becomes marketing — professional vendors publish errata),
  security contact, SLA menu per offering tier.
- **R7-T5 [OPUS] (cert path)** `docs/CERT_GAP_ANALYSIS.md`: clause-by-
  clause self-assessment against IEC 61508-2/-3 objectives (SIL-2 target
  posture) for the interlock-adjacent upsell; satisfied/partial/gap with
  evidence links. **[HUMAN]:** one exploratory assessor quote.

---

# §D — STANDING RULES FOR THIS PLAN

1. Never modify any plan file.
2. Never mark a risk CLOSED without human confirmation in RISK_REGISTER.md.
3. Never let an agent send outreach, submit applications, or sign —
   prepare, then HUMAN-GATE.
4. Every externally visible number flows from a committed evidence
   artifact; the trust ledger is append-only and fully linked.
5. Publish losses too: a benchmark we lose or a gap we have goes in the
   document with a task ID, not in a drawer.
6. Demos reproducible by one command and rehearsed by runbook.
7. The register is reviewed monthly; a stale register is a CI failure.
