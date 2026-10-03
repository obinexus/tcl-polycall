# tcl-polycall

Tcl 9 loadable extension for the [Polycall](https://github.com/obinexus/polycall)
core's **binding ABI v1** (`polycall.h`, libpolycall >= 1.1.0): configuration
validation, `polycall_rpc` calls and peer-to-peer nodes. Tcl package
`tcl-polycall` 1.1.0; npm source distribution `@obinexusltd/tcl-polycall`
(not published yet).

`src/tcl_polycall.c` is a stubs-enabled Tcl 9 extension that includes the real
`<polycall.h>` and links the core through pkg-config. Configuration parsing,
the wire protocols and the peer transport stay in libpolycall.

## Build and install

Requirements: Tcl 9 (`tclsh9.0`, headers and stub library: Debian/Ubuntu
`tcl9.0-dev`), a C11 compiler, make, pkg-config, and the Polycall core
>= 1.1.0 installed with its `polycall.pc`.

```sh
export PKG_CONFIG_PATH=/opt/polycall/lib/pkgconfig   # if the core is not in a system prefix
make                       # -> dist/tclpolycall.so (.dylib on macOS, .dll on Windows)
make install               # -> [lindex $tcl_pkgPath 0]/tcl-polycall1.1.0/{pkgIndex.tcl,tclpolycall.so}
make install DESTDIR=/tmp/stage TCL_PKG_DIR=/tcl
```

Tcl is located through `tclConfig.sh` (override `TCL_CONFIG`, or `TCL_CFLAGS`
and `TCL_STUB_LIB`); the core through `pkg-config polycall` (override
`POLYCALL_CFLAGS` / `POLYCALL_LIBS`). On Linux the extension is linked with
`-z now` and a RUNPATH to the core's libdir: a missing core, or an old 1.0
core without the ABI v1 symbols, makes `load` fail with a clear dynamic-loader
error, and `Tclpolycall_Init` refuses a core whose
`polycall_ffi_abi_version()` is not 1.

To use a checkout without installing: `make`, then
`lappend auto_path /path/to/tcl-polycall` (the root `pkgIndex.tcl` loads
`dist/tclpolycall[info sharedlibextension]`).

## Tcl API (namespace `::polycall`)

```tcl
package require tcl-polycall 1.1.0

polycall::abi_version                   ;# 1
polycall::version                       ;# 1.1.0
polycall::run_config tcl-polycallrc     ;# 0, or the raw status: polycall_ffi_run_config(path, 1)
polycall::run_config tcl-polycallrc 0   ;# run=0: unknown keys are warnings
polycall::run_config_or_error tcl-polycallrc
polycall::describe tcl-polycallrc       ;# JSON

# one polycall_rpc round trip to `polycall start` / `polycall daemon start`
polycall::call 127.0.0.1:8084 inventory get {{"item_id":"widget-a"}} 2000

set h [polycall::peer open alpha 127.0.0.1:0 $env(POLYCALL_DEV_TOKEN)]   ;# "" bind = send-only
polycall::peer register $h beta 127.0.0.1:9002
polycall::peer send $h beta [encoding convertto utf-8 "hello"] msg-1 5000
set m [polycall::peer recv $h 5000]     ;# dict: sender, message_id, payload (byte array)
polycall::peer recv $h forever          ;# until a message, cancel or close
polycall::peer ping $h beta;  polycall::peer list $h;  polycall::peer health $h
polycall::peer endpoint $h;  polycall::peer node_id $h;  polycall::peer unregister $h beta
polycall::peer cancel $h;  polycall::peer close $h
```

Payloads are byte arrays (binary-safe; use `encoding convertto utf-8` for
text). Failures raise a Tcl error whose `-errorcode` is
`{POLYCALL <POLYCALL_E_NAME> <status> <polycall_last_error> ?extra?}`, where
`extra` is the remote error object of `call` or the needed size of a
`peer recv` whose capacity was too small (the message stays queued). With the
`Thread` package a `peer recv` blocked in one thread is woken by
`peer cancel` / `peer close` from another.

## Tests

`tests/run-real-core.sh` builds the extension, installs it into a staging
package directory, and runs the tcltest suite (`tests/polycall.test`) with
`package require tcl-polycall` resolving to the installed copy, against the
**real installed core**: version/ABI, a missing core, an old core (missing
symbols) and an ABI 2 core in child interpreters, `run_config`, `call` against
a live `polycall start` runtime, two nodes both directions, payload matrix
(empty, UTF-8, binary + NUL, 1 MiB, 1 MiB + 1), registry ownership,
de-duplication, auth, dead peers, timeouts, small buffers, cancel and close
waking blocked receivers (Thread), handle lifecycle, concurrent senders in 8
threads, and interop with a `polycall peer serve` C node. A missing tclsh9.0,
make, pkg-config or core is reported as SKIP (exit 77), never as success.

```sh
sh tests/run-real-core.sh     # core in /opt/polycall, or POLYCALL_PREFIX / POLYCALL_LIBRARY
```

## License

MIT © 2026 Nnamdi Michael Okpala (`okpalan@protonmail.com`), see [LICENSE](LICENSE).
