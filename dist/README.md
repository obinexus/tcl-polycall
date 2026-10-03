# Build output

`make` writes the loadable Tcl extension here as `tclpolycall.so` (Linux),
`tclpolycall.dylib` (macOS) or `tclpolycall.dll` (Windows) -- the suffix
`[info sharedlibextension]` that `src/polycall.tcl` loads.

The compiled binary is not committed: it is specific to the Tcl ABI, OS,
architecture and libpolycall build.
