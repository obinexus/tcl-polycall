# tcl-polycall - Tcl reference adapter for libpolycall.
#
# A thin adapter over the flat FFI boundary (include/polycall/polycall_ffi.h)
# using the `cffi` package (the standard Tcl C FFI, `teacup install cffi` or
# your distro's tcl-cffi). No config parsing or runtime logic lives here: every
# proc forwards to the shared C core.
#
# Usage:
#   tclsh src/polycall.tcl ../tcl-polycallrc

package require cffi

namespace eval polycall {
    variable VERSION "1.5.0"
    variable loaded 0

    # Locate the shared core produced by the top-level build (setup.sh / CMake).
    proc _find_lib {} {
        set here [file dirname [file normalize [info script]]]
        set root [file normalize [file join $here .. .. ..]]
        foreach d {build bin} {
            foreach n {libpolycall.dll polycall.dll libpolycall.so libpolycall.dylib} {
                set p [file join $root $d $n]
                if {[file exists $p]} { return $p }
            }
        }
        return ""
    }

    proc _load {} {
        variable loaded
        if {$loaded} return
        set lib [_find_lib]
        if {$lib eq ""} {
            error "shared libpolycall not found; build the core first (./setup.sh)" "" {POLYCALL 6}
        }
        cffi::Wrapper create ::polycall::core $lib
        core function polycall_ffi_version     int {buf {chars[64] out} n int}
        core function polycall_ffi_run_config  int {path {string nullok} run int}
        core function polycall_ffi_describe    int {path {string nullok} buf {chars[256] out} n int}
        set loaded 1
    }

    proc version {} {
        _load
        core polycall_ffi_version out 64
        return [string trimright $out "\x00"]
    }

    proc run_config {{path {}} {run 1}} {
        _load
        if {$path eq ""} { set path null }
        set rc [core polycall_ffi_run_config $path $run]
        if {$rc != 0} { error "run_config($path) failed" "" [list POLYCALL $rc] }
        return $rc
    }

    proc describe {{path {}}} {
        _load
        if {$path eq ""} { set path null }
        set rc [core polycall_ffi_describe $path out 256]
        set text [string trimright $out "\x00"]
        if {$rc != 0} { error "describe: $text" "" [list POLYCALL $rc] }
        return $text
    }
}

# Tiny CLI when run directly.
if {[info exists argv0] && [file normalize $argv0] eq [file normalize [info script]]} {
    set cfg [lindex $argv 0]
    puts "tcl-polycall using libpolycall [polycall::version]"
    puts [polycall::describe $cfg]
    exit [polycall::run_config $cfg]
}
