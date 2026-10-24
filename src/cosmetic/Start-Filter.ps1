#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:LOCALAPPDATA 'OutlookCosmeticFilter'
$nodePath = Join-Path $env:ProgramFiles 'nodejs\node.exe'
$runtimeFile = Join-Path $root 'runtime.json'
if (Test-Path -LiteralPath $runtimeFile) { $nodePath = (Get-Content -LiteralPath $runtimeFile -Raw | ConvertFrom-Json).nodePath }
if (-not (Test-Path -LiteralPath $nodePath)) { throw 'Node.js is not installed at the expected location.' }
$pidFile = Join-Path $root 'helper.pid'
if (Test-Path -LiteralPath $pidFile) {
    $helperId = 0
    if ([int]::TryParse((Get-Content -LiteralPath $pidFile -Raw), [ref]$helperId)) {
        $running = Get-CimInstance Win32_Process -Filter "ProcessId = $helperId" -ErrorAction SilentlyContinue
        if ($running -and $running.Name -eq 'node.exe' -and $running.CommandLine -like ('*' + (Join-Path $root 'helper.cjs') + '*')) { return }
    }
    # A previous Windows session may leave a PID that now belongs to another process.
    Remove-Item -LiteralPath $pidFile
}
Start-Process -FilePath $nodePath -ArgumentList ('"' + (Join-Path $root 'helper.cjs') + '"') -WindowStyle Hidden
