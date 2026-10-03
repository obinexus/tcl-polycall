# tclsh9.0 tests/all.tcl -- run every *.test file in this interpreter and
# exit non-zero when any test failed (tcltest itself always exits 0).
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
exit [expr {$failed > 0 ? 1 : 0}]
