.PHONY: all clean

SRC_DIR=src

JKL_SOURCES=$(notdir $(wildcard $(SRC_DIR)/*.jkl))
ASM_SOURCES=$(notdir $(wildcard $(SRC_DIR)/*.S))
TESTS=$(basename $(JKL_SOURCES) $(ASM_SOURCES))
TESTS_BIN=$(addprefix $(BUILD_DIR)/,$(TESTS))
ROM=$(addsuffix .rom,$(TESTS_BIN))

JKLC=jkl.exe target=xr17032
XRASM=xrasm.exe target=xr17032
XRLINK=xrlink.exe

LDFLAGS=-move:text=0xFFFE0000,data=0x1000,bss=@data -bin 

all: $(ROM)

$(BUILD_DIR)/Init.o: Init.S
	$(XRASM) $^ $@

$(BUILD_DIR)/Util.o: Util.jkl
	$(JKLC) $^ $(BUILD_DIR)/temp.S
	$(XRASM) $(BUILD_DIR)/temp.S $@

$(BUILD_DIR)/%.rom: $(SRC_DIR)/%.jkl $(BUILD_DIR)/Init.o $(BUILD_DIR)/Util.o
	@mkdir -p $(BUILD_DIR)
	$(JKLC) incdir=$(realpath .)/ $(SRC_DIR)/$*.jkl $(BUILD_DIR)/temp.S
	$(XRASM) $(BUILD_DIR)/temp.S $(BUILD_DIR)/test.o
	$(XRLINK) link $@ $(BUILD_DIR)/Init.o $(BUILD_DIR)/Util.o $(BUILD_DIR)/test.o $(LDFLAGS)
	@rm $(BUILD_DIR)/test.o

$(BUILD_DIR)/%.rom: $(SRC_DIR)/%.S $(BUILD_DIR)/Init.o $(BUILD_DIR)/Util.o
	@mkdir -p $(BUILD_DIR)
	$(XRASM) $(SRC_DIR)/$*.S $(BUILD_DIR)/test.o
	$(XRLINK) link $@ $(BUILD_DIR)/Init.o $(BUILD_DIR)/Util.o $(BUILD_DIR)/test.o $(LDFLAGS)
	@rm $(BUILD_DIR)/test.o
