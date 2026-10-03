#!/bin/sh
# tcl-polycall: build the extension for $TCLSH's Tcl (9.0 or 8.6) against the
# installed core (pkg-config), install it into a staging package directory
# and run the tcltest suite with `package require tcl-polycall` resolving to
# that installed copy.
#
#   sh tests/run-real-core.sh                       # tclsh9.0
#   TCLSH=tclsh8.6 sh tests/run-real-core.sh        # Tcl 8.6
#   TCLSH=tclsh86 POLYCALL_PREFIX=... sh tests/run-real-core.sh   # MSYS2 UCRT64 shell
#
# Needs tclsh + its headers/stub library (tcl9.0-dev or tcl8.6-dev), the Tcl
# Thread package for the threaded checks, make, pkg-config, a C compiler and
# the core (POLYCALL_PREFIX, default /opt/polycall). Build output goes to a
# temporary directory, never into the checkout. TCL_POLYCALL_TEST_WRAPPER
# (e.g. "valgrind --error-exitcode=99") runs the suite under a tool.
# Exit: 0 pass, 1 failure, 77 SKIPPED (a missing toolchain is never reported
# as success).
set -u
cd "$(dirname "$0")/.." || exit 1
REPO=$(pwd)
TCLSH=${TCLSH:-tclsh9.0}
command -v "$TCLSH" >/dev/null 2>&1 || { echo "SKIP: $TCLSH not found on PATH"; exit 77; }
command -v make >/dev/null 2>&1 || { echo "SKIP: make not found"; exit 77; }
command -v pkg-config >/dev/null 2>&1 || { echo "SKIP: pkg-config not found"; exit 77; }
. tests/real-core-env.sh
pkg-config --exists polycall || pc_skip "polycall.pc not found (PKG_CONFIG_PATH)"
if [ "$POLYCALL_TEST_WINDOWS" != 1 ]; then
  # paths cross to the core as UTF-8 (BINDING_ABI.md); on POSIX that matches
  # the file names Tcl itself creates only in a UTF-8 locale
  case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
    *UTF-8*|*utf-8*|*utf8*|*UTF8*) ;;
    *) LC_ALL=C.UTF-8; export LC_ALL ;;
  esac
fi

TCLV=$(echo 'puts [info tclversion]' | "$TCLSH" | tr -d '\r')
SHLIB=$(echo 'puts [info sharedlibextension]' | "$TCLSH" | tr -d '\r')
BUILD="$PC_TMP/build"
EXT="$BUILD/tclpolycall$SHLIB"
STAGE="$PC_TMP/stage"
make TCL_VERSION="$TCLV" TCLSH="$TCLSH" EXTENSION="$EXT" || { echo "FAIL: build"; exit 1; }
make install TCL_VERSION="$TCLV" TCLSH="$TCLSH" EXTENSION="$EXT" DESTDIR="$STAGE" TCL_PKG_DIR=/tcl \
  || { echo "FAIL: make install"; exit 1; }
# a copy whose core can only come from the loader path, for the "library
# missing" check: Linux builds it without RUNPATH; on Windows the DLL search
# path already decides
mkdir -p "$PC_TMP/norpath"
if [ "$POLYCALL_TEST_WINDOWS" = 1 ]; then
  cp "$EXT" "$PC_TMP/norpath/" || { echo "FAIL: norpath copy"; exit 1; }
else
  make TCL_VERSION="$TCLV" TCLSH="$TCLSH" EXTENSION="$PC_TMP/norpath/tclpolycall$SHLIB" POLYCALL_LIBDIR= \
    >/dev/null || { echo "FAIL: norpath build"; exit 1; }
fi
TCL_POLYCALL_NORPATH_EXT="$POLYCALL_TEST_TMP/norpath/tclpolycall$SHLIB"
TCLLIBPATH=$(pc_native "$STAGE/tcl")
TCL_POLYCALL_REPO=$(pc_native "$REPO")
export TCL_POLYCALL_NORPATH_EXT TCLLIBPATH TCL_POLYCALL_REPO
echo "testing the installed package at $TCLLIBPATH/tcl-polycall1.1.0 with Tcl $(echo 'puts [info patchlevel]' | "$TCLSH")"
# shellcheck disable=SC2086
${TCL_POLYCALL_TEST_WRAPPER:-} "$TCLSH" tests/all.tcl
