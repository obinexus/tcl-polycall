# tcl-polycall

Tcl loadable extension (Tcl 9.0 and Tcl 8.6) for the [Polycall](https://github.com/obinexus/polycall)
core's **binding ABI v1** (`polycall.h`, libpolycall >= 1.1.0): configuration
validation, `polycall_rpc` calls and peer-to-peer nodes. Tcl package
`tcl-polycall` 1.1.0; npm source distribution `tcl-polycall`
(not published yet).

`src/tcl_polycall.c` is a stubs-enabled Tcl extension that includes the real
`<polycall.h>` and links the core through pkg-config. The same source builds
for Tcl 9.0 (the default) or Tcl 8.6 (`make TCL_VERSION=8.6`); a build loads
only into the Tcl major version it was compiled for. Configuration parsing,
the wire protocols and the peer transport stay in libpolycall.

Tested platforms: Linux x86_64 (Debian 13: Tcl 9.0.1 + Thread 3.0.1, Tcl
8.6.16 + Thread 2.8.11) and Windows x64 (MSYS2 UCRT64 GCC, Tcl 8.6.18 +
Thread 2.8.13, against both `libpolycall.dll` and the MSVC `polycall.dll`).
Tcl 9 on Windows and macOS are built by the same Makefile but not tested.

## Build and install

Requirements: Tcl 9.0 or 8.6 with headers and stub library (Debian/Ubuntu
`tcl9.0-dev` or `tcl8.6-dev`; the `Thread` package, `tcl9.0-thread` /
`tcl-thread`, for using peers from several threads), a C11 compiler, make,
pkg-config, and the Polycall core >= 1.1.0 installed with its `polycall.pc`.

```sh
export PKG_CONFIG_PATH=/opt/polycall/lib/pkgconfig   # if the core is not in a system prefix
make                       # -> dist/tclpolycall.so (.dylib on macOS, .dll on Windows)
make install               # -> [lindex $tcl_pkgPath 0]/tcl-polycall1.1.0/{pkgIndex.tcl,tclpolycall.so}
make install DESTDIR=/tmp/stage TCL_PKG_DIR=/tcl
make TCL_VERSION=8.6       # for tclsh8.6 (TCLSH=tclsh8.6)
```

Windows: from an MSYS2 UCRT64 (or MINGW64) shell with MSYS2's Tcl and the
core's UCRT64 build (`libpolycall.dll`, `lib/pkgconfig/polycall.pc`) — or the
MSVC build, whose `polycall.lib` GNU ld links directly:

```sh
export PKG_CONFIG_PATH=/c/path/to/polycall/lib/pkgconfig PATH=/c/path/to/polycall/bin:$PATH
make TCL_VERSION=8.6 TCLSH=tclsh86     # -> dist/tclpolycall.dll
```

The core's `bin` directory (its DLL) must be on `PATH` when Tcl loads the
extension.

Tcl is located through `tclConfig.sh` (override `TCL_CONFIG`, or `TCL_CFLAGS`
and `TCL_STUB_LIB`); the core through `pkg-config polycall` (override
`POLYCALL_CFLAGS` / `POLYCALL_LIBS`). On Linux the extension is linked with
`-z now` and a RUNPATH to the core's libdir; on Windows the import table
binds every core symbol at load time. A missing core, or an old 1.0 core
without the ABI v1 symbols, makes `load` fail with the loader's error (Linux
names the library or symbol; Windows only says a dependent library or an
imported function could not be found), and `Tclpolycall_Init` refuses a core
whose `polycall_ffi_abi_version()` is not 1.

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
text — a string with characters above U+00FF is refused, never truncated).
Strings (paths, ids, endpoints, JSON) cross to the core as UTF-8; Tcl 8.6
strings cannot hold characters outside the BMP (Tcl turns them into U+FFFD),
Tcl 9 can. On POSIX the core opens configuration paths byte for byte, which
matches the names Tcl creates in a UTF-8 locale; on Windows it converts the
UTF-8 path to UTF-16. Failures raise a Tcl error whose `-errorcode` is
`{POLYCALL <POLYCALL_E_NAME> <status> <polycall_last_error> ?extra?}`, where
`extra` is the remote error object of `call` or the needed size of a
`peer recv` whose capacity was too small (the message stays queued). With the
`Thread` package a `peer recv` blocked in one thread is woken by
`peer cancel` / `peer close` from another.

## Tests

`tests/run-real-core.sh` builds the extension for `$TCLSH`'s Tcl into a
temporary directory, installs it into a staging package directory, and runs
the tcltest suite (`tests/polycall.test`) with `package require tcl-polycall`
resolving to the installed copy, against the **real installed core**:
version/ABI, a missing core, an old core (missing symbols) and an ABI 2 core
in child interpreters, `run_config` (valid, missing, invalid, strict, TLS,
non-ASCII path), `call` against a live `polycall start` runtime and a
`polycall daemon`, timeout boundaries, two nodes both directions, payload matrix (empty, UTF-8,
binary + NUL, 1 MiB, 1 MiB + 1), registry ownership, de-duplication, auth,
dead peers, timeouts, small buffers, cancel and close waking blocked receivers
(Thread), handle lifecycle, concurrent senders in 8 threads, and interop with
a `polycall peer serve` C node. A missing tclsh, make, pkg-config or core, or
any skipped test, is reported as SKIP (exit 77), never as success.

```sh
sh tests/run-real-core.sh                     # tclsh9.0; core in /opt/polycall, or POLYCALL_PREFIX
TCLSH=tclsh8.6 sh tests/run-real-core.sh      # Tcl 8.6
TCL_POLYCALL_TEST_WRAPPER="valgrind --error-exitcode=99 --leak-check=full" sh tests/run-real-core.sh
# Windows, MSYS2 UCRT64 shell:
TCLSH=tclsh86 POLYCALL_PREFIX=/c/path/to/polycall sh tests/run-real-core.sh
```

## License

MIT © 2026 Nnamdi Michael Okpala (`okpalan@protonmail.com`), see [LICENSE](LICENSE).
