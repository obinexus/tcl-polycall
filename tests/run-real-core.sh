#!/bin/sh
# tcl-polycall: build the Tcl 9 extension against the installed core (pkg-config),
# install it into a staging package directory and run the tcltest suite with
# `package require tcl-polycall` resolving to that installed copy.
#
#   sh tests/run-real-core.sh
#
# Needs tclsh9.0 + Tcl 9 headers/stub library (tcl9.0-dev), the Tcl Thread
# package for the threaded checks, make, a C compiler and the core
# (POLYCALL_PREFIX, default /opt/polycall). Exit: 0 pass, 1 failure,
# 77 SKIPPED (a missing toolchain is never reported as success).
set -u
cd "$(dirname "$0")/.." || exit 1
REPO=$(pwd)
TCLSH=${TCLSH:-tclsh9.0}
command -v "$TCLSH" >/dev/null 2>&1 || { echo "SKIP: $TCLSH not found on PATH"; exit 77; }
command -v make >/dev/null 2>&1 || { echo "SKIP: make not found"; exit 77; }
command -v pkg-config >/dev/null 2>&1 || { echo "SKIP: pkg-config not found"; exit 77; }
. tests/real-core-env.sh
pkg-config --exists polycall || pc_skip "polycall.pc not found (PKG_CONFIG_PATH)"

make TCLSH="$TCLSH" || { echo "FAIL: build"; exit 1; }
STAGE="$POLYCALL_TEST_TMP/stage"
make install TCLSH="$TCLSH" DESTDIR="$STAGE" TCL_PKG_DIR=/tcl || { echo "FAIL: make install"; exit 1; }
# a second build without RUNPATH, for the "library missing" check
make TCLSH="$TCLSH" EXTENSION="$POLYCALL_TEST_TMP/norpath/tclpolycall.so" POLYCALL_LIBDIR= \
  >/dev/null || { echo "FAIL: norpath build"; exit 1; }
TCL_POLYCALL_NORPATH_EXT="$POLYCALL_TEST_TMP/norpath/tclpolycall.so"
TCLLIBPATH="$STAGE/tcl"
TCL_POLYCALL_REPO="$REPO"
export TCL_POLYCALL_NORPATH_EXT TCLLIBPATH TCL_POLYCALL_REPO
echo "testing the installed package at $STAGE/tcl/tcl-polycall1.1.0"
"$TCLSH" tests/all.tcl
