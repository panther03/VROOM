# sw/apps/ folder
APP ?= hello

# Shared build folder for everything
BUILD_DIR = $(realpath .)/build

.DEFAULT_GOAL = sim

.PHONY: sim tests syn app clean

sim:
	@mkdir -p $(BUILD_DIR)/hw
	make -f hw.mk BUILD_DIR=$(BUILD_DIR)/hw BINARY_NAME=Sim
#	cp -r hw/mem/*.mem $(BUILD_DIR)/hw

syn:
	@mkdir -p $(BUILD_DIR)/hw
	make -f hw.mk BUILD_DIR=$(BUILD_DIR)/hw BINARY_NAME=TopCore verilog
#	cp -r hw/mem/*.mem $(BUILD_DIR)/hw

app: compiler
	@mkdir -p $(BUILD_DIR)/sw
	make -C sw/apps/$(APP)/ BUILD_DIR=$(BUILD_DIR)/sw/

tests:
	@mkdir -p $(BUILD_DIR)/sw/tests
	make -C sw/tests/ BUILD_DIR=$(BUILD_DIR)/sw/tests

clean:
	rm -rf build/