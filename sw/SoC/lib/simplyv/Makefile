## SIMPLYV
SIMPLYV_DIR = $(SW_SOC_ROOT)/lib/simplyv
SIMPLYV_SRCS := $(wildcard $(SIMPLYV_DIR)/src/*.c)
SIMPLYV_OBJS := $(patsubst $(SIMPLYV_DIR)/src/%.c, %.o, $(wildcard $(SIMPLYV_DIR)/src/*.c))
SIMPLYV_SRCS_DIR := $(SIMPLYV_DIR)/src
SIMPLYV_LIB := $(SIMPLYV_DIR)/lib/libsimplyv.a
SIMPLYV_INC := $(SIMPLYV_DIR)/inc
TINY_IO := $(LIB_DIR)/tinyio/inc

include $(SW_ROOT)/SoC/common/config.mk

all: $(SIMPLYV_LIB)

# Build sources for devices
%.o: $(SIMPLYV_SRCS_DIR)/%.c
	@echo "[CC] $<"
	$(CC) -c $< -o $@ -I$(SIMPLYV_INC) -I$(TINY_IO) $(CFLAGS) $(MACRO_LIST)

# Build libsimplyv.a library
$(SIMPLYV_LIB): $(SIMPLYV_OBJS)
	@echo "\n[OBJ] Creating libsimplyv.a library"
	@mkdir -p lib
	$(AR) rcs $(SIMPLYV_LIB) $(SIMPLYV_OBJS)
	@rm -f $(SIMPLYV_OBJS)

dump: $(SIMPLYV_LIB)
	$(OBJDUMP) -d $^ > lib/libsimplyv.dump

clean:
	@rm -f $(SIMPLYV_LIB)
