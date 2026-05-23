<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# `flow/` — Consolidated flow entry points

One entry point per flow stage (tapeout audit §0.1). Each script is a thin
orchestrator over the `Makefile`; run from anywhere (each `cd`s to repo root).
No `v2`/`safe`/`optimized`/`robust`/`fast` script variants exist — those were
consolidated here and removed from the repo root (git history preserves them).

| Stage | Entry point | Wraps / replaces | Notes |
|-------|-------------|------------------|-------|
| Lint | `flow/lint.sh` | `make lint` + `verilog2001_compliance_check.sh`, `fast_syntax_check.sh` | Verilator → iverilog fallback + per-file syntax sweep |
| Simulate | `flow/sim.sh [target]` | `make sim_*` | No arg = full set; arg = one tb (`core`, `eml`, `soc`, `top`, `snn_tile_256`, `cosim`) |
| Synthesize | `flow/synth.sh [quick\|full]` | `make synth` / `make synth_full` | |
| Formal | `flow/formal.sh` | `make formal` | Requires SymbiYosys |
| PnR | `flow/pnr.sh` | `run_pnr_flow.sh`, `run_safe_pnr*.sh`, `robust_pnr_flow.sh`, `check_and_run_pnr.sh`, `run_openroad.sh` | Dockerized OpenROAD w/ resource limits + timeout; local fallback. Env: `PNR_TIMEOUT`, `PNR_CPUS`, `PNR_MEM` |
| Signoff | `flow/signoff.sh [v1.1\|postpr]` | `make signoff_v1.1` / `make signoff_postpr` | |
| Compliance | `flow/compliance.sh` | `verify_xcew_v1_1.sh` + `make check_csr_v1.1` | Claim re-verification; tool/file-absent → SKIP |

The seven dev-time monitor/tracker scripts (`monitor_*.sh`, `*_tracker.sh`,
`realtime_monitor.sh`, `progress_monitor.sh`, `final_status_report.sh`) were
removed; their function (watching a long PnR run) is covered by standard
`docker stats` / `tail -f logs/pnr.log` and is documented inline in `flow/pnr.sh`.
