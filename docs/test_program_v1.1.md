# Xcew Processor v1.1 - Test Program
# ============================================================================
# Document: docs/test_program_v1.1.md
# Version: v1.1 (Final Integration)
# Target: Post-silicon bring-up and manufacturing validation
# Date: 2026-04-25
# ============================================================================

## 1. Test Flow Overview

```
Power-On Reset
    |
    +-- [TEST-01] Power Supply Validation
    |       Verify all domains at nominal voltage
    |
    +-- [TEST-02] JTAG Chain Test
    |       IDCODE read, boundary scan, BYPASS
    |
    +-- [TEST-03] Scan Chain Test
    |       At-speed scan, transition fault, stuck-at
    |
    +-- [TEST-04] BIST Memory Test
    |       Boot ROM, SRAM, NVM, EML memo cache
    |
    +-- [TEST-05] Firmware Boot Test
    |       Load ELF via JTAG, execute, verify UART output
    |
    +-- [TEST-06] Functional Validation
    |       EML math, SNN classify, NVM read/write
    |
    +-- [TEST-07] Security Validation
    |       Constant-time, fault injection, determinism
    |
    +-- [TEST-08] Power Domain Test
    |       Sleep/wake transitions, retention, leakage
    |
    +-- [TEST-09] Body Bias Calibration
    |       Leakage sweep, optimal bias code
    |
    +-- [TEST-10] Co-simulation Correlation
    |       RTL vs silicon timing within +/-15%
    |
    PASS/FAIL Summary
```

## 2. Test Sequences

### TEST-01: Power Supply Validation

**Purpose**: Verify all power domains reach nominal voltage
**Equipment**: Multimeter, oscilloscope, programmable power supply

| Step | Action | Expected | Pass Criteria |
|------|--------|----------|---------------|
| 1 | Apply VDD_CORE=1.2V | PD_CORE active | VDD_CORE within 1.14-1.26V |
| 2 | Apply VDD_SNN=0.9V | PD_SNN active | VDD_SNN within 0.855-0.945V |
| 3 | Apply VDD_NVM=1.8V | PD_NVM active | VDD_NVM within 1.71-1.89V |
| 4 | Measure idle current | Quiescent current | I_CORE<50mA, I_SNN<20mA, I_NVM<30mA |
| 5 | Assert i_rst=1 for 100ns | All FFs reset | All outputs to known state |

### TEST-02: JTAG Chain Test

**Purpose**: Verify JTAG TAP controller and scan chain
**Equipment**: JTAG programmer (e.g., Xilinx Platform Cable)

| Step | Action | Expected | Pass Criteria |
|------|--------|----------|---------------|
| 1 | Read IDCODE register | Device ID | ID matches 0x____ (TBD at tapeout) |
| 2 | Shift TEST pattern through BYPASS | All 1s | BYPASS register = 1 |
| 3 | Load EXTEST instruction | Boundary scan mode | EXTEST loaded |
| 4 | Apply EXTEST pattern | All I/O sampled | No stuck I/O pins |
| 5 | Shift full scan chain | Pattern received | Chain length = expected |

### TEST-03: Scan Chain Test

**Purpose**: Verify scan chain functionality and at-speed testing
**Equipment**: JTAG programmer, pattern generator

| Step | Action | Expected | Pass Criteria |
|------|--------|----------|---------------|
| 1 | Load SHIFT_DR, capture scan chain | Full chain readable | No shift failures |
| 2 | Load EXTEST, apply stuck-at patterns | All FFs testable | Stuck-at coverage >98% |
| 3 | Run at-speed transition test | Clock edge captured | Transition faults <2% |
| 4 | Run at-speed path delay test | Critical paths verified | Path delay <4.0ns (CORE), <8.0ns (SNN) |

### TEST-04: BIST Memory Test

**Purpose**: Test all embedded memories
**Equipment**: JTAG programmer, BIST controller

| Step | Action | Memory | Expected |
|------|--------|--------|----------|
| 1 | Run March C+ | Boot ROM (1024 words) | All words = programmed values |
| 2 | Run March C+ | SRAM (4096 words) | No failures |
| 3 | Run March C+ | NVM (65536 words) | No failures |
| 4 | Run March C+ | EML memo cache (128 entries) | No failures |
| 5 | Run March C+ | EML DAG cache (256 entries) | No failures |
| 6 | Run March C+ | SNN neuron array (8 cells) | No failures |

### TEST-05: Firmware Boot Test

**Purpose**: Verify firmware loads and executes correctly
**Equipment**: JTAG programmer, UART receiver

| Step | Action | Expected | Pass Criteria |
|------|--------|----------|---------------|
| 1 | Load firmware.elf to Boot ROM | Program stored | Checksum match |
| 2 | Deassert i_rst | Core begins execution | First instruction at PC=0x0000 |
| 3 | Monitor UART output | "EML test: PASS/FAIL" | Byte 0x01 = EML pass |
| 4 | Monitor UART output | "SNN test: PASS/FAIL" | Byte 0x02 = SNN pass |
| 5 | Check final marker | UART 0xFF end marker | Received within 10ms |

### TEST-06: Functional Validation

**Purpose**: Verify all custom instructions produce correct results
**Equipment**: Firmware co-simulation harness

#### EML Unit Tests
| Test | Input | Expected Output | Pass Criteria |
|------|-------|-----------------|---------------|
| exp(1) - ln(1) | rs1=0x3F800000, rs2=0x3F800000 | ~0x402DF854 | Within +/-1 LSB |
| exp(2) - ln(1) | rs1=0x40000000, rs2=0x3F800000 | ~0x404DF854 | Within +/-1 LSB |
| Complex mode | cfg[15]=1, rs1=0x40000000 | Euler identity | Real/Imag within tolerance |
| Depth limit | cfg[14:12]=2, deep tree | exc_depth=1 | Exception raised |
| Memo hit | Store then load same input | Cached result | Hit latency <=2 cycles |
| DAG reuse | Repeated subtree (v1.1) | Cached DAG node | 2x+ reuse achieved |

#### SNN Unit Tests
| Test | Input | Expected | Pass Criteria |
|------|-------|----------|---------------|
| Basic classify | spike_in=0xDEADBEEF_FEDCBA98 | classification + confidence | Matches golden model |
| TTFS mode (v1.1) | RF waveform input | TTFS spike train | Energy reduction >40% |
| STDP learning (v1.1) | Spike pairs with varying delta_t | Weight updates | Within [-127, +127] |
| Accuracy check | RadioML subset | Classification accuracy | >95% |

#### NVM Unit Tests
| Test | Input | Expected | Pass Criteria |
|------|-------|----------|---------------|
| Write/read | addr=0x0010, data=0xCAFE_BABE | Read returns 0xCAFE_BABE | Data match |
| ECC single-bit | Inject 1-bit error | Corrected data | Single-bit fixed |
| ECC double-bit | Inject 2-bit error | Error flagged | ecc_err=1 |
| Wear leveling | Write same addr 1000x | Physical addr changes | wear_ptr increments |

### TEST-07: Security Validation

**Purpose**: Verify v1.1 security features function correctly

#### Constant-Time Execution
| Step | Action | Expected | Pass Criteria |
|------|--------|----------|---------------|
| 1 | Set sec_ctrl.CONST_TIME_EN=1 | Constant-time mode | |
| 2 | Execute exp() with different inputs | Same cycle count | Cycle variance = 0 |
| 3 | Execute ln() with different inputs | Same cycle count | Cycle variance = 0 |
| 4 | Execute exp()-ln() with different inputs | Same cycle count | Cycle variance = 0 |

#### Fault Monitoring
| Step | Action | Expected | Pass Criteria |
|------|--------|----------|---------------|
| 1 | Disable all tiles for >watchdog_timeout | Watchdog trip | fault_status.WATCHDOG_TRIP=1 |
| 2 | Inject ECC error | Single-bit correction | fault_status.ERROR_CODE=0x2 |
| 3 | Inject double-bit ECC error | Error flagged | fault_status.ECC_ERR=1 |
| 4 | Trigger fault | Pipeline halt | pipeline_halt=1, IRQ asserted |

#### Deterministic Policy Execution
| Step | Action | Expected | Pass Criteria |
|------|--------|----------|---------------|
| 1 | Set pol_sec.DETERM_EN=1, MAX_CYCLES=12 | Deterministic mode | |
| 2 | Execute policy operation | Fixed cycle execution | Exactly 12 cycles |
| 3 | Execute long-running operation | Timeout IRQ | timeout_irq=1 |

### TEST-08: Power Domain Test

**Purpose**: Verify power orchestration and sleep/wake transitions

| Step | Action | Expected | Pass Criteria |
|------|--------|----------|---------------|
| 1 | Set pwr_ctrl.idle_timeout=10, idle EML tile | EML enters sleep | tile_sleep[1]=1, clock gated |
| 2 | Trigger wake via IRQ | EML resumes | tile_sleep[1]=0 within 5 cycles |
| 3 | Set pwr_ctrl.idle_timeout=10, idle SNN tile | SNN enters sleep | tile_sleep[2]=1 |
| 4 | Trigger wake via IRQ | SNN resumes | tile_sleep[2]=0 within 5 cycles |
| 5 | Put NVM in retention | State preserved | Read after restore matches |
| 6 | Measure sleep current | Leakage reduction | I_sleep < 10% I_active |
| 7 | Measure wake latency | Time to active | EML/SNN < 10 cycles, NVM < 15 cycles |

### TEST-09: Body Bias Calibration

**Purpose**: Calibrate optimal body bias for leakage minimization

| Step | Action | Expected | Pass Criteria |
|------|--------|----------|---------------|
| 1 | Write bias_ctrl.BIAS_CODE=0x80, CAL_EN=1 | Calibration starts | |
| 2 | Wait for LEAKAGE_RDY=1 | Sweep complete | <1ms calibration time |
| 3 | Read optimized BIAS_CODE | Optimal bias code | Code in [0x40, 0xC0] |
| 4 | Measure leakage current | Leakage minimized | < target leakage |
| 5 | Apply bias to pb_bias_out/nb_bias_out | Physical bias applied | DAC outputs valid |

### TEST-10: Co-simulation Correlation

**Purpose**: Correlate silicon behavior with RTL simulation

| Step | Action | Expected | Pass Criteria |
|------|--------|----------|---------------|
| 1 | Run OODA benchmark on silicon | OODA latency measured | <= 8ms |
| 2 | Run same benchmark in RTL co-sim | RTL OODA latency | Within +/-15% of silicon |
| 3 | Measure silicon power | Power consumption | <= 1.75W peak |
| 4 | Compare EML results | Silicon vs golden | All results match |
| 5 | Compare SNN results | Silicon vs golden | Accuracy within 2% |

## 3. Pass/Fail Criteria

| Test Category | Pass Criteria |
|--------------|---------------|
| Power | All voltages within spec, currents nominal |
| JTAG | IDCODE match, scan chain complete |
| DFT | Scan coverage >95%, BIST zero failures |
| Firmware | Boot sequence complete, UART markers correct |
| EML | All math results within +/-1 LSB of golden |
| SNN | Classification accuracy >95% vs golden |
| NVM | Read/write match, ECC correct |
| Security | Constant-time (0 variance), fault detection 100% |
| Power | Sleep current <10% active, wake latency met |
| Co-sim | Silicon within +/-15% of simulation |

## 4. Backward Compatibility Test (v1_1_mode=0)

| Step | Action | Expected | Pass Criteria |
|------|--------|----------|---------------|
| 1 | Set v1_1_mode=0 | Only v1.0 features active | |
| 2 | Load v1.0 firmware | Unmodified firmware boots | Same as v1.0 silicon |
| 3 | Execute EML instruction | exp()-ln() correct | Results match v1.0 |
| 4 | Execute SNN classify | Classification works | Results match v1.0 |
| 5 | Read/write NVM | Operations work | Results match v1.0 |
| 6 | Read v1.1 CSRs | Read 0x0 | 0x7C5-0x7CC return 0 |
| 7 | Write v1.1 CSRs | Writes ignored | Values unchanged |
