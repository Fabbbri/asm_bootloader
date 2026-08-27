NASM ?= nasm
QEMU ?= qemu-system-i386

BUILD_DIR := build
BOOT_SRC := boot/boot.asm
BOOT_BIN := $(BUILD_DIR)/boot.bin
DISK_IMG := $(BUILD_DIR)/disk.img

.PHONY: all run inspect clean

all: $(DISK_IMG)

$(BUILD_DIR):
	mkdir -p $@

$(BOOT_BIN): $(BOOT_SRC) | $(BUILD_DIR)
	$(NASM) -f bin $< -o $@

$(DISK_IMG): $(BOOT_BIN)
	cp $< $@

run: $(DISK_IMG)
	@unset LD_LIBRARY_PATH SNAP_LIBRARY_PATH GIO_MODULE_DIR GTK_EXE_PREFIX \
		GTK_IM_MODULE_FILE GTK_MODULES GTK_PATH; \
	exec $(QEMU) -drive format=raw,file=$(DISK_IMG)

inspect: $(DISK_IMG)
	@test "$$(stat -c '%s' $(BOOT_BIN))" -eq 512
	@test "$$(tail -c 2 $(BOOT_BIN) | xxd -p)" = "55aa"
	@echo "Sector de arranque valido: 512 bytes, firma 0xAA55."

clean:
	rm -rf $(BUILD_DIR)
