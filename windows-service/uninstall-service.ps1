<#
.SYNOPSIS
  Stops and removes the IDV API Showcase Windows service (installed via
  install-service.ps1).

.PARAMETER ServiceName
  Must match the name used at install time. Default: IDVApiShowcase.

.NOTES
  Must be run from an elevated (Administrator) PowerShell session. If it
  isn't, this script re-launches itself elevated.
#>

param(
    [string]$ServiceName = "IDVApiShowcase"
)

$ErrorActionPreference = "Stop"

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Not running elevated -- relaunching as Administrator..."
    # Single pre-quoted string, not an array -- see install-service.ps1 for why.
    $ArgLine = "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -ServiceName `"$ServiceName`""
    Start-Process powershell -Verb RunAs -ArgumentList $ArgLine
    exit
}

try {
    # See install-service.ps1 for why: native tools write routine diagnostics
    # to stderr, which Windows PowerShell turns into terminating errors under
    # $ErrorActionPreference = "Stop". Relax it here, check exit codes instead.
    $ErrorActionPreference = "Continue"

    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

    if (-not (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)) {
        Write-Host "Service '$ServiceName' is not installed -- nothing to remove."
        return
    }

    $Nssm = Join-Path $ScriptDir "nssm.exe"
    if (-not (Test-Path $Nssm)) {
        $found = Get-Command nssm.exe -ErrorAction SilentlyContinue
        if ($found) {
            $Nssm = $found.Source
        } else {
            Write-Warning "nssm.exe not found in `"$ScriptDir`" or PATH."
            Write-Warning "Falling back to sc.exe to remove the service registration."
            sc.exe stop $ServiceName | Out-Null
            sc.exe delete $ServiceName
            return
        }
    }

    Write-Host "Stopping and removing service '$ServiceName'..."
    & $Nssm stop $ServiceName 2>&1 | Out-Null
    & $Nssm remove $ServiceName confirm 2>&1 | Out-Null
    Write-Host "Done. '$ServiceName' has been removed."
}
catch {
    Write-Host ""
    Write-Host "UNINSTALL FAILED: $($_.Exception.Message)" -ForegroundColor Red
}
