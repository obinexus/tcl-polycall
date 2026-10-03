# Tests

- `run-real-core.sh` — the real-core runner. Sources `real-core-env.sh`
  (locates the installed core, builds the loader-failure fixtures, starts a
  `polycall start` runtime, sets a random `POLYCALL_DEV_TOKEN`), runs `make`,
  `make install` into a staging package dir, builds a second copy without
  RUNPATH (for the "core missing" check), then `tclsh9.0 tests/all.tcl`.
  Exit 77 = SKIPPED (no tclsh9.0 / make / pkg-config / core), never success.
- `all.tcl` — sources every `*.test` file and exits non-zero on any failure
  (tcltest alone always exits 0).
- `polycall.test` — library (version, ABI, strerror, last_error, missing
  core, old core, ABI 2), config (valid / missing / invalid / strict unknown
  key / TLS / describe), call (success, unknown op, remote error, deadline,
  invalid input, no runtime), peer (identity, both directions, payload
  matrix, registry ownership, duplicate id, auth, dead peer, timeout,
  too-small buffer, cancel / close waking blocked receivers in threads,
  handle lifecycle, invalid ids, 8 concurrent sender threads with
  backpressure retries), interop with `polycall peer serve` / CLI.
- `fixtures/fake_polycall.c` — loader-failure fixture only (old core, ABI 2).
- `package.test.js` — npm / Tcl package / binding-manifest metadata (no Tcl).
