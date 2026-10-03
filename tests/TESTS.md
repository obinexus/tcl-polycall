# Tests

- `run-real-core.sh` — the real-core runner. Sources `real-core-env.sh`
  (locates the installed core, builds the loader-failure fixtures, starts a
  `polycall start` runtime and a `polycall daemon` on ephemeral ports, sets a
  random `POLYCALL_DEV_TOKEN`), runs `make` for `$TCLSH`'s Tcl (9.0 or 8.6)
  into a temporary build directory, `make install` into a staging package
  dir, builds a second copy without RUNPATH (Linux; for the "core missing"
  check), then `$TCLSH tests/all.tcl` (optionally under
  `TCL_POLYCALL_TEST_WRAPPER`, e.g. valgrind). Works on Linux and in an MSYS2
  UCRT64 shell on Windows (`TCLSH=tclsh86`). Exit 77 = SKIPPED (no tclsh /
  make / pkg-config / core, or any skipped test), never success.
- `all.tcl` — sources every `*.test` file; exits 1 on any failure, 77 when a
  test was skipped, 0 only when every test ran and passed (tcltest alone
  always exits 0).
- `polycall.test` — library (version, ABI, strerror, last_error, missing
  core, old core, ABI 2), config (valid / missing / invalid / strict unknown
  key / TLS / describe / non-ASCII path), call (success, unknown op, remote
  error, deadline, invalid input, no runtime, `polycall daemon`, timeout
  boundaries), peer
  (identity, both directions, payload matrix, registry ownership, duplicate
  id, auth, dead peer, timeout, too-small buffer, cancel / close waking
  blocked receivers in threads, handle lifecycle, invalid ids, 8 concurrent
  sender threads with backpressure retries), interop with
  `polycall peer serve` / CLI.
- `fixtures/fake_polycall.c` — loader-failure fixture only (old core, ABI 2).
- `package.test.js` — npm / Tcl package / binding-manifest metadata (no Tcl).
