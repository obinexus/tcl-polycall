# TODO — tcl-polycall

Status: Tcl 9 extension over the Polycall binding ABI v1 (libpolycall >= 1.1.0).

- [x] `src/tcl_polycall.c` includes the real `<polycall.h>`; linked via pkg-config
- [x] `-fPIC`, `-z now`, RUNPATH; macOS builds `.dylib` (what `[info sharedlibextension]` loads)
- [x] `run_config ?path?` keeps `polycall_ffi_run_config(path, 1)`; `call`; `peer ...`
- [x] Errors: `-errorcode {POLYCALL NAME status detail ?extra?}`
- [x] tcltest suite against the real core (Linux, Debian 13, Tcl 9.0.1 + Thread 3.0.1)
- [ ] Windows build (MSVC/MinGW Tcl 9 with its stub library) and run
- [ ] Publish `@obinexusltd/tcl-polycall`
