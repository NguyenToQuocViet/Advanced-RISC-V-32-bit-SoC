# Build dispatcher for legacy5, fpga7, asap7, and sky130 profiles.

TARGET      ?= fpga7
TEST        ?= soc7
VERILATOR   ?= verilator
VIVADO      ?= vivado
LIBRELANE   ?= librelane
VFLAGS      ?= --binary --timing -Wall -Wno-fatal
FILELIST     = filelists/$(TARGET).f
OBJ_DIR      = build/verilator/$(TARGET)/$(TEST)

VALID_TARGETS := legacy5 fpga7 asap7 sky130

TEST_TOP_dbp_sram  := dbp_7stg_1r1w_sram_tb
TEST_FILE_dbp_sram := tb/unit/dbp_7stg_1r1w_sram_tb.sv
TEST_PASS_dbp_sram := DBP_7STG_TB PASS
TEST_TOP_dbp_asap7  := dbp_7stg_asap7_tb
TEST_FILE_dbp_asap7 := tb/unit/dbp_7stg_asap7_tb.sv
TEST_PASS_dbp_asap7 := DBP_7STG_TB PASS
TEST_TOP_dcache  := dcache_7stg_tb
TEST_FILE_dcache := tb/unit/dcache_7stg_tb.sv
TEST_PASS_dcache := DCACHE_7STG_TB PASS
TEST_TOP_axi_default_error   := axi_default_error_tb
TEST_FILE_axi_default_error  := tb/unit/axi_default_error_tb.sv
TEST_EXTRA_axi_default_error := rtl/soc/interconnect/axi_default_error.sv
TEST_PASS_axi_default_error  := SUMMARY | PASS=6 FAIL=0
TEST_TOP_axi_read_router   := axi_read_router_tb
TEST_FILE_axi_read_router  := tb/unit/axi_read_router_tb.sv
TEST_EXTRA_axi_read_router := rtl/soc/interconnect/soc_addr_map_pkg.sv \
	rtl/soc/interconnect/soc_addr_decode.sv \
	rtl/soc/interconnect/axi_read_router.sv
TEST_PASS_axi_read_router  := SUMMARY | PASS=7 FAIL=0
TEST_TOP_axi_write_router   := axi_write_router_tb
TEST_FILE_axi_write_router  := tb/unit/axi_write_router_tb.sv
TEST_EXTRA_axi_write_router := rtl/soc/interconnect/soc_addr_map_pkg.sv \
	rtl/soc/interconnect/soc_addr_decode.sv \
	rtl/soc/interconnect/axi_write_router.sv
TEST_PASS_axi_write_router  := SUMMARY | PASS=7 FAIL=0
TEST_TOP_fetch  := fetch_path_7stg_tb
TEST_FILE_fetch := tb/integration/fetch_path_7stg_tb.sv
TEST_PASS_fetch := FETCH_PATH_7STG_TB PASS
TEST_TOP_mem7  := mem_path_7stg_tb
TEST_FILE_mem7 := tb/integration/mem_path_7stg_tb.sv
TEST_PASS_mem7 := MEM_PATH_7STG_TB PASS
TEST_TOP_cache7  := cache_subsystem_7stg_tb
TEST_FILE_cache7 := tb/integration/cache_subsystem_7stg_tb.sv
TEST_EXTRA_cache7 := tb/models/axi_slave_model.sv
TEST_PASS_cache7 := CACHE_SUBSYSTEM_7STG_TB PASS
TEST_TOP_core7  := rv32ui_core_7stg_tb
TEST_FILE_core7 := tb/riscv_test/rv32ui_core_7stg_tb.sv
TEST_PASS_core7 := CORE-7STG SUMMARY: 38 PASS | 0 FAIL | 0 TIMEOUT
TEST_TOP_soc7  := rv32ui_soc_7stg_tb
TEST_FILE_soc7 := tb/riscv_test/rv32ui_soc_7stg_tb.sv
TEST_EXTRA_soc7 := tb/models/axi_slave_model.sv
TEST_PASS_soc7 := SOC-7STG SUMMARY: 38 PASS | 0 FAIL | 0 TIMEOUT
TEST_TOP_soc5  := rv32ui_tb
TEST_FILE_soc5 := tb/riscv_test/rv32ui_tb.sv
TEST_EXTRA_soc5 := tb/models/axi_slave_model.sv
TEST_PASS_soc5 := SUMMARY: 38 PASS | 0 FAIL | 0 TIMEOUT

TB_TOP   = $(TEST_TOP_$(TEST))
TB_FILE  = $(TEST_FILE_$(TEST))
TB_EXTRA = $(TEST_EXTRA_$(TEST))
PASS_MARKER = $(TEST_PASS_$(TEST))

REGRESSION_legacy5 := soc5
REGRESSION_fpga7   := axi_read_router axi_write_router dbp_sram dcache fetch core7 soc7
REGRESSION_asap7   := axi_read_router axi_write_router dbp_asap7 dcache fetch core7 soc7
REGRESSION_sky130  := axi_read_router axi_write_router dbp_sram dcache fetch core7 soc7
REGRESSION_TESTS    = $(REGRESSION_$(TARGET))

.PHONY: all check-target lint test regression regression-all synth librelane-config librelane-synth clean help

all: regression

check-target:
	@if ! echo "$(VALID_TARGETS)" | grep -qw "$(TARGET)"; then \
		echo "Unsupported TARGET=$(TARGET); choose: $(VALID_TARGETS)"; exit 2; \
	fi
	@test -f "$(FILELIST)"

lint: check-target
	$(VERILATOR) --lint-only --timing -Wall -Wno-fatal -f $(FILELIST)

test: check-target
	@if test -z "$(TB_TOP)"; then echo "Unknown TEST=$(TEST)"; exit 2; fi
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS) --top-module $(TB_TOP) --Mdir $(OBJ_DIR) \
		-f $(FILELIST) $(TB_EXTRA) $(TB_FILE)
	./$(OBJ_DIR)/V$(TB_TOP) | tee $(OBJ_DIR)/run.log
	@grep -Fq "$(PASS_MARKER)" $(OBJ_DIR)/run.log

regression: check-target
	@set -e; for test_name in $(REGRESSION_TESTS); do \
		$(MAKE) --no-print-directory test TARGET=$(TARGET) TEST=$$test_name; \
	done

regression-all:
	@set -e; for target_name in $(VALID_TARGETS); do \
		$(MAKE) --no-print-directory regression TARGET=$$target_name; \
	done

synth: check-target
	@if test "$(TARGET)" = "asap7" -o "$(TARGET)" = "sky130"; then \
		echo "ASIC targets require their platform synthesis flow; Vivado only supports legacy5/fpga7."; exit 2; \
	fi
	$(VIVADO) -mode batch -source flow/vivado/tcl/synth_filelist.tcl \
		-tclargs $(TARGET)

librelane-config:
	python3 flow/librelane/sky130/prepare_config.py

librelane-synth: librelane-config
	$(LIBRELANE) --dockerized --pdk sky130A --to OpenROAD.CheckMacroInstances build/librelane/sky130/config.json

clean:
	rm -rf build

help:
	@echo "make regression [TARGET=legacy5|fpga7|asap7|sky130]"
	@echo "make test TARGET=<target> TEST=<test>"
	@echo "make regression-all"
	@echo "make lint TARGET=<target>"
	@echo "make synth TARGET=legacy5|fpga7"
	@echo "make librelane-synth"
