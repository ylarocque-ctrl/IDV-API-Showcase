<#
.SYNOPSIS
  Installs the IDV API Showcase demo server as a Windows service using NSSM.

.DESCRIPTION
  Wraps `python -m http.server <port>` (served from this project's root folder,
  the parent of windows-service\) as a Windows service, so the demo app is
  reachable at http://localhost:<port> automatically at boot -- no terminal,
  no manual "python -m http.server" step.

  The service is configured to auto-start and to restart itself if the Python
  process ever exits unexpectedly.

.PARAMETER Port
  Port for the local HTTP server. Default: 8000. Must match what you use to
  browse to the app (e.g. http://localhost:8000).

.PARAMETER ServiceName
  Windows service name shown in services.msc. Default: IDVApiShowcase.

.NOTES
  Requires NSSM (https://nssm.cc/download) -- download the zip, and copy the
  nssm.exe matching your system (win64 folder, usually) into this same
  windows-service\ folder. Or, if nssm.exe is already on PATH, this script
  will find it there instead.

  Must be run from an elevated (Administrator) PowerShell session. If it
  isn't, this script re-launches itself elevated (you'll see a UAC prompt).
#>

param(
    [int]$Port = 8000,
    [string]$ServiceName = "IDVApiShowcase"
)

$ErrorActionPreference = "Stop"

# --- Re-launch elevated if needed ------------------------------------------
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Not running elevated -- relaunching as Administrator..."
    # Built as ONE string, not an array: Start-Process -ArgumentList arrays are
    # joined/quoted inconsistently across PowerShell versions and mangle paths
    # that contain spaces (this project's folder does). A single pre-quoted
    # string is the reliable form. -NoExit keeps the elevated window open so
    # you can actually read the result instead of it flashing shut.
    $ArgLine = "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Port $Port -ServiceName `"$ServiceName`""
    Start-Process powershell -Verb RunAs -ArgumentList $ArgLine
    exit
}

try {
    # Native tools like nssm.exe write routine diagnostics to stderr even for
    # expected "nothing to do" cases (e.g. stopping a service that doesn't
    # exist yet). Windows PowerShell treats any stderr line from a native
    # command as an error, and with $ErrorActionPreference = "Stop" (set
    # above) that becomes a terminating exception -- so we relax it here and
    # check exit codes explicitly instead, only for the nssm/native calls.
    $ErrorActionPreference = "Continue"

    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $AppDir    = Split-Path -Parent $ScriptDir   # project root = parent of windows-service\

    # --- Locate nssm.exe: this folder first, then PATH -------------------------
    $Nssm = Join-Path $ScriptDir "nssm.exe"
    if (-not (Test-Path $Nssm)) {
        $found = Get-Command nssm.exe -ErrorAction SilentlyContinue
        if ($found) {
            $Nssm = $found.Source
        } else {
            throw "nssm.exe not found. Download it from https://nssm.cc/download, copy nssm.exe (win64) into `"$ScriptDir`", then re-run this script."
        }
    }

    # --- Locate python.exe -------------------------------------------------------
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
    if (-not $python) {
        throw "Python was not found on PATH. Install Python (or add it to PATH), then re-run this script."
    }
    $PythonExe = $python.Source

    # The 'py' launcher needs an explicit -3; a real python.exe does not.
    $PyArgs = if ($PythonExe -match 'py\.exe$') { "-3 -m http.server $Port" } else { "-m http.server $Port" }

    Write-Host ""
    Write-Host "Service name : $ServiceName"
    Write-Host "Python       : $PythonExe"
    Write-Host "App folder   : $AppDir"
    Write-Host "Port         : $Port"
    Write-Host ""

    # --- Clean up a previous install of the same name, so re-runs are idempotent.
    # Only touch nssm stop/remove if the service actually exists -- calling
    # them on a name that isn't registered is exactly what produces nssm's
    # "Can't open service!" message.
    if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
        Write-Host "Existing '$ServiceName' service found -- stopping and removing it first..."
        & $Nssm stop $ServiceName 2>&1 | Out-Null
        & $Nssm remove $ServiceName confirm 2>&1 | Out-Null
    }

    # --- Install ------------------------------------------------------------
    & $Nssm install $ServiceName $PythonExe $PyArgs
    if ($LASTEXITCODE -ne 0) { throw "nssm install failed (exit code $LASTEXITCODE)." }
    & $Nssm set $ServiceName AppDirectory $AppDir
    & $Nssm set $ServiceName DisplayName "IDV API Showcase - Demo Server"
    & $Nssm set $ServiceName Description "Serves the IDV API Showcase demo app (index.html + config.json) at http://localhost:$Port for Quadient File Manager API demos."
    & $Nssm set $ServiceName Start SERVICE_AUTO_START

    # Restart automatically if the Python process ever exits
    & $Nssm set $ServiceName AppExit Default Restart
    & $Nssm set $ServiceName AppRestartDelay 3000

    # Logs -- handy for troubleshooting a demo that "just stopped working"
    $LogDir = Join-Path $AppDir "logs"
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
    & $Nssm set $ServiceName AppStdout (Join-Path $LogDir "service-out.log")
    & $Nssm set $ServiceName AppStderr (Join-Path $LogDir "service-err.log")
    & $Nssm set $ServiceName AppRotateFiles 1
    & $Nssm set $ServiceName AppRotateOnline 1
    & $Nssm set $ServiceName AppRotateSeconds 86400
    & $Nssm set $ServiceName AppRotateBytes 1048576

    & $Nssm start $ServiceName
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Warning: 'nssm start' returned exit code $LASTEXITCODE -- check the status and logs below." -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 1
    & $Nssm status $ServiceName

    Write-Host ""
    Write-Host "Done. Open http://localhost:$Port and check the config badge."
    Write-Host "Manage the service via services.msc, or: nssm status $ServiceName"
    Write-Host "Logs: $LogDir"
}
catch {
    Write-Host ""
    Write-Host "INSTALL FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "(This window was kept open with -NoExit so you can read this. Fix the issue above and re-run.)" -ForegroundColor Yellow
}
