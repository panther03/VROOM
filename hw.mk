BSC_FLAGS=--aggressive-conditions -show-range-conflict --show-schedule -p +:hw/:hw/core:hw/mem:hw/top:hw/tb:hw/util -vdir $(BUILD_DIR) -bdir $(BUILD_DIR) -simdir $(BUILD_DIR) -info-dir $(BUILD_DIR) -o 
BSV_FILES=$(shell find hw -name "*.bsv" -type f)

$(BUILD_DIR)/$(BINARY_NAME): $(BUILD_DIR) $(BSV_FILES)
	mkdir -p $(BUILD_DIR)
	bsc $(DEFINES) $(BSC_FLAGS) $@ -sim -g mk$(BINARY_NAME) -u ./hw/tb/$(BINARY_NAME).bsv
	bsc $(DEFINES) $(BSC_FLAGS) $@ -parallel-sim-link $(shell nproc) -sim -e mk$(BINARY_NAME)

verilog: $(BUILD_DIR)/$(BINARY_NAME).v
$(BUILD_DIR)/$(BINARY_NAME).v: $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	bsc -remove-dollar $(DEFINES) -D SYNTHESIS $(BSC_FLAGS) $(BINARY_NAME) -verilog -g mk$(BINARY_NAME) -u ./hw/core/$(BINARY_NAME).bsv

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)