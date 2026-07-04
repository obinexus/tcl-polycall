# @obinexusltd/tcl-polycall

Tcl 9 source binding for [libpolycall](https://github.com/obinexus/libpolycall).
It is a thin adapter: Tcl passes a configuration path to the native shim, and
the shim makes exactly one call to `polycall_ffi_run_config(config_path, 1)`.
Configuration parsing and runtime behavior remain in libpolycall.

## Install

```powershell
npm install @obinexusltd/tcl-polycall
```

The npm package publishes the C/Tcl source, headers, tests, examples, loader,
and build metadata. It does not publish a platform-specific DLL.

## Tcl API

After building the extension, add this package root to Tcl's `auto_path`:

```tcl
lappend auto_path C:/path/to/tcl-polycall
package require tcl-polycall 1.0.0

set status [::polycall::run_config C:/path/to/tcl-polycallrc]
::polycall::run_config_or_error C:/path/to/tcl-polycallrc
```

- `::polycall::run_config ?configPath?` returns the libpolycall status unchanged.
- `::polycall::run_config_or_error ?configPath?` returns `0` on success and
  raises a Tcl error with error code `POLYCALL STATUS <n>` on failure.
- Omitting `configPath` uses `tcl-polycallrc`.

Paths obtained with `Tcl_GetString` use Tcl's UTF-8 string representation.

## Build and test

The default build and tests do not need Tcl or a live libpolycall library:

```powershell
npm run build
npm test
```

`npm test` compiles the native adapter against a mock FFI, runs its contract
test, checks the Tcl 9 extension source against the available headers, audits
the thin boundary, and validates the npm package layout.

This repository defaults `TCL_ROOT` to the supplied Tcl 9.0.4 source tree:

```text
C:/ProgramData/tcl9.0.4
```

That directory currently contains headers and sources, not a built interpreter
or stub library. Build Tcl from its `win` directory first, then provide the
resulting stub library and your libpolycall linker flags:

```powershell
cd C:\ProgramData\tcl9.0.4\win
nmake -f makefile.vc release

cd C:\Users\OBINexus\Projects\libpolycall\tcl-polycall
make extension `
  TCL_ROOT=C:/ProgramData/tcl9.0.4 `
  TCL_STUB_LIB=C:/path/to/tclstub90.lib `
  POLYCALL_LDFLAGS="-LC:/path/to/libpolycall -lpolycall"
```

The output is `dist/tclpolycall.dll`. Set `TCLSH` and `TCL_STUB_LIB` to run the
Tcl-level mock test:

```powershell
make test-tcl `
  TCLSH=C:/path/to/tclsh90.exe `
  TCL_STUB_LIB=C:/path/to/tclstub90.lib
```

The Tcl extension intentionally uses the Tcl 9 `Tcl_Size` and
`Tcl_CreateObjCommand2` APIs found in the supplied 9.0.4 headers.

## Published directories

The CommonJS entry point indexes these project-relative directories:
`src`, `include`, `generated`, `dist`, `examples`, `tests`, and `scripts`.
Use `require('@obinexusltd/tcl-polycall').directories` to enumerate them, or
`resolve(directoryName, ...segments)` for traversal-safe path resolution.

## License

MIT © 2026 Nnamdi Michael Okpala (`okpalan@protonmail.com`).
