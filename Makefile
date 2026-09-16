.PHONY: all clean

ACME ?= acme
OUTPUT := build/c64_chargfx_sid_arpeggio.prg
SOURCE := c64_chargfx_sid_arpeggio.s

all: $(OUTPUT)

$(OUTPUT): $(SOURCE) custom_charset_1bpp.bin
	@mkdir -p build
	$(ACME) --strict-segments -I . -f cbm -o $@ $(SOURCE)

clean:
	rm -rf build
