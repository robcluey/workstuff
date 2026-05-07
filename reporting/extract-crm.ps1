<#
.SYNOPSIS
  Extract daily Cluey+ signup counts from the CRM CSV.
  Deduplicates by email (first occurrence by date). Filters obvious test signups.
  Outputs JSON: { "YYYY-MM-DD": count, ... }

.PARAMETER CsvPath
  Path to the Daily Report CSV.

.PARAMETER StartDate
  Optional ISO date (YYYY-MM-DD) — exclude signups before this date.

.PARAMETER EndDate
  Optional ISO date (YYYY-MM-DD) — exclude signups after this date.

.EXAMPLE
  .\extract-crm.ps1 -StartDate "2026-03-08" -EndDate "2026-05-07"
#>
param(
    [string]$CsvPath   = "C:\Users\RobNewman\OneDrive - Cluey\Email Attachments\Cluey+ Report\Daily Report.csv",
    [string]$StartDate = "",
    [string]$EndDate   = ""
)

if (-not (Test-Path $CsvPath)) {
    Write-Error "CSV not found: $CsvPath"
    exit 1
}

# CSV columns: Lead Source | Enrolment Name | Created Date | Last Source | Last Campaign Name | Email | Created Date
# Import-Csv auto-names the duplicate "Created Date" column — use index access to be safe.
$lines = Get-Content $CsvPath -Encoding UTF8
$header = ($lines[0] -split ',')
$rows = $lines[1..($lines.Count-1)] | ConvertFrom-Csv -Header $header

# Sort ascending by date for first-occurrence dedup
$rows = $rows | Sort-Object {
    try { [datetime]::Parse($_.'Created Date') } catch { [datetime]::MinValue }
}

$seen  = @{}
$daily = [ordered]@{}

foreach ($r in $rows) {
    $name  = $r.'Enrolment Name'.Trim()
    $email = $r.Email.Trim().ToLower()
    $raw   = $r.'Created Date'.Trim()

    # Filter obvious test signups
    if ($name  -match 'test test|namitest|namotest|nambo test|enrolment for test') { continue }
    if ($email -match '@clueylearning\.com|@cluey\.com\.au|^test\.')               { continue }
    if ($email -eq '')                                                               { continue }

    # Skip duplicate emails
    if ($seen.ContainsKey($email)) { continue }
    $seen[$email] = $true

    # Parse date
    try {
        $dt      = [datetime]::Parse($raw)
        $dateKey = $dt.ToString('yyyy-MM-dd')
    } catch { continue }

    # Apply date range filter
    if ($StartDate -and $dateKey -lt $StartDate) { continue }
    if ($EndDate   -and $dateKey -gt $EndDate)   { continue }

    if (-not $daily.ContainsKey($dateKey)) { $daily[$dateKey] = 0 }
    $daily[$dateKey]++
}

$daily | ConvertTo-Json
