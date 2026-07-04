CC ?= gcc
AR ?= ar

CPPFLAGS ?=
CPPFLAGS += -Iinclude -Igenerated
CFLAGS ?= -O2
CFLAGS += -std=c11 -Wall -Wextra -Wpedantic

TCL_ROOT ?= C:/ProgramData/tcl9.0.4
TCL_INCLUDE ?= $(TCL_ROOT)/generic
TCLSH ?= tclsh9.0
TCL_STUB_LIB ?=
POLYCALL_LDFLAGS ?=

BUILD_DIR := build
LIB_DIR := lib
DIST_DIR := dist
ADAPTER_OBJ := $(BUILD_DIR)/tcl_polycall.o
STATIC_LIB := $(LIB_DIR)/libtcl_polycall.a
TEST_BIN := $(BUILD_DIR)/tcl_polycall_adapter_test

ifeq ($(OS),Windows_NT)
EXE_EXT := .exe
SHARED_EXT := .dll
TEST_BIN := $(TEST_BIN)$(EXE_EXT)
else
EXE_EXT :=
SHARED_EXT := .so
endif

EXTENSION := $(DIST_DIR)/tclpolycall$(SHARED_EXT)

.DEFAULT_GOAL := all

.PHONY: all
all: $(STATIC_LIB)

$(BUILD_DIR) $(LIB_DIR) $(DIST_DIR):
ifeq ($(OS),Windows_NT)
	@if not exist "$@" mkdir "$@"
else
	@mkdir -p $@
endif

$(ADAPTER_OBJ): src/tcl_polycall.c include/tcl_polycall.h generated/polycall/polycall_ffi.h | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@

$(STATIC_LIB): $(ADAPTER_OBJ) | $(LIB_DIR)
	$(AR) rcs $@ $^

$(TEST_BIN): src/tcl_polycall.c tests/polycall_ffi_mock.c tests/tcl_polycall_adapter_test.c | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) -Itests $(CFLAGS) $^ -o $@

.PHONY: test
test: $(TEST_BIN)
	$(TEST_BIN)

.PHONY: tcl-check
tcl-check:
	$(CC) $(CPPFLAGS) -I"$(TCL_INCLUDE)" -DUSE_TCL_STUBS $(CFLAGS) -fsyntax-only src/tcl_polycall_extension.c

.PHONY: tcl-check-if-available
tcl-check-if-available:
ifeq ($(OS),Windows_NT)
	@if exist "$(TCL_INCLUDE)\tcl.h" ($(MAKE) tcl-check) else (echo Tcl headers not found at $(TCL_INCLUDE); skipping Tcl source check)
else
	@if test -f "$(TCL_INCLUDE)/tcl.h"; then $(MAKE) tcl-check; else echo "Tcl headers not found at $(TCL_INCLUDE); skipping Tcl source check"; fi
endif

.PHONY: extension
extension: | $(DIST_DIR)
ifeq ($(OS),Windows_NT)
	@if "$(strip $(TCL_STUB_LIB))"=="" (echo Set TCL_STUB_LIB to the Tcl 9 stub library & exit /b 2)
	@if "$(strip $(POLYCALL_LDFLAGS))"=="" (echo Set POLYCALL_LDFLAGS to the libpolycall linker flags & exit /b 2)
else
	@test -n "$(TCL_STUB_LIB)" || (echo "Set TCL_STUB_LIB to the Tcl 9 stub library" && exit 2)
	@test -n "$(POLYCALL_LDFLAGS)" || (echo "Set POLYCALL_LDFLAGS to the libpolycall linker flags" && exit 2)
endif
	$(CC) $(CPPFLAGS) -I"$(TCL_INCLUDE)" -DUSE_TCL_STUBS $(CFLAGS) -shared \
		src/tcl_polycall.c src/tcl_polycall_extension.c \
		$(POLYCALL_LDFLAGS) "$(TCL_STUB_LIB)" -o $(EXTENSION)

.PHONY: test-tcl
test-tcl: | $(BUILD_DIR)
ifeq ($(OS),Windows_NT)
	@if "$(strip $(TCL_STUB_LIB))"=="" (echo Set TCL_STUB_LIB to the Tcl 9 stub library & exit /b 2)
else
	@test -n "$(TCL_STUB_LIB)" || (echo "Set TCL_STUB_LIB to the Tcl 9 stub library" && exit 2)
endif
	$(CC) $(CPPFLAGS) -Itests -I"$(TCL_INCLUDE)" -DUSE_TCL_STUBS $(CFLAGS) -shared \
		src/tcl_polycall.c src/tcl_polycall_extension.c tests/polycall_ffi_mock.c \
		"$(TCL_STUB_LIB)" -o $(BUILD_DIR)/tclpolycall$(SHARED_EXT)
	$(TCLSH) tests/extension-smoke.tcl $(BUILD_DIR)/tclpolycall$(SHARED_EXT)

.PHONY: verify-dry
verify-dry:
ifeq ($(OS),Windows_NT)
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-dry.ps1
else
	sh scripts/verify-dry.sh
endif

.PHONY: clean
clean:
ifeq ($(OS),Windows_NT)
	@if exist "$(BUILD_DIR)" rmdir /s /q "$(BUILD_DIR)"
	@if exist "$(LIB_DIR)" rmdir /s /q "$(LIB_DIR)"
	@if exist "$(EXTENSION)" del /q "$(EXTENSION)"
else
	rm -rf $(BUILD_DIR) $(LIB_DIR) $(EXTENSION)
endif

-include $(ADAPTER_OBJ:.o=.d)
