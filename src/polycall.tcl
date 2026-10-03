# Loader for the tcl-polycall native extension built by `make` into
# dist/tclpolycall[info sharedlibextension] (.so, .dylib or .dll -- the
# Makefile uses the same suffix Tcl expects on each platform).

namespace eval ::tclpolycall::loader {
    variable packageRoot [file normalize [file join [file dirname [info script]] ..]]
    variable extension [file join $packageRoot dist tclpolycall[info sharedlibextension]]
}

if {![file isfile $::tclpolycall::loader::extension]} {
    return -code error -errorcode {POLYCALL LOAD MISSING} \
        "tcl-polycall extension not found at $::tclpolycall::loader::extension; run `make`"
}

load $::tclpolycall::loader::extension Tclpolycall
