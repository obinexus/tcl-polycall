# TODO — tcl-polycall

Status: implemented Tcl 9 source adapter for libpolycall 1.5.

- [x] Exact thin shim over `polycall_ffi_run_config(config_path, 1)`
- [x] Tcl 9 loadable-extension entry point and namespaced commands
- [x] Raw-status and Tcl-error API variants
- [x] Native mock contract test and Tcl extension smoke test
- [x] npm package metadata, relative directory index, README, and MIT license
- [x] Tcl 9.0.4 source-header compatibility check
- [ ] Build the supplied `C:/ProgramData/tcl9.0.4` source tree
- [ ] Run `make test-tcl` with its resulting `tclsh90` and stub library
- [ ] Run an end-to-end test against a built libpolycall shared core
- [ ] Publish `@obinexusltd/tcl-polycall` publicly on npm
