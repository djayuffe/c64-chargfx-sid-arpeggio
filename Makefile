.PHONY: all clean

ACME ?= acme
OUTPUT := build/v10k4c.prg
SOURCE := deepseek_asm_20251009_v10k4c_chargfx_safe_loudsid_clean.s

all: $(OUTPUT)

$(OUTPUT): $(SOURCE) custom_charset_1bpp.bin
	@mkdir -p build
	$(ACME) --strict-segments -I . -f cbm -o $@ $(SOURCE)

clean:
	rm -rf build
