# Package index for running from a checkout (lappend auto_path <checkout>)
# after `make`. `make install` writes its own pkgIndex.tcl next to the
# installed extension instead.
package ifneeded tcl-polycall 1.1.0 [list source [file join $dir src polycall.tcl]]
