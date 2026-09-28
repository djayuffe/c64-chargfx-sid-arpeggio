.PHONY: all charset clean run test verify

ACME ?= acme
PYTHON ?= python3
OUTPUT := build/c64_chargfx_sid_arpeggio.prg
SYMBOLS := build/c64_chargfx_sid_arpeggio.sym
SOURCE := c64_chargfx_sid_arpeggio.s
CHARSET := custom_charset_1bpp.bin
ACMEFLAGS := --strict-segments -I . -f cbm

all: $(OUTPUT)

$(OUTPUT): $(SOURCE) $(CHARSET)
	@mkdir -p build
	$(ACME) $(ACMEFLAGS) --symbollist $(SYMBOLS) -o $@ $(SOURCE)

charset: $(CHARSET)

$(CHARSET): scripts/generate_charset.py
	$(PYTHON) scripts/generate_charset.py --output $(CHARSET)

verify: $(SOURCE) $(CHARSET) scripts/generate_charset.py scripts/verify_build.py
	@mkdir -p build
	$(ACME) $(ACMEFLAGS) --symbollist $(SYMBOLS) -o $(OUTPUT) $(SOURCE)
	PYTHONPYCACHEPREFIX=/tmp/c64-chargfx-pycache $(PYTHON) scripts/verify_build.py \
		--prg $(OUTPUT) --symbols $(SYMBOLS) --charset $(CHARSET) --source $(SOURCE)

test: verify

run: $(OUTPUT)
	x64sc -pal -autostart $(OUTPUT)

clean:
	rm -rf build
