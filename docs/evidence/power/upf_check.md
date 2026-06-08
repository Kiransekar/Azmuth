<!-- SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary -->
# UPF / Power Intent Reconciliation Report

**Audit reference:** Tapeout §3.6
**Date:** 2026-06-06
**UPF source:** `syn/upf_v1.1_final.tcl`

## Power Domains

| UPF Domain | RTL Coverage | Always-on? | Notes |
|------------|-------------|------------|-------|
| PD_TOP | `xcew_top_v1_1` top-level | Yes | Primary supply |
| PD_CORE | `riscv_core`, `xcie_csr`, `xcie_ctrl`, `policy_determinism` | Switchable | Core pipeline |
| PD_EML | `eml_unit`, `eml_dag_cache`, `eml_constant_time` | Switchable | EML accelerator |
| PD_SNN | `snn_tile_256`, `lif_ttfs_neuron_v1_1`, `stdp_engine_v1_1` | Switchable | SNN classifier |
| PD_NVM | `nvm_ctrl` | Switchable | NVM controller |

## Power Switches

| UPF Switch | Controls | RTL Signal | Verified |
|------------|----------|-----------|----------|
| SW_CORE | PD_CORE | `orchestrator.tile_sleep[0]` | ✓ RTL drives switch enable |
| SW_EML | PD_EML | `orchestrator.tile_sleep[1]` | ✓ RTL drives switch enable |
| SW_SNN | PD_SNN | `orchestrator.tile_sleep[2]` | ✓ RTL drives switch enable |
| SW_NVM | PD_NVM | `orchestrator.tile_sleep[3]` | ✓ RTL drives switch enable |

## Isolation Cells

| UPF Isolation | Cross-domain Signal | RTL Site | Control | Verified |
|---------------|-------------------|----------|---------|----------|
| ISO_CORE_TO_AXI | Core AXI master signals | `xcew_top_v1_1.v` | `tile_iso_en[0]` | ✓ |
| ISO_EML_TO_TOP | EML result/valid/ready | `xcew_top_v1_1.v` | `tile_iso_en[1]` | ✓ |
| ISO_SNN_TO_TOP | SNN class/done/ready | `xcew_top_v1_1.v` | `tile_iso_en[2]` | ✓ |
| ISO_NVM_TO_TOP | NVM data/busy | `xcew_top_v1_1.v` | `tile_iso_en[3]` | ✓ |
| ISO_TOP_TO_EML | Config/enable signals | `xcew_top_v1_1.v` | `tile_iso_en[1]` | ✓ |
| ISO_TOP_TO_SNN | Input current/classify_en | `xcew_top_v1_1.v` | `tile_iso_en[2]` | ✓ |
| ISO_TOP_TO_NVM | Address/data/write_en | `xcew_top_v1_1.v` | `tile_iso_en[3]` | ✓ |

## Retention Registers

| UPF Retention | RTL Module | Save/Restore Signal | Verified |
|---------------|-----------|---------------------|----------|
| RET_CORE | `retention_reg` (core) | `tile_ret_en[0]` | ✓ |
| RET_EML | `retention_reg` (eml) | `tile_ret_en[1]` | ✓ |
| RET_SNN | `retention_reg` (snn) | `tile_ret_en[2]` | ✓ |
| RET_NVM | `retention_reg` (nvm) | `tile_ret_en[3]` | ✓ |

## Level Shifters

| UPF Level Shifter | Boundary | Direction | Verified |
|--------------------|----------|-----------|----------|
| LS_CORE | PD_TOP ↔ PD_CORE | Bidirectional | ✓ present in UPF |
| LS_EML | PD_TOP ↔ PD_EML | Bidirectional | ✓ |
| LS_SNN | PD_TOP ↔ PD_SNN | Bidirectional | ✓ |
| LS_NVM | PD_TOP ↔ PD_NVM | Bidirectional | ✓ |

## Consistency Check Summary

| Check | Result |
|-------|--------|
| Every UPF isolation cell maps to RTL cross-domain signal | ✓ PASS |
| Every UPF retention register maps to `retention_reg.v` instantiation | ✓ PASS |
| Every UPF level shifter at a real voltage boundary | ✓ PASS |
| Every UPF power switch controlled by `orchestrator` output | ✓ PASS |
| Formal property (power_fv.sv) confirms sleep↔iso↔ret relationship | ✓ Properties P1–P5 |

## Notes

- **PD_DEBUG** (for Debug Module, per DECISION-004 §3.5.9) is not yet in the
  UPF — will be added when Debug Module RTL lands.
- Clock gating cells are expected at each switchable domain's clock input;
  the gated clocks (`clk_eml_gated`, etc.) are generated in `xcew_top_v1_1.v`.
