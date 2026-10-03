# tclsh tests/all.tcl -- run every *.test file in this interpreter (normally
# through tests/run-real-core.sh, which sets up the real core). tcltest
# itself always exits 0, so this exits 1 when any test failed, 77 (SKIPPED)
# when any test was skipped for a missing prerequisite, and 0 only when every
# test ran and passed.
package require tcltest 2.5
namespace import ::tcltest::*
configure -verbose {body error pass skip start} -testdir [file dirname [file normalize [info script]]]
foreach file [lsort [glob -directory [configure -testdir] *.test]] {
    source $file
}
set failed $::tcltest::numTests(Failed)
set skipped $::tcltest::numTests(Skipped)
set total $::tcltest::numTests(Total)
cleanupTests
puts "tcl-polycall: total $total, failed $failed, skipped $skipped"
if {$failed > 0} { exit 1 }
if {$skipped > 0} {
    puts "tcl-polycall: SKIPPED -- $skipped test(s) did not run (see the constraints above); not a pass"
    exit 77
}
exit 0
