## UNINASOC
UNINASOC_DIR = $(SW_SOC_ROOT)/lib/uninasoc
UNINASOC_SRCS := $(wildcard $(UNINASOC_DIR)/src/*.c)
UNINASOC_OBJS := $(patsubst $(UNINASOC_DIR)/src/%.c, %.o, $(wildcard $(UNINASOC_DIR)/src/*.c))
UNINASOC_SRCS_DIR := $(UNINASOC_DIR)/src
UNINASOC_LIB := $(UNINASOC_DIR)/lib/libuninasoc.a
UNINASOC_INC := $(UNINASOC_DIR)/inc
TINY_IO := $(SW_SOC_ROOT)/lib/tinyio/inc

include $(SW_ROOT)/SoC/common/config.mk

all: $(UNINASOC_LIB)

# Build sources for devices
%.o: $(UNINASOC_SRCS_DIR)/%.c
	@echo "[CC] $<"
	$(CC) -c $< -o $@ -I$(UNINASOC_INC) -I$(TINY_IO) $(CFLAGS) $(MACRO_LIST)

# Build libuninasoc.a library
$(UNINASOC_LIB): $(UNINASOC_OBJS)
	@echo "\n[OBJ] Creating libuninasoc.a library"
	@mkdir -p lib
	ar rcs $(UNINASOC_LIB) $(UNINASOC_OBJS)
	@rm -f $(UNINASOC_OBJS)

clean:
	@rm $(UNINASOC_LIB)
