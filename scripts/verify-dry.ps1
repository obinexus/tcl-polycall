$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$adapterPath = Join-Path $root 'src/tcl_polycall.c'
$extensionPath = Join-Path $root 'src/tcl_polycall_extension.c'
$forbidden = 'fopen|open\(|CreateFile|sscanf|strtok|socket\(|connect\('
$matches = Select-String -Path $adapterPath,$extensionPath -Pattern $forbidden

if ($matches) {
    $matches | ForEach-Object { Write-Error $_.Line }
    throw 'tcl-polycall must not parse configuration or implement runtime logic'
}

$adapter = Get-Content -Raw $adapterPath
$extension = Get-Content -Raw $extensionPath
if (-not $adapter.Contains('polycall_ffi_run_config(config_path, 1)')) {
    throw 'tcl-polycall does not forward through polycall_ffi_run_config'
}
if (-not $extension.Contains('Tcl_GetString(objv[1])')) {
    throw 'tcl-polycall does not marshal Tcl strings through Tcl_GetString'
}
if (-not $extension.Contains('Tcl_SetErrorCode(interp, "POLYCALL", "STATUS"')) {
    throw 'tcl-polycall does not expose structured Tcl error codes'
}

Write-Output 'tcl-polycall thin-adapter check: PASS'
