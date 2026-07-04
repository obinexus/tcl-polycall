# Tests

- `tcl_polycall_adapter_test.c` verifies exact path forwarding, validation mode
  `1`, and unchanged core statuses without requiring Tcl or libpolycall.
- `extension-smoke.tcl` verifies package loading, default arguments, raw status
  behavior, and Tcl `POLYCALL STATUS` error translation. It runs through
  `make test-tcl` when a built Tcl 9 interpreter and stub library are supplied.
- `package.test.js` verifies npm metadata, relative directory indexing, exports,
  authorship, and required project files.
