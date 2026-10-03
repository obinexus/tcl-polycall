# tclsh9.0 examples/run.tcl ?configPath?   (after `make`)
# Validates a configuration file with the core: polycall_ffi_run_config(path, 1).
set projectRoot [file normalize [file join [file dirname [info script]] ..]]
lappend auto_path $projectRoot

package require tcl-polycall 1.1.0

set configPath [expr {$argc > 0
    ? [lindex $argv 0]
    : [file join $projectRoot examples tcl-polycallrc]}]

puts "libpolycall [::polycall::version] (binding ABI [::polycall::abi_version])"
puts "tcl-polycall status: [::polycall::run_config_or_error $configPath]"
