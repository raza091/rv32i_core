# RV32I Pipelined Processor

A 5-stage pipelined RISC-V RV32I processor core written in Verilog.
Built from scratch following professional IC design conventions including
named port connections, active-low resets, _i/_o port suffixes, and
a central parameters package file.

---

## Architecture

```
       +------+   +------+   +------+   +------+   +------+
       |  IF  |-->|  ID  |-->|  EX  |-->| MEM  |-->|  WB  |
       +------+   +------+   +------+   +------+   +------+
           ^           |          |          |
           |     +-----v----------v----------v------+
           |     |         Hazard Unit              |
           |     |   (load-use stall, flush)        |
           +-----+----------------------------------+
                       |          |
                 +-----v----------v------+
                 |     Forwarding Unit   |
                 |  (EX->EX, MEM->EX)   |
                 +-----------------------+
```

### Pipeline Stages

| Stage | Modules | Function |
|-------|---------|----------|
| IF | fetch_unit, pc_reg, if_id_reg | Fetch instruction, compute PC+4 |
| ID | decoder, regfile, imm_gen, id_ex_reg | Decode instruction, read registers |
| EX | alu, branch_unit, forwarding_unit, ex_mem_reg | Execute, evaluate branch |
| MEM | lsu, mem_wb_reg | Load/store to data memory |
| WB | wb_stage | Write result back to register file |

### Hazard Handling

| Hazard | Detection | Resolution |
|--------|-----------|------------|
| Load-use data hazard | EX stage is load AND rd matches ID rs1/rs2 | Stall 1 cycle + bubble |
| RAW data hazard | EX/MEM rd matches current rs1/rs2 | Forwarding (no stall) |
| Control hazard | Branch or jump taken | Flush IF/ID stage |

---

## Simulation Results

Test program executed on the core:

```asm
ADDI x1, x0, 5      # x1 = 5
ADDI x2, x0, 10     # x2 = 10
ADD  x3, x1, x2     # x3 = x1 + x2 = 15
SW   x3, 0(x0)      # mem[0x0] = 15
LW   x4, 0(x0)      # x4 = mem[0x0] = 15
ADDI x5, x0, 1      # x5 = 1 (completion marker)
```

Results:

```
PASS: x1      = 0x00000005  (ADDI x1, x0, 5)
PASS: x2      = 0x0000000A  (ADDI x2, x0, 10)
PASS: x3      = 0x0000000F  (ADD  x3, x1, x2)
PASS: x4      = 0x0000000F  (LW   x4, 0(x0))
PASS: dmem[0] = 0x0000000F  (SW   x3, 0(x0))
```

---

## Directory Structure

```
rv32i_core/
├── rtl/
│   ├── pkg/
│   │   └── rv32i_pkg.v          # central parameters, opcodes, defines
│   ├── frontend/
│   │   ├── pc_reg.v             # program counter register
│   │   ├── fetch_unit.v         # instruction fetch + branch mux
│   │   └── if_id_reg.v          # IF/ID pipeline register
│   ├── decode/
│   │   ├── decoder.v            # full RV32I instruction decoder
│   │   ├── regfile.v            # 32x32 register file
│   │   ├── imm_gen.v            # immediate generator (I/S/B/U/J)
│   │   └── id_ex_reg.v          # ID/EX pipeline register
│   ├── execute/
│   │   ├── alu.v                # ALU - all RV32I integer operations
│   │   ├── branch_unit.v        # branch condition + target address
│   │   ├── forwarding_unit.v    # data hazard forwarding logic
│   │   ├── hazard_unit.v        # load-use stall + control flush
│   │   └── ex_mem_reg.v         # EX/MEM pipeline register
│   ├── memory/
│   │   ├── lsu.v                # load store unit + byte enables
│   │   └── mem_wb_reg.v         # MEM/WB pipeline register
│   ├── writeback/
│   │   └── wb_stage.v           # writeback mux (ALU/load/PC+4)
│   └── core_top.v               # top level - connects all stages
├── tb/
│   └── directed/
│       └── tb_core.v            # self-checking testbench
├── sim/                         # simulation output (gitignored)
├── syn/                         # synthesis scripts
├── doc/                         # documentation
├── Makefile                     # multi-tool build system
└── README.md
```

---

## Tools Supported

| Tool | Type | Command |
|------|------|---------|
| iverilog + vvp | Open source | `make` |
| GTKWave | Open source waveform | `make wave GUI=1` |
| Questa / ModelSim | EDA simulation | `make TOOL=questa` |
| Cadence Xcelium | EDA simulation | `make TOOL=xcelium` |
| Cadence HAL | Lint | `make lint TOOL=hal` |

---

## Usage

```bash
# Clone
git clone https://github.com/raza091/rv32i_core.git
cd rv32i_core

# Compile and simulate (open source)
make

# Open waveform in GTKWave
make wave GUI=1

# Simulate with Questa
make TOOL=questa

# Simulate with Questa + GUI waveform
make TOOL=questa GUI=1

# Simulate with Cadence Xcelium
make TOOL=xcelium

# Lint RTL only
make lint

# Remove generated files
make clean
```

---

## Coding Conventions

| Convention | Meaning |
|------------|---------|
| `_i` suffix | input port |
| `_o` suffix | output port |
| `_ni` suffix | active low input |
| `_q` suffix | registered signal (flip-flop output) |
| `_d` suffix | combinational next value |
| `u_` prefix | module instance name |

---

## Supported Instructions

| Type | Instructions |
|------|-------------|
| R-type | ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU |
| I-type | ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI, SLTIU |
| Load | LB, LH, LW, LBU, LHU |
| Store | SB, SH, SW |
| Branch | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| Jump | JAL, JALR |
| Upper | LUI, AUIPC |
| Fence | FENCE (treated as NOP) |

---

## Author

**Ali Raza Tariq**  
Engineer and Researcher — Pakistan  
GoP IC Design and Verification Cohort 1 — GIKI / Inspire / NECOP  
GitHub: [github.com/raza091](https://github.com/raza091)
