# Makefile for bare-metal ARM64 test kernel
# Builds a minimal "kernel" that just prints to UART

CROSS_COMPILE ?= aarch64-linux-gnu-
AS = $(CROSS_COMPILE)as
LD = $(CROSS_COMPILE)ld
OBJCOPY = $(CROSS_COMPILE)objcopy

# Output file (named Image to match Linux kernel convention for booti)
TARGET = Image

# Source files
SRC = hello.S

# Intermediate files
OBJ = hello.o
ELF = hello.elf

# Build the Image file
all: $(TARGET)

$(OBJ): $(SRC)
	$(AS) -o $@ $<

$(ELF): $(OBJ)
	$(LD) -T linker.ld -o $@ $<

$(TARGET): $(ELF)
	$(OBJCOPY) -O binary $< $@
	@echo "Built test kernel: $(TARGET)"
	@ls -lh $(TARGET)

clean:
	rm -f $(OBJ) $(ELF) $(TARGET)

.PHONY: all clean
