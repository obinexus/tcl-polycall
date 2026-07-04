set projectRoot [file normalize [file join [file dirname [info script]] ..]]
lappend auto_path $projectRoot

package require tcl-polycall 1.0.0

set configPath [expr {$argc > 0
    ? [lindex $argv 0]
    : [file join $projectRoot examples tcl-polycallrc]}]

puts "tcl-polycall status: [::polycall::run_config_or_error $configPath]"
