#!/usr/bin/env sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

if grep -E -n 'fopen|open\(|CreateFile|sscanf|strtok|socket\(|connect\(' \
    "$root/src/tcl_polycall.c" "$root/src/tcl_polycall_extension.c"; then
    echo "tcl-polycall must not parse configuration or implement runtime logic" >&2
    exit 1
fi

grep -F -q 'polycall_ffi_run_config(config_path, 1)' \
    "$root/src/tcl_polycall.c"
grep -F -q 'Tcl_GetString(objv[1])' \
    "$root/src/tcl_polycall_extension.c"
grep -F -q 'Tcl_SetErrorCode(interp, "POLYCALL", "STATUS"' \
    "$root/src/tcl_polycall_extension.c"

echo "tcl-polycall thin-adapter check: PASS"
