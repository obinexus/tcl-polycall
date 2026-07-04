# Build output

`npm run build:tcl` writes the loadable Tcl extension here as
`tclpolycall.dll` on Windows or `tclpolycall.so` on Unix-like platforms.

The compiled binary is intentionally not committed because it is specific to
the Tcl ABI, operating system, architecture, and libpolycall build.
