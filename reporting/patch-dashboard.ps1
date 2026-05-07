<#
.SYNOPSIS
  Replace the DATA section in clueyplus-dashboard.html with new JS content.
  Matches between the DATA and COLOURS comment markers.

.PARAMETER DashboardPath
  Path to clueyplus-dashboard.html.

.PARAMETER DataFile
  Path to a file containing the replacement JS data block (content between markers only).

.EXAMPLE
  .\patch-dashboard.ps1 -DataFile reporting\data\new-data.js
#>
param(
    [string]$DashboardPath = "C:\Users\RobNewman\Documents\workstuff\clueyplus-dashboard.html",
    [Parameter(Mandatory)][string]$DataFile
)

if (-not (Test-Path $DashboardPath)) {
    Write-Error "Dashboard not found: $DashboardPath"
    exit 1
}
if (-not (Test-Path $DataFile)) {
    Write-Error "Data file not found: $DataFile"
    exit 1
}

$html    = [System.IO.File]::ReadAllText($DashboardPath, [System.Text.Encoding]::UTF8)
$newData = [System.IO.File]::ReadAllText($DataFile,      [System.Text.Encoding]::UTF8).TrimEnd()

# Match everything between the DATA and COLOURS block-comment markers (inclusive of markers)
# Markers look like: // ── DATA ─────...  and  // ── COLOURS ─────...
# Using [^\n]* to handle the variable-length dash runs and em-dash characters
$pattern = '(?s)(// [^\n]*DATA[^\n]*\r?\n)(.+?)(\r?\n// [^\n]*COLOURS)'

if ($html -notmatch $pattern) {
    Write-Error "Could not locate DATA/COLOURS markers in $DashboardPath"
    exit 1
}

$updated = $html -replace $pattern, "`$1$newData`$3"

[System.IO.File]::WriteAllText($DashboardPath, $updated, [System.Text.Encoding]::UTF8)
Write-Host "Patched: $DashboardPath"
