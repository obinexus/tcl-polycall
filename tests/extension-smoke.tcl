proc assert_equal {actual expected message} {
    if {$actual ne $expected} {
        error "$message: expected <$expected>, got <$actual>"
    }
}

if {$argc != 1} {
    error "usage: tclsh extension-smoke.tcl /path/to/tclpolycall[info sharedlibextension]"
}

load [file normalize [lindex $argv 0]] Tclpolycall
assert_equal [package require tcl-polycall] 1.0.0 "package version"
assert_equal [::polycall::run_config ok-polycallrc] 0 "raw status"
assert_equal [::polycall::run_config] 0 "default config status"

set result [catch {::polycall::run_config_or_error __status_37__} message options]
assert_equal $result 1 "nonzero status raises Tcl error"
assert_equal [dict get $options -errorcode] {POLYCALL STATUS 37} "error code"
assert_equal $message {libpolycall run_config failed with status 37} "error message"

puts "tcl-polycall Tcl extension smoke test: PASS"
