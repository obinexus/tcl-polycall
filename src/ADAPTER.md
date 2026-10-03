# Adapter boundary

`tcl_polycall.c` is a Tcl 9 extension (stubs-enabled) that includes the real
`<polycall.h>` and links libpolycall through pkg-config. Each Tcl command
translates Tcl objects to the binding ABI v1 C call and back: strings as
UTF-8, payloads as byte arrays `(pointer, length)`, handles as int32,
caller-owned output buffers. Statuses become Tcl errors with
`-errorcode {POLYCALL <NAME> <status> <polycall_last_error> ?extra?}`.

`::polycall::run_config ?path?` keeps the documented contract:
`polycall_ffi_run_config(path, 1)` with the status returned unchanged.

Configuration parsing, the wire protocols and the peer transport stay in
libpolycall; this extension has no parser and no network code.
