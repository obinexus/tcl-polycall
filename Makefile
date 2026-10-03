# tcl-polycall -- Tcl 9 loadable extension over the Polycall binding ABI v1.
#
#   make                      build dist/tclpolycall$(SHLIB_EXT)
#   make test                 run tests/all.tcl against the real core (tclsh9.0)
#   make install [DESTDIR=..] install the package into $(TCL_PKG_DIR)/tcl-polycall$(VERSION)
#
# The core is found through pkg-config (polycall.pc; set PKG_CONFIG_PATH for a
# non-system prefix) and Tcl through tclConfig.sh (TCL_CONFIG). Nothing is
# hard-coded: override POLYCALL_CFLAGS / POLYCALL_LIBS / TCL_CFLAGS /
# TCL_STUB_LIB when needed.

VERSION := 1.1.0
comma := ,
CC ?= cc
PKG_CONFIG ?= pkg-config
TCLSH ?= tclsh9.0

# Debian/Ubuntu: prefer the multiarch file. /usr/lib/tcl9.0/tclConfig.sh is a
# wrapper that needs dpkg-architecture (dpkg-dev) and sources itself forever
# without it, so it is the last resort.
TCL_CONFIG ?= $(firstword $(wildcard \
	/usr/lib/*-linux-gnu*/tcl9.0/tclConfig.sh \
	/usr/lib64/tcl9.0/tclConfig.sh \
	/usr/local/lib/tcl9.0/tclConfig.sh \
	/usr/local/lib/tclConfig.sh \
	/opt/homebrew/lib/tclConfig.sh \
	/usr/lib/tcl9.0/tclConfig.sh))
TCL_CFLAGS ?= $(shell sh -c '. "$(TCL_CONFIG)" && echo $$TCL_INCLUDE_SPEC' 2>/dev/null)
TCL_STUB_LIB ?= $(shell sh -c '. "$(TCL_CONFIG)" && echo $$TCL_STUB_LIB_SPEC' 2>/dev/null)
TCL_PKG_DIR ?= $(shell echo 'puts [lindex $$tcl_pkgPath 0]' | $(TCLSH) 2>/dev/null)

POLYCALL_CFLAGS ?= $(shell $(PKG_CONFIG) --cflags polycall)
POLYCALL_LIBS ?= $(shell $(PKG_CONFIG) --libs polycall)
POLYCALL_LIBDIR ?= $(shell $(PKG_CONFIG) --variable=libdir polycall)

CFLAGS ?= -O2 -g
WARN := -std=c11 -Wall -Wextra -Wpedantic -Wno-overlength-strings

UNAME_S := $(shell uname -s 2>/dev/null)
ifeq ($(OS),Windows_NT)
SHLIB_EXT := .dll
PIC :=
SHARED := -shared
LINK_EXTRA :=
else ifeq ($(UNAME_S),Darwin)
# must match [info sharedlibextension] on macOS, which src/polycall.tcl loads
SHLIB_EXT := .dylib
PIC := -fPIC
SHARED := -dynamiclib
LINK_EXTRA := $(if $(POLYCALL_LIBDIR),-Wl$(comma)-rpath$(comma)$(POLYCALL_LIBDIR))
else
SHLIB_EXT := .so
PIC := -fPIC
SHARED := -shared
# bind every core symbol at load time: an old core without the ABI v1
# symbols fails `load` with a clear "undefined symbol" error, never later
LINK_EXTRA := -Wl,-z,now -Wl,--no-undefined $(if $(POLYCALL_LIBDIR),-Wl$(comma)-rpath$(comma)$(POLYCALL_LIBDIR))
endif

EXTENSION := dist/tclpolycall$(SHLIB_EXT)

.PHONY: all
all: $(EXTENSION)

.PHONY: check-deps
check-deps:
	@test -n "$(TCL_CFLAGS)$(TCL_CONFIG)" || { echo "Tcl 9 development files not found (set TCL_CONFIG=/path/to/tclConfig.sh)"; exit 2; }
	@$(PKG_CONFIG) --exists polycall || { echo "polycall.pc not found (install the Polycall core >= 1.1.0 or set PKG_CONFIG_PATH)"; exit 2; }

$(EXTENSION): src/tcl_polycall.c | check-deps
	@mkdir -p $(dir $@)
	$(CC) $(WARN) $(CFLAGS) $(PIC) -DUSE_TCL_STUBS $(TCL_CFLAGS) $(POLYCALL_CFLAGS) $(SHARED) \
		src/tcl_polycall.c -o $@ $(POLYCALL_LIBS) $(TCL_STUB_LIB) $(LINK_EXTRA) $(LDFLAGS)

.PHONY: test
test: $(EXTENSION)
	$(TCLSH) tests/all.tcl $(abspath $(EXTENSION))

# Installs a self-contained package directory: pkgIndex.tcl + the extension.
.PHONY: install
install: $(EXTENSION)
	@test -n "$(TCL_PKG_DIR)" || { echo "cannot determine TCL_PKG_DIR; pass TCL_PKG_DIR=..."; exit 2; }
	mkdir -p "$(DESTDIR)$(TCL_PKG_DIR)/tcl-polycall$(VERSION)"
	cp $(EXTENSION) "$(DESTDIR)$(TCL_PKG_DIR)/tcl-polycall$(VERSION)/"
	printf '%s\n' 'package ifneeded tcl-polycall $(VERSION) [list load [file join $$dir tclpolycall[info sharedlibextension]] Tclpolycall]' \
		> "$(DESTDIR)$(TCL_PKG_DIR)/tcl-polycall$(VERSION)/pkgIndex.tcl"

.PHONY: clean
clean:
	rm -rf build dist/tclpolycall.so dist/tclpolycall.dylib dist/tclpolycall.dll
