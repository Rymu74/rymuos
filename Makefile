.SILENT:

override CC := gcc
override LD := ld
override MAKEFLAGS += -rR

override KERNEL := rymuos
override IMAGE_NAME := rymuos

UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Darwin)
    override CC := x86_64-elf-gcc
    override LD := x86_64-elf-ld
endif

define DEFAULT_VAR =
    ifeq ($(origin $1),default)
        override $(1) := $(2)
    endif
    ifeq ($(origin $1),undefined)
        override $(1) := $(2)
    endif
endef

override DEFAULT_CC := cc
$(eval $(call DEFAULT_VAR,CC,$(DEFAULT_CC)))

override DEFAULT_LD := ld
$(eval $(call DEFAULT_VAR,LD,$(DEFAULT_LD)))

override DEFAULT_CFLAGS := -g -O2 -pipe
$(eval $(call DEFAULT_VAR,CFLAGS,$(DEFAULT_CFLAGS)))

override DEFAULT_CPPFLAGS :=
$(eval $(call DEFAULT_VAR,CPPFLAGS,$(DEFAULT_CPPFLAGS)))

override DEFAULT_NASMFLAGS := -F dwarf -g
$(eval $(call DEFAULT_VAR,NASMFLAGS,$(DEFAULT_NASMFLAGS)))

override DEFAULT_LDFLAGS :=
$(eval $(call DEFAULT_VAR,LDFLAGS,$(DEFAULT_LDFLAGS)))

override CFLAGS += -O0 -Ilimine -Isrc -Wall -Wextra -std=gnu11 -ffreestanding -fno-stack-protector -fno-stack-check -fno-lto -fno-PIE -fno-PIC -m64 -march=x86-64 -mabi=sysv -mcmodel=kernel -mno-80387 -mno-mmx -mno-sse -mno-sse2 -mno-red-zone -DPRINTF_DISABLE_SUPPORT_FLOAT -DHEAP_ACCESSABLE

override LDFLAGS += -nostdlib -static -m elf_x86_64 -z max-page-size=0x1000 -T linker.ld

override CPPFLAGS := -I. $(CPPFLAGS) -MMD -MP

override NASMFLAGS += -Wall -f elf64

override CFILES := $(shell cd src && find -L * -type f -name '*.c')
override ASFILES := $(shell cd src && find -L * -type f -name '*.S')
override NASMFILES := $(shell cd src && find -L * -type f -name '*.asm')
override OBJ := $(addprefix obj/,$(CFILES:.c=.c.o) $(ASFILES:.S=.S.o) $(NASMFILES:.asm=.asm.o))
override HEADER_DEPS := $(addprefix obj/,$(CFILES:.c=.c.d) $(ASFILES:.S=.S.d))

.PHONY: all
all: dist/$(KERNEL)

dist/$(KERNEL): Makefile linker.ld $(OBJ)
	echo "linking kernel"
	mkdir -p "$$(dirname $@)"
	$(LD) $(OBJ) $(LDFLAGS) -o $@

-include $(HEADER_DEPS)

obj/%.c.o: src/%.c Makefile
	echo "$@"
	mkdir -p "$$(dirname $@)"
	$(CC) $(CFLAGS) $(CPPFLAGS) -c $< -o $@

obj/%.S.o: src/%.S Makefile
	echo "$@"
	mkdir -p "$$(dirname $@)"
	$(CC) $(CFLAGS) $(CPPFLAGS) -c $< -o $@

obj/%.asm.o: src/%.asm Makefile
	echo "$@"
	mkdir -p "$$(dirname $@)"
	nasm $(NASMFLAGS) $< -o $@

.PHONY: iso
iso:
	make -s
	echo "building limine"
	git clone -q https://github.com/limine-bootloader/limine.git --branch=v6.x-branch-binary --depth=1
	make -s -C limine

	rm -rf iso_root
	mkdir -p iso_root
	cp dist/rymuos \
		limine.cfg limine/limine-bios.sys limine/limine-bios-cd.bin limine/limine-uefi-cd.bin iso_root/
	mkdir -p iso_root/EFI/BOOT
	cp limine/BOOTX64.EFI iso_root/EFI/BOOT/
	cp limine/BOOTIA32.EFI iso_root/EFI/BOOT/
	xorriso -as mkisofs -b limine-bios-cd.bin \
		-no-emul-boot -boot-load-size 4 -boot-info-table \
		--efi-boot limine-uefi-cd.bin \
		-efi-boot-part --efi-boot-image --protective-msdos-label \
		iso_root -o $(IMAGE_NAME).iso
	./limine/limine bios-install $(IMAGE_NAME).iso
	rm -rf iso_root limine
	echo ""
	echo "build complete"

.PHONY: clean full-clean

clean:
	rm -rf dist obj limine rymuos.raw.bin rymuos.iso
