# tclsh examples/peer.tcl   (Tcl 9.0 or 8.6, after `make` for that Tcl)
# Two peer nodes in one interpreter exchange a payload in each direction.
lappend auto_path [file normalize [file join [file dirname [info script]] ..]]
package require tcl-polycall 1.1.0

set alpha [polycall::peer open alpha]           ;# 127.0.0.1:<ephemeral>
set beta  [polycall::peer open beta]
polycall::peer register $alpha beta [polycall::peer endpoint $beta]

polycall::peer send $alpha beta [encoding convertto utf-8 "hello beta"] greeting-1
set m [polycall::peer recv $beta 2000]
puts "beta got [string length [dict get $m payload]] bytes from [dict get $m sender] (id [dict get $m message_id])"

polycall::peer send $beta [polycall::peer endpoint $alpha] "hello alpha" greeting-2
puts "alpha got [dict get [polycall::peer recv $alpha 2000] payload]"

polycall::peer close $alpha
polycall::peer close $beta
