.DEFAULT_GOAL := build
CART = build/cart.wasm

ifndef WASI_SDK_PATH
$(error Download the WASI SDK (https://github.com/WebAssembly/wasi-sdk) and set $$WASI_SDK_PATH)
endif

CC = "$(WASI_SDK_PATH)/bin/clang" --sysroot="$(WASI_SDK_PATH)/share/wasi-sysroot"

# Optional dependency from binaryen for smaller builds
WASM_OPT = wasm-opt
WASM_OPT_FLAGS = -Oz --zero-filled-memory --strip-producers

# Whether to build for debugging instead of release
DEBUG = 0

# Compilation flags
CFLAGS = -MMD -MP -fno-exceptions -I$(CARP_DIR)/core
# CFLAGS = -W -Wall -Wextra -Werror -Wno-unused -Wconversion -Wsign-conversion -MMD -MP -fno-exceptions -I$(CARP_DIR)/core
ifeq ($(DEBUG), 1)
	CFLAGS += -DDEBUG -O0 -g
else
	CFLAGS += -DNDEBUG -Oz -flto
endif

# Linker flags
LDFLAGS = -Wl,-zstack-size=14752,--no-entry,--import-memory -mexec-model=reactor \
	-Wl,--initial-memory=65536,--max-memory=65536,--stack-first
ifeq ($(DEBUG), 1)
	LDFLAGS += -Wl,--export-all,--no-gc-sections
else
	LDFLAGS += -Wl,--strip-all,--gc-sections,--lto-O3 -Oz
endif

ifeq ($(OS), Windows_NT)
	MKDIR_BUILD = if not exist build md build
	RMDIR = rd /s /q
else
	MKDIR_BUILD = mkdir -p build
	RMDIR = rm -rf
endif

OBJECTS = build/main.o
DEPS = $(OBJECTS:.o=.d)

build/%.h: assets/%.png
	@$(MKDIR_BUILD)
	w4 png2src --c -o $@ $<

ASSETS = $(patsubst assets/%.png, build/%.h, $(wildcard assets/*.png))

build/main.c: $(wildcard **/*.carp) $(wildcard *.carp)
	@$(MKDIR_BUILD)
	carp --no-core -b main.carp

# Compile C sources
$(OBJECTS): build/main.c $(ASSETS)
	@$(MKDIR_BUILD)
	$(CC) -c $< -o $@ $(CFLAGS)

# Link cart.wasm from all object files and run wasm-opt
$(CART): $(OBJECTS)
	$(CC) -o $@ $(OBJECTS) $(LDFLAGS)
ifneq ($(DEBUG), 1)
ifeq (, $(shell command -v $(WASM_OPT)))
	@echo Tip: $(WASM_OPT) was not found. Install it from binaryen for smaller builds!
else
	$(WASM_OPT) $(WASM_OPT_FLAGS) $@ -o $@
endif
endif

.PHONY: build
build: $(CART)

.PHONY: clean
clean:
	$(RMDIR) build

.PHONY: run
run: $(CART)
	w4 run $(CART) --no-open --no-qr

.PHONY: run-native
run-native: $(CART)
	w4 run-native $(CART)

-include $(DEPS)
