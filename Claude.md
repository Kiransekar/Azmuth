\`\`\`markdown

\# Xcew Processor - AI Execution Context (Granular RTL Spec)

\## Version: v1.0 | Target: 130nm CMOS | ISA: RV32IMC + Xcew

\## AI DIRECTIVE: You are an HDL engineering assistant. This file is the SINGLE SOURCE OF TRUTH. Generate Verilog-2001 ONLY. Follow phase order strictly. Do NOT deviate from port lists, control signals, timing targets, or coding standards. Generate ONE module per prompt. Validate with lint + sim + coverage BEFORE proceeding. Ask for clarification ONLY if a requirement violates RISC-V compliance or Yosys synthesis rules.

\---

\## 🔒 1. MODULE HIERARCHY & PORT MAPS (EXPLICIT)

| Module | Top-Level Ports (Name | Dir | Width | Protocol) | Purpose |

|--------|----------------------|-----|-------|-----------|---------|

| \`xcew\_top\` | \`i\_clk, i\_rst\` | I | 1 | Sync reset tree | Clock/reset distribution |

| | \`i\_inst\[31:0\], o\_inst\_req, o\_inst\_gnt\` | I/O | 32/1/1 | AXI4-Lite fetch | Instruction fetch from L1I |

| \`core/xcie\_decoder\` | \`i\_opcode\[6:0\], i\_funct3\[2:0\], i\_funct7\[6:0\], o\_is\_xcew, o\_xcew\_id\[3:0\], o\_illegal\` | I/O | Various | Combinational decode | Custom instruction decode |

| \`core/xcie\_csr\` | \`i\_clk, i\_rst, i\_rd\_addr\[11:0\], i\_wr\_en, i\_wr\_data\[31:0\], o\_rd\_data\[31:0\], o\_irq\_mask\[3:0\]\` | I/O | Various | CSR access protocol | 0x7C0-0x7FF register file |

| \`eml/eml\_unit\` | \`i\_clk, i\_rst, i\_rs1\[31:0\], i\_rs2\[31:0\], i\_cfg\[12:0\], i\_valid, o\_rd\[31:0\], o\_valid, o\_ready, o\_exc\` | I/O | 32/1 | Valid/Ready handshake | EML synthesis + memo cache |

| \`snn/snn\_tile\` | \`i\_clk\_snn, i\_rst, i\_spike\_in\[64:0\], i\_weight\_ptr\[15:0\], i\_classify\_en, o\_class\[7:0\], o\_conf\[7:0\], o\_done\` | I/O | 64/16/1/8/8/1 | Event-triggered | Digital SNN inference |

| \`nvm/nvm\_ctrl\` | \`i\_clk\_nvm, i\_rst, i\_addr\[15:0\], i\_wr\_en, i\_wr\_data\[31:0\], i\_rd\_en, o\_rd\_data\[31:0\], o\_busy, o\_ecc\_err\` | I/O | 16/1/32/1/32/1/1 | AXI4-Lite compliant | ReRAM KB controller |

\*\*Standard Widths:\*\* \`DATA\_W=32\`, \`ADDR\_W=12\` (4KB memo/NVM), \`STATE\_W=3\`, \`DEPTH\_W=3\`, \`PREC\_W=2\`

\---

\## 📐 2. INSTRUCTION MICROARCHITECTURE (CYCLE-ACCURATE)

| Cycle | \`eml\` | \`eml.cfg\` | \`mload\` | \`mstore\` | \`snn.class\` | \`pol.update\` |

|-------|-------|-----------|---------|----------|-------------|--------------|

| 1 | Decode + CSR read \`xcew\_cfg\` | Decode + write \`xcew\_cfg\` | Decode + address calc | Decode + address calc | Decode + DMA setup | Decode + NVM addr setup |

| 2 | Hash subtree → check memo | NOP | Cache lookup | Cache lookup | Load spike buffer | Load NVM read buffer |

| 3 | If hit: \`o\_valid=1\`, return | NOP | If hit: \`o\_valid=1\` | If hit: \`o\_valid=1\` | Spike encode → LIF1 | ECC decode |

| 4 | EXP approx (Stage 1) | NOP | NOP | NOP | LIF update → router | ALU delta calc |

| 5 | EXP approx (Stage 2) | NOP | NOP | NOP | LIF thresh check | NVM write buffer |

| 6 | LN approx (Stage 1) | NOP | NOP | NOP | IRQ setup if done | Write enable pulse |

| 7 | LN approx (Stage 2) | NOP | NOP | NOP | NOP | Write complete flag |

| 8 | SUB + complex rot | NOP | NOP | NOP | NOP | NOP |

| 9 | Round/Clamp + \`o\_valid=1\` | NOP | NOP | NOP | NOP | NOP |

\*\*Control Signal Truth Table (\`xcie\_ctrl.v\`):\*\*

| Signal | \`eml\` | \`eml.cfg\` | \`mload\` | \`mstore\` | \`snn.class\` | \`pol.update\` |

|--------|-------|-----------|---------|----------|-------------|--------------|

| \`ctrl\_decode\_valid\` | 1 | 1 | 1 | 1 | 1 | 1 |

| \`ctrl\_csr\_wr\` | 0 | 1 | 0 | 0 | 0 | 0 |

| \`ctrl\_eml\_valid\` | 1 | 0 | 0 | 0 | 0 | 0 |

| \`ctrl\_memo\_rd\` | 1 | 0 | 1 | 0 | 0 | 0 |

| \`ctrl\_memo\_wr\` | 0 | 0 | 0 | 1 | 0 | 0 |

| \`ctrl\_snn\_en\` | 0 | 0 | 0 | 0 | 1 | 0 |

| \`ctrl\_nvm\_wr\` | 0 | 0 | 0 | 0 | 0 | 1 |

| \`ctrl\_irq\_gen\` | 0 | 0 | 0 | 0 | 1 | 0 |

| \`ctrl\_exc\_gen\` | 0 | 0 | 0 | 0 | 0 | 0 |

\---

\## 🏗️ 3. TILE MICROARCHITECTURES (GRANULAR)

\### 3.1 EML Unit (\`eml/eml\_unit.v\`)

\- \*\*Pipeline Stages:\*\*

1\. \`ST\_FETCH\`: Decode \`rs1/rs2\`, compute hash, check \`memo\_cache\`

2\. \`ST\_EXP\`: 2-cycle CORDIC/LUT \`exp()\` approx (BF16/FP16)

3\. \`ST\_LN\`: 2-cycle CORDIC/LUT \`ln()\` approx

4\. \`ST\_SUB\`: \`exp - ln\`, complex rotation if \`cfg\[COMPLEX\]=1\`

5\. \`ST\_WB\`: Round/clamp, set flags, assert \`o\_valid\`

\- \*\*Memo Cache:\*\* 128-entry direct-mapped. Tag: \`hash\[7:0\]\`, Data: \`rd\[31:0\]\`, Valid: \`vbit\`. Hit latency: 2 cycles.

\- \*\*Depth Limiter:\*\* \`depth\_cnt\[2:0\]\` increments per tree level. If \`depth\_cnt > cfg\[MAX\_DEPTH\]\` → \`exc\_depth=1\`, flush pipeline.

\- \*\*Overflow/NaN:\*\* \`status\_reg\[1\] = overflow\`, \`status\_reg\[0\] = NaN\`. Sync to CSR \`xcew\_status\`.

\### 3.2 SNN Tile (\`snn/snn\_tile.v\`)

\- \*\*LIF Neuron Array:\*\* 256 cells. Each: \`v\_mem\[15:0\]\`, \`spike\_thresh\[7:0\]\`, \`leak\_rate\[7:0\]\`, \`reset\_val\[15:0\]\`.

\- \*\*Update Rule:\*\* \`v\_mem <= v\_mem + spike\_input - leak\_rate; if v\_mem >= spike\_thresh -> spike\_out=1, v\_mem=reset\_val; else spike\_out=0\`.

\- \*\*Spike Router:\*\* 8x8 priority crossbar. Event-driven. Routes \`spike\_in\[64:0\]\` → synaptic weight update buffer.

\- \*\*Controller FSM:\*\* \`IDLE → LOAD\_BUFFER → CLASSIFY → CHECK\_CONF → DONE\`. Latency: 5-15 cycles.

\- \*\*Learning:\*\* STDP proxy. If \`classify\_en=1\` && \`rs2≠0\` → apply \`Δw = lr \* (pre - post) \* spike\_corr\`.

\### 3.3 NVM Controller (\`nvm/nvm\_ctrl.v\`)

\- \*\*Address Map:\*\* \`0x8000\_0000 - 0x8000\_FFFF\` (64KB physical, 4KB windowed via CSR)

\- \*\*Wear-Leveling:\*\* Round-robin block pointer \`wear\_ptr\[9:0\]\`. Maps logical \`addr\[15:0\]\` → physical \`addr\[15:0\] ^ (wear\_ptr\[9:0\] << 6)\`.

\- \*\*ECC:\*\* Hamming(32,26). Parity bits stored in dedicated 64KB meta-array. Corrects single-bit, detects double-bit.

\- \*\*Write Buffer:\*\* 4-entry FIFO. Coalesces writes. Asserts \`o\_busy\` until drain.

\---

\## 🔄 4. CONTROL STATE MACHINES (EXPLICIT)

\### \`xcie\_ctrl.v\` FSM

| State | Next State (Condition) | Outputs |

|-------|------------------------|---------|

| \`IDLE\` | \`DECODE\` (\`i\_valid=1\`) | \`ctrl\_decode\_valid=0\` |

| \`DECODE\` | \`EXE\_EML\` (\`op==eml\`), \`EXE\_CFG\` (\`op==cfg\`), \`EXE\_MEMO\` (\`op==mload/mstore\`), \`EXE\_SNN\` (\`op==snn\`), \`EXE\_NVM\` (\`op==pol\`), \`TRAP\` (\`illegal\`) | Route to unit, assert \`ctrl\_\*\_valid\` |

| \`EXE\_EML\` | \`IDLE\` (\`eml.o\_valid=1\` OR \`eml.o\_exc=1\`) | \`ctrl\_eml\_valid=1\`, wait |

| \`EXE\_CFG\` | \`IDLE\` (1 cycle) | \`ctrl\_csr\_wr=1\`, clear |

| \`EXE\_MEMO\` | \`IDLE\` (\`memo\_hit=1\` OR \`memo\_miss=1\`) | \`ctrl\_memo\_rd/wr=1\` |

| \`EXE\_SNN\` | \`IDLE\` (\`snn.o\_done=1\`) | \`ctrl\_snn\_en=1\` |

| \`EXE\_NVM\` | \`IDLE\` (\`nvm.o\_busy=0\`) | \`ctrl\_nvm\_wr=1\` |

| \`TRAP\` | \`IDLE\` (\`mepc\_update=1\`) | \`ctrl\_exc\_gen=1\`, set \`mtval/mepc\` |

\---

\## 💾 5. MEMORY & CSR MAP (BIT-LEVEL)

\### \`xcew\_cfg\` (0x7C0)

| Bit | Field | Reset | Description |

|-----|-------|-------|-------------|

| 31-16 | RESERVED | 0 | Must read 0 |

| 15 | COMPLEX\_MODE | 0 | 0=real, 1=complex datapath |

| 14-12 | MAX\_DEPTH | 7 | Actual depth = field + 1 |

| 11-8 | PRECISION | 0 | 0=BF16, 1=FP16, 2=Q15.16, 3=reserved |

| 7 | BRANCH\_CUT | 0 | 0=trap, 1=clip to ±inf |

| 6-0 | RESERVED | 0 | Must read 0 |

\### \`xcew\_status\` (0x7C1, RO)

| Bit | Field | Description |

|-----|-------|-------------|

| 31-4 | PIPELINE\_STAGE | Current EML stage (0=IDLE, 1=EXP, 2=LN, 3=SUB, 4=WB) |

| 3 | IRQ\_PENDING | SNN/NVM/EML IRQ pending |

| 2 | NVM\_BUSY | Write buffer active |

| 1 | OVERFLOW | Last \`eml\` overflowed |

| 0 | NaN\_FLAG | Last \`eml\` produced NaN |

\---

\## 🔍 6. VERIFICATION & FORMAL PROPERTIES (SIGNAL-LEVEL)

\### SBY Assertions (\`eml/eml\_unit.sby\`)

\`\`\`verilog

property p\_depth\_safe; @(posedge clk) disable iff (rst) depth\_cnt <= xcew\_cfg\[14:12\]+1; endproperty

assert property (p\_depth\_safe);

property p\_overflow\_flag; @(posedge clk) disable iff (rst) (overflow\_detected) |=> (xcew\_status\[1\]==1); endproperty

assert property (p\_overflow\_flag);

property p\_memo\_hit\_latency; @(posedge clk) disable iff (rst) (cache\_hit) |-> (o\_valid ##\[1:2\] o\_ready); endproperty

assert property (p\_memo\_hit\_latency);

\`\`\`

\### Testbench Stimuli (\`tb/eml\_tb.v\`)

1\. \`eml(1.0, 1.0) → exp(1)-ln(1) = 2.71828\` (real)

2\. \`eml.cfg(12'b1000\_0000\_0000) → COMPLEX=1, DEPTH=5\`

3\. \`eml(0.5+0.5i, 1.0) → complex mode, verify Euler identity\`

4\. Depth limit test: \`cfg\[14:12\]=3\` → inject depth=5 → assert \`exc\_depth=1\`

5\. Memo hit/miss: store \`rd=0xDEADBEEF\` at \`hash=0x42\`, load → verify match

\### Coverage Targets

\- \*\*Line\*\*: 100%

\- \*\*Branch\*\*: >90%

\- \*\*FSM\*\*: All states + transitions covered

\- \*\*Signal\*\*: 100% toggle on \`ctrl\_\*\`, \`o\_valid\`, \`depth\_cnt\`, \`xcew\_status\`

\---

\## 🤖 7. AI GENERATION PROTOCOL (COPY-PASTE PROMPTS)

\### Phase 1: Core Decoder & CSR

\`\`\`

Generate \`rtl/core/xcie\_decoder.v\` and \`rtl/core/xcie\_csr.v\` per spec.

Ports: Exact match Section 1.

Logic: Decode table match Section 2. CSR bitfields match Section 5.

Include: \`tb/xcie\_core\_tb.v\` with directed decode + illegal trap tests.

Validate: Run \`make lint\` → zero warnings. Run \`make sim\_core\` → coverage >95%.

Output: \`✅ PHASE\_1\_LOCKED\` or \`❌ PHASE\_1\_RETRY: \`.

\`\`\`

\### Phase 2: EML Unit

\`\`\`

Generate \`rtl/eml/eml\_unit.v\` per spec.

Pipeline: 5 stages exact. Memo cache 128-entry direct-mapped. Depth limiter \`cfg\[14:12\]+1\`.

FSM: Match Section 3.1. Control signals match Section 2.

Include: \`tb/eml\_tb.v\`, \`sim/eml\_golden.py\`, \`sby/eml.sby\`.

Validate: Lint clean. Sim coverage >90%. Formal props pass. Match golden outputs ±1 LSB.

Output: \`✅ PHASE\_2\_LOCKED\` or \`❌ PHASE\_2\_RETRY: \`.

\`\`\`

\### Phase 3: SNN & NVM

\`\`\`

Generate \`rtl/snn/snn\_tile.v\` and \`rtl/nvm/nvm\_ctrl.v\` per spec.

LIF: Exact update rule. Wear-leveling XOR mapping. Hamming(32,26) ECC.

Include: \`tb/snn\_nvm\_tb.v\`, \`sim/snn\_golden.py\`, \`sby/nvm.sby\`.

Validate: Spike encode → classify → IRQ. NVM write/read → ECC correct. Coverage >90%.

Output: \`✅ PHASE\_3\_LOCKED\` or \`❌ PHASE\_3\_RETRY: \`.

\`\`\`

\### Phase 4: Top Integration

\`\`\`

Generate \`rtl/xcew\_top.v\`, \`syn/synth.tcl\`, \`syn/sdc.sdc\`, \`syn/upf.tcl\`.

Interconnect: AXI4-Lite to CSR/NVM, XCPI bridge to EML/SNN.

Constraints: Exact match Section 8. Power domains: 1.2V/0.9V/1.8V.

Include: \`tb/xcew\_top\_tb.v\` with full instruction stream.

Validate: STA pass (<4.0ns critical), area <18mm², power <2W peak.

Output: \`✅ PHASE\_4\_LOCKED\`.

\`\`\`

\---

\## ⚡ 8. SYNTHESIS & 130NM CONSTRAINTS (EXACT)

\### Yosys Flow (\`syn/synth.tcl\`)

\`\`\`tcl

read\_verilog -sv rtl/rtl\_list.f

hierarchy -top xcew\_top

proc; opt; memory; fsm

synth -top xcew\_top -flatten

dfflibmap -liberty syn/130nm\_std.lib

abc -liberty syn/130nm\_std.lib -constr syn/sdc.sdc -D 4.0

opt\_clean

write\_verilog -noattr -noexpr syn/xcew\_netlist.v

\`\`\`

\### SDC (\`syn/sdc.sdc\`)

\`\`\`tcl

create\_clock -name clk\_core -period 4.0 \[get\_ports i\_clk\]

create\_clock -name clk\_snn -period 8.0 \[get\_ports i\_clk\_snn\]

set\_clock\_uncertainty -setup 0.2 \[get\_clocks clk\_core clk\_snn\]

set\_input\_delay -clock clk\_core 1.0 \[all\_inputs\]

set\_output\_delay -clock clk\_core 1.0 \[all\_outputs\]

set\_max\_area 18000000

set\_max\_transition 0.5 \[get\_ports\]

set\_driving\_cell -liberty syn/130nm\_std.lib \[all\_inputs\]

set\_load -liberty syn/130nm\_std.lib \[all\_outputs\]

\`\`\`

\### UPF (\`syn/upf.tcl\`)

\`\`\`tcl

create\_supply\_domain PD\_CORE -default

create\_supply\_domain PD\_SNN

create\_supply\_domain PD\_NVM

create\_power\_switch SW\_CORE -domain PD\_CORE -control i\_core\_en

create\_power\_switch SW\_SNN -domain PD\_SNN -control i\_snn\_en

create\_power\_switch SW\_NVM -domain PD\_NVM -control i\_nvm\_en

\`\`\`

\---

\## ✅ LOCK CONFIRMATION & EXECUTION RULES

1\. This spec is \*\*granular, signal-level, and cycle-accurate\*\*. No ambiguity remains for RTL generation.

2\. AI MUST follow Phase 1 → 4 strictly. Do NOT skip validation.

3\. Every module requires: Verilog-2001 source, TB, golden model, SBY assertions, coverage report.

4\. Lint warnings = BLOCK. Coverage < targets = BLOCK. STA fail = BLOCK.

5\. Future versions (\`Xcew-v2/v3\`) inherit opcodes, CSR addresses, and port protocols. Only widths/features expand.