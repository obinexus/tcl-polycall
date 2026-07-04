# Adapter boundary

`tcl_polycall_run_config()` is the only native language-adapter operation. It
passes the caller's UTF-8 configuration path to
`polycall_ffi_run_config(config_path, 1)` and returns the core status unchanged.

`tcl_polycall_extension.c` only translates between Tcl objects and that C
function. Configuration parsing, validation, and runtime behavior remain in
libpolycall.
