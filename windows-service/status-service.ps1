<#
.SYNOPSIS
  Quick check of whether the IDV API Showcase service is installed and running.
  No Administrator rights needed.

.PARAMETER ServiceName
  Must match the name used at install time. Default: IDVApiShowcase.
#>

param(
    [string]$ServiceName = "IDVApiShowcase"
)

$svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if (-not $svc) {
    Write-Host "Service '$ServiceName' is not installed. Run install-service.ps1 first."
    exit 1
}

Write-Host "Service '$ServiceName': $($svc.Status)  (StartType: $($svc.StartType))"
if ($svc.Status -eq "Running") {
    Write-Host "Should be reachable now -- check http://localhost:<port>/ (default port 8000)."
} else {
    Write-Host "Not running. Start it via: Start-Service $ServiceName  (or services.msc)"
}
