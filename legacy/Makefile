NASM ?= nasm
QEMU ?= qemu-system-i386

BUILD_DIR := build
BOOT_SRC := boot/boot.asm
BOOT_BIN := $(BUILD_DIR)/boot.bin
KERNEL_SRC := src/kernel.asm
KERNEL_BIN := $(BUILD_DIR)/kernel.bin
KERNEL_SECTORS := 16
DISK_IMG := $(BUILD_DIR)/disk.img

.PHONY: all run inspect clean

all: $(DISK_IMG)

$(BUILD_DIR):
	mkdir -p $@

$(BOOT_BIN): $(BOOT_SRC) | $(BUILD_DIR)
	$(NASM) -f bin -D KERNEL_SECTORS=$(KERNEL_SECTORS) $< -o $@

$(KERNEL_BIN): $(KERNEL_SRC) | $(BUILD_DIR)
	$(NASM) -f bin $< -o $@
	@test "$$(stat -c '%s' $@)" -le "$$(( $(KERNEL_SECTORS) * 512 ))"
	truncate -s "$$(( $(KERNEL_SECTORS) * 512 ))" $@

$(DISK_IMG): $(BOOT_BIN) $(KERNEL_BIN)
	cp $(BOOT_BIN) $@
	dd if=$(KERNEL_BIN) of=$@ bs=512 seek=1 conv=notrunc status=none

run: $(DISK_IMG)
	@unset LD_LIBRARY_PATH SNAP_LIBRARY_PATH GIO_MODULE_DIR GTK_EXE_PREFIX \
		GTK_IM_MODULE_FILE GTK_MODULES GTK_PATH; \
	exec $(QEMU) -drive format=raw,file=$(DISK_IMG) -rtc base=localtime

inspect: $(DISK_IMG)
	@test "$$(stat -c '%s' $(BOOT_BIN))" -eq 512
	@test "$$(tail -c 2 $(BOOT_BIN) | xxd -p)" = "55aa"
	@test "$$(stat -c '%s' $(KERNEL_BIN))" -eq "$$(( $(KERNEL_SECTORS) * 512 ))"
	@test "$$(stat -c '%s' $(DISK_IMG))" -eq "$$(( ($(KERNEL_SECTORS) + 1) * 512 ))"
	@echo "Imagen valida: Stage 1, firma 0xAA55 y Stage 2 de $(KERNEL_SECTORS) sectores."

clean:
	rm -rf $(BUILD_DIR)
