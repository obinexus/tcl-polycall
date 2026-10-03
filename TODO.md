# TODO — tcl-polycall

Status: Tcl extension (Tcl 9.0 and 8.6) over the Polycall binding ABI v1 (libpolycall >= 1.1.0).

- [x] `src/tcl_polycall.c` includes the real `<polycall.h>`; linked via pkg-config
- [x] `-fPIC`, `-z now`, RUNPATH; macOS builds `.dylib` (what `[info sharedlibextension]` loads)
- [x] `run_config ?path?` keeps `polycall_ffi_run_config(path, 1)`; `call`; `peer ...`
- [x] Errors: `-errorcode {POLYCALL NAME status detail ?extra?}`
- [x] tcltest suite against the real core: Linux (Debian 13, Tcl 9.0.1 + Thread 3.0.1, Tcl 8.6.16 + Thread 2.8.11; valgrind clean)
- [x] Windows x64: MSYS2 UCRT64 GCC + Tcl 8.6.18 / Thread 2.8.13 against `libpolycall.dll` and the MSVC `polycall.dll`
- [ ] Tcl 9 on Windows (no Tcl 9 build on the QA host) and macOS (no macOS host): built by the Makefile, not tested
- [ ] Publish `@obinexusltd/tcl-polycall`
