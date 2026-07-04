# Loader for the tcl-polycall native extension.

namespace eval ::tclpolycall::loader {
    variable packageRoot [file normalize [file join [file dirname [info script]] ..]]
    variable extension [file join $packageRoot dist tclpolycall[info sharedlibextension]]
}

if {![file isfile $::tclpolycall::loader::extension]} {
    return -code error -errorcode {TCLPOLYCALL LOAD MISSING} \
        "tcl-polycall extension not found at $::tclpolycall::loader::extension; run `npm run build:tcl`"
}

load $::tclpolycall::loader::extension Tclpolycall
