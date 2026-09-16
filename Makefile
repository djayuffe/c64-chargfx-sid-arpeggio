.PHONY: all clean

ACME ?= acme
OUTPUT := build/deepseek_c64_v10k4c.prg
SOURCE := deepseek_c64_v10k4c.s

all: $(OUTPUT)

$(OUTPUT): $(SOURCE) custom_charset_1bpp.bin
	@mkdir -p build
	$(ACME) --strict-segments -I . -f cbm -o $@ $(SOURCE)

clean:
	rm -rf build
