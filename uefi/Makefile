NASM ?= nasm
LD ?= ld
QEMU ?= qemu-system-x86_64

BUILD_DIR := build
EFI_DIR := $(BUILD_DIR)/esp/EFI/BOOT
OBJS := $(BUILD_DIR)/boot.obj \
	$(BUILD_DIR)/console.obj \
	$(BUILD_DIR)/time.obj \
	$(BUILD_DIR)/clock.obj \
	$(BUILD_DIR)/stopwatch.obj \
	$(BUILD_DIR)/alarm.obj \
	$(BUILD_DIR)/sound.obj
EFI := $(EFI_DIR)/BOOTX64.EFI
IMG := $(BUILD_DIR)/uefi.img
OVMF_CODE := /usr/share/OVMF/OVMF_CODE_4M.fd

.PHONY: all run run-term inspect clean

all: $(IMG)

$(BUILD_DIR):
	mkdir -p $@

$(EFI_DIR):
	mkdir -p $@

$(BUILD_DIR)/boot.obj: boot/boot.asm | $(BUILD_DIR)
	$(NASM) -f win64 $< -o $@

$(BUILD_DIR)/console.obj: src/console.asm | $(BUILD_DIR)
	$(NASM) -f win64 $< -o $@

$(BUILD_DIR)/time.obj: src/time.asm | $(BUILD_DIR)
	$(NASM) -f win64 $< -o $@

$(BUILD_DIR)/clock.obj: src/clock.asm | $(BUILD_DIR)
	$(NASM) -f win64 $< -o $@

$(BUILD_DIR)/stopwatch.obj: src/stopwatch.asm | $(BUILD_DIR)
	$(NASM) -f win64 $< -o $@

$(BUILD_DIR)/alarm.obj: src/alarm.asm | $(BUILD_DIR)
	$(NASM) -f win64 $< -o $@

$(BUILD_DIR)/sound.obj: src/sound.asm | $(BUILD_DIR)
	$(NASM) -f win64 $< -o $@

$(EFI): $(OBJS) | $(EFI_DIR)
	$(LD) -mi386pep --subsystem 10 -e efi_main $^ -o $@

$(IMG): $(EFI)
	dd if=/dev/zero of=$@ bs=1M count=64 status=none
	mformat -i $@ -F ::
	mmd -i $@ ::/EFI ::/EFI/BOOT
	mcopy -i $@ $(EFI) ::/EFI/BOOT/BOOTX64.EFI

run: $(IMG)
	@unset LD_LIBRARY_PATH SNAP_LIBRARY_PATH GIO_MODULE_DIR GTK_EXE_PREFIX \
		GTK_IM_MODULE_FILE GTK_MODULES GTK_PATH; \
	exec $(QEMU) \
		-rtc base=localtime \
		-drive if=pflash,format=raw,readonly=on,file=$(OVMF_CODE) \
		-drive if=none,id=uefi_disk,format=raw,file=$(IMG) \
		-device qemu-xhci \
		-device usb-storage,drive=uefi_disk

run-term: $(IMG)
	@unset LD_LIBRARY_PATH SNAP_LIBRARY_PATH GIO_MODULE_DIR GTK_EXE_PREFIX \
		GTK_IM_MODULE_FILE GTK_MODULES GTK_PATH; \
	exec $(QEMU) \
		-display curses \
		-rtc base=localtime \
		-drive if=pflash,format=raw,readonly=on,file=$(OVMF_CODE) \
		-drive if=none,id=uefi_disk,format=raw,file=$(IMG) \
		-device qemu-xhci \
		-device usb-storage,drive=uefi_disk

inspect: $(EFI) $(IMG)
	file $(EFI)
	mdir -i $(IMG) ::/EFI/BOOT

clean:
	rm -rf $(BUILD_DIR)
