CROSS   = riscv64-unknown-elf
CC      = $(CROSS)-gcc
OBJCOPY = $(CROSS)-objcopy
OBJDUMP = $(CROSS)-objdump

# -march=rv32i  : base integer ISA only (no M/A/F/D)
# -mabi=ilp32   : 32-bit int/long/pointer, no FP registers
# -O1           : light optimisation (keeps all stores, removes dead code)
# -nostdlib     : no libc / startup from newlib
# -ffreestanding: do not assume standard library exists
CFLAGS  = -march=rv32i -mabi=ilp32 -O1 -nostdlib -ffreestanding -Wall

SRCS    = startup.S main.c
TARGET  = program

HELLO_SRCS = startup.S hello_uart.c
HELLO      = hello

all: $(TARGET).mem $(TARGET).dump
	@echo "Build complete → $(TARGET).mem ready for testbench"

hello: $(HELLO).mem $(HELLO).dump
	@echo "Build complete → $(HELLO).mem ready for FPGA"

$(TARGET).elf: $(SRCS) link.ld
	$(CC) $(CFLAGS) -T link.ld $(SRCS) -o $@

$(HELLO).elf: $(HELLO_SRCS) link.ld
	$(CC) $(CFLAGS) -T link.ld $(HELLO_SRCS) -o $@

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

# Byte-per-line for axi_slave_model (testbench)
$(TARGET).mem: $(TARGET).bin
	xxd -p -c 1 $< > $@

# Word-per-line (32-bit LE) for axi_bram (FPGA) — 4 byte-lane files
$(HELLO).mem: $(HELLO).bin
	xxd -p -c 4 $< | awk '{print substr($$1,1,2)}' > $(HELLO)0.mem
	xxd -p -c 4 $< | awk '{print substr($$1,3,2)}' > $(HELLO)1.mem
	xxd -p -c 4 $< | awk '{print substr($$1,5,2)}' > $(HELLO)2.mem
	xxd -p -c 4 $< | awk '{print substr($$1,7,2)}' > $(HELLO)3.mem
	@touch $@

%.dump: %.elf
	$(OBJDUMP) -d -M numeric $< > $@

clean:
	rm -f $(TARGET).elf $(TARGET).bin $(TARGET).mem $(TARGET).dump
	rm -f $(HELLO).elf $(HELLO).bin $(HELLO).mem $(HELLO).dump

.PHONY: all hello clean

FIBO_SRCS = startup.S fibonacci_uart.c
FIBO      = fibonacci

fibonacci: $(FIBO).mem $(FIBO).dump
	@echo "Build complete -> $(FIBO).mem ready for FPGA"

$(FIBO).elf: $(FIBO_SRCS) link.ld
	$(CC) $(CFLAGS) -T link.ld $(FIBO_SRCS) -o $@

$(FIBO).mem: $(FIBO).bin
	xxd -p -c 4 $< | awk '{print substr($$1,1,2)}' > hello0.mem
	xxd -p -c 4 $< | awk '{print substr($$1,3,2)}' > hello1.mem
	xxd -p -c 4 $< | awk '{print substr($$1,5,2)}' > hello2.mem
	xxd -p -c 4 $< | awk '{print substr($$1,7,2)}' > hello3.mem
	@touch $@
