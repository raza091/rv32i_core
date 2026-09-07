#=============================================================================
# Makefile — RV32I Core
# Supports: iverilog/vvp/gtkwave (opensource) and Questa/Cadence (EDA)
# Author: Ali Raza Tariq
# Usage:
#   make                    -> compile + sim (iverilog, default)
#   make TOOL=questa        -> compile + sim (Questa/ModelSim)
#   make TOOL=xcelium       -> compile + sim (Cadence Xcelium)
#   make GUI=1              -> open waveform GUI after sim
#   make lint               -> lint with iverilog
#   make lint TOOL=hal      -> lint with Cadence HAL
#=============================================================================

#-----------------------------------------------------------------------------
# Tool selection — override on command line: make TOOL=questa
#-----------------------------------------------------------------------------
TOOL    ?= iverilog
GUI     ?= 0

#-----------------------------------------------------------------------------
# Directories
#-----------------------------------------------------------------------------
RTL_DIR = rtl
PKG_DIR = rtl/pkg
TB_DIR  = tb/directed
SIM_DIR = sim

#-----------------------------------------------------------------------------
# Source files
# PKG_FILES  — package/defines file compiled first
# RTL_FILES  — all RTL submodules (excluding pkg)
# CORE_TOP   — top level integration file
# TB_FILES   — testbench files
# ALL_SRCS   — complete ordered list for iverilog
#-----------------------------------------------------------------------------
PKG_FILES = $(PKG_DIR)/rv32i_pkg.v

RTL_FILES = $(wildcard $(RTL_DIR)/frontend/*.v)  \
            $(wildcard $(RTL_DIR)/decode/*.v)    \
            $(wildcard $(RTL_DIR)/execute/*.v)   \
            $(wildcard $(RTL_DIR)/memory/*.v)    \
            $(wildcard $(RTL_DIR)/writeback/*.v)

CORE_TOP  = $(RTL_DIR)/core_top.v

TB_FILES  = $(TB_DIR)/tb_core.v

# complete source list — order matters for iverilog
# pkg first, then RTL submodules, then top, then testbench
ALL_SRCS  = $(PKG_FILES) $(RTL_FILES) $(CORE_TOP) $(TB_FILES)

#-----------------------------------------------------------------------------
# Output files
#-----------------------------------------------------------------------------
SIM_BIN = $(SIM_DIR)/core_sim
VCD     = $(SIM_DIR)/core.vcd
LOG     = $(SIM_DIR)/sim.log

#-----------------------------------------------------------------------------
# ── TOOL: iverilog (open source) ─────────────────────────────────────────────
#-----------------------------------------------------------------------------
IVERILOG       = iverilog
VVP            = vvp
GTKWAVE        = gtkwave

# -Wall        : enable all warnings
# -Wno-timescale: suppress timescale warnings (we set it per file)
# -g2012       : enable SystemVerilog/Verilog-2012 features
# -I$(PKG_DIR) : include path so `include "rv32i_pkg.v" resolves
IVER_FLAGS     = -Wall -Wno-timescale -g2012
IVER_INC       = -I$(PKG_DIR)

#-----------------------------------------------------------------------------
# ── TOOL: Questa / ModelSim ───────────────────────────────────────────────────
#-----------------------------------------------------------------------------
VLOG           = vlog
VOPT           = vopt
VSIM           = vsim
QUESTA_LIB     = work
QUESTA_TOP     = tb_core
VLOG_FLAGS     = -svinputport=compat -incr -64 -nologo -quiet \
                 -suppress 2583 -suppress 13262 -suppress 2986 \
                 -suppress 2879 -suppress 3999
VOPT_FLAGS     = +acc +check_synthesis
VSIM_FLAGS     = -suppress 3999 -suppress 8885

#-----------------------------------------------------------------------------
# ── TOOL: Cadence Xcelium ────────────────────────────────────────────────────
#-----------------------------------------------------------------------------
XRUN           = xrun
XRUN_FLAGS     = -access +rwc -timescale 1ns/1ps \
                 -define XCELIUM -incdir $(PKG_DIR) \
                 -top tb_core -log $(LOG)
SIMVISION      = simvision

#-----------------------------------------------------------------------------
# ── TOOL: Cadence HAL (lint only) ────────────────────────────────────────────
#-----------------------------------------------------------------------------
HAL            = hal
HAL_FLAGS      = -sv -timescale 1ns/1ps -incdir $(PKG_DIR)

#-----------------------------------------------------------------------------
# Phony targets — not real files
#-----------------------------------------------------------------------------
.PHONY: all sim compile run wave lint clean help

#-----------------------------------------------------------------------------
# Default target
#-----------------------------------------------------------------------------
all: sim

sim: compile run

#=============================================================================
# ── OPEN SOURCE FLOW (iverilog + vvp + gtkwave) ──────────────────────────────
#=============================================================================
ifeq ($(TOOL),iverilog)

compile:
	@mkdir -p $(SIM_DIR)
	@echo "==> [iverilog] Compiling..."
	@$(IVERILOG) $(IVER_FLAGS) $(IVER_INC) \
	             -o $(SIM_BIN) $(ALL_SRCS)
	@echo "==> Compilation done."

run: compile
	@echo "==> [vvp] Running simulation..."
	@$(VVP) $(SIM_BIN) | tee $(LOG)

wave:
ifeq ($(GUI),1)
	@echo "==> [gtkwave] Opening waveform..."
	@$(GTKWAVE) $(VCD) &
else
	@echo "==> Run with GUI=1 to open GTKWave: make wave GUI=1"
endif

lint:
	@echo "==> [iverilog] Linting RTL..."
	@$(IVERILOG) $(IVER_FLAGS) $(IVER_INC) \
	             -t null $(PKG_FILES) $(RTL_FILES) $(CORE_TOP)
	@echo "==> Lint clean."

endif

#=============================================================================
# ── QUESTA / MODELSIM FLOW ───────────────────────────────────────────────────
#=============================================================================
ifeq ($(TOOL),questa)

compile:
	@mkdir -p $(SIM_DIR)
	@echo "==> [Questa] Creating library..."
	@vlib $(QUESTA_LIB)
	@echo "==> [Questa] Compiling packages first..."
	@$(VLOG) $(VLOG_FLAGS) -work $(QUESTA_LIB) \
	         +incdir+$(PKG_DIR) $(PKG_FILES)
	@echo "==> [Questa] Compiling RTL + TB..."
	@$(VLOG) $(VLOG_FLAGS) -timescale "1ns/1ps" \
	         -work $(QUESTA_LIB) -pedanticerrors \
	         +incdir+$(PKG_DIR) \
	         $(RTL_FILES) $(CORE_TOP) $(TB_FILES)
	@echo "==> [Questa] Optimising design..."
	@$(VOPT) $(VLOG_FLAGS) $(VOPT_FLAGS) \
	         -work $(QUESTA_LIB) $(QUESTA_TOP) \
	         -o $(QUESTA_TOP)_opt
	@echo "==> Compilation done."

run:
ifeq ($(GUI),1)
	@echo "==> [Questa GUI] Running simulation..."
	@$(VSIM) $(VSIM_FLAGS) -work $(QUESTA_LIB) \
	         $(QUESTA_TOP)_opt \
	         -do "add wave -r /*; run -all"
else
	@echo "==> [Questa batch] Running simulation..."
	@$(VSIM) -c $(VSIM_FLAGS) -work $(QUESTA_LIB) \
	         $(QUESTA_TOP)_opt \
	         -do "run -all; quit -f" | tee $(LOG)
endif

wave:
ifeq ($(GUI),1)
	@$(VSIM) $(VSIM_FLAGS) -work $(QUESTA_LIB) \
	         $(QUESTA_TOP)_opt \
	         -do "add wave -r /*; run -all"
else
	@echo "==> Run with GUI=1: make wave TOOL=questa GUI=1"
endif

lint:
	@echo "==> [Questa] Linting RTL..."
	@$(VLOG) $(VLOG_FLAGS) -lint +incdir+$(PKG_DIR) \
	         $(PKG_FILES) $(RTL_FILES) $(CORE_TOP)
	@echo "==> Lint done."

endif

#=============================================================================
# ── CADENCE XCELIUM FLOW ─────────────────────────────────────────────────────
#=============================================================================
ifeq ($(TOOL),xcelium)

compile:
	@mkdir -p $(SIM_DIR)
	@echo "==> [Xcelium] Compiling and elaborating..."
	@$(XRUN) $(XRUN_FLAGS) $(ALL_SRCS)
	@echo "==> Compilation done."

run:
ifeq ($(GUI),1)
	@echo "==> [SimVision] Running with GUI..."
	@$(XRUN) $(XRUN_FLAGS) -gui $(ALL_SRCS)
else
	@echo "==> [Xcelium batch] Running simulation..."
	@$(XRUN) $(XRUN_FLAGS) $(ALL_SRCS) | tee $(LOG)
endif

wave:
ifeq ($(GUI),1)
	@$(SIMVISION) $(SIM_DIR)/*.shm &
else
	@echo "==> Run with GUI=1: make wave TOOL=xcelium GUI=1"
endif

lint:
	@echo "==> [HAL] Linting RTL..."
	@$(HAL) $(HAL_FLAGS) $(PKG_FILES) $(RTL_FILES) $(CORE_TOP)
	@echo "==> Lint done."

endif

#=============================================================================
# ── COMMON TARGETS ───────────────────────────────────────────────────────────
#=============================================================================

# Remove all generated simulation files
clean:
	@echo "==> Cleaning..."
	@rm -rf $(SIM_DIR)/*.vcd \
	        $(SIM_DIR)/*.vvp \
	        $(SIM_DIR)/*.log \
	        $(SIM_BIN) \
	        work/ \
	        xcelium.d/ \
	        *.shm *.trn *.dsn \
	        transcript vsim.wlf
	@echo "==> Clean done."

# Print usage information
help:
	@echo ""
	@echo "RV32I Core Makefile"
	@echo "--------------------"
	@echo "Usage: make [target] [TOOL=<tool>] [GUI=1]"
	@echo ""
	@echo "TOOL options:"
	@echo "  iverilog   open source iverilog + vvp + gtkwave (default)"
	@echo "  questa     Questa / ModelSim (Mentor/Siemens)"
	@echo "  xcelium    Cadence Xcelium"
	@echo ""
	@echo "Targets:"
	@echo "  make                      compile + sim (iverilog)"
	@echo "  make TOOL=questa          compile + sim (Questa)"
	@echo "  make TOOL=xcelium         compile + sim (Xcelium)"
	@echo "  make wave GUI=1           open waveform after sim"
	@echo "  make lint                 lint with iverilog"
	@echo "  make lint TOOL=hal        lint with Cadence HAL"
	@echo "  make clean                remove all generated files"
	@echo "  make help                 show this message"
	@echo ""