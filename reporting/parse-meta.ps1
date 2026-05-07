<#
.SYNOPSIS
  Parse a saved Pipeboard get_insights MCP response file.
  Outputs JSON with two keys:
    byDate  — {date: {spend, reach, clicks, results}} — campaign-level daily totals
    byAdset — {name: {total: {spend,reach,clicks,results}, days: {date: {spend,reach,clicks}}}}

.PARAMETER FilePath
  Path to the saved MCP response JSON file.

.PARAMETER ResultAction
  The action_type to count as "results".
  BOF: start_trial_website
  TOF: thruplay

.EXAMPLE
  .\parse-meta.ps1 -FilePath "C:\...\bof-campaign.json" -ResultAction "start_trial_website"
#>
param(
    [Parameter(Mandatory)][string]$FilePath,
    [string]$ResultAction = 'start_trial_website'
)

$raw = Get-Content $FilePath -Raw -Encoding UTF8
$resp = $raw | ConvertFrom-Json

if (-not $resp.data) {
    Write-Error "No 'data' array found in response. Check file: $FilePath"
    exit 1
}

$byDate   = [ordered]@{}
$byAdset  = [ordered]@{}

foreach ($e in $resp.data) {
    $date   = $e.date_start
    $spend  = [double]($e.spend)
    $reach  = if ($e.reach)               { [int]($e.reach) }               else { 0 }
    $clicks = if ($e.inline_link_clicks)  { [int]($e.inline_link_clicks) }  else { 0 }

    $results = 0
    if ($e.actions) {
        foreach ($a in $e.actions) {
            if ($a.action_type -eq $ResultAction) {
                $results = [int]($a.value)
            }
        }
    }

    # Campaign-level date aggregate
    if (-not $byDate.ContainsKey($date)) {
        $byDate[$date] = @{ spend=0.0; reach=0; clicks=0; results=0 }
    }
    $byDate[$date].spend   += $spend
    $byDate[$date].reach   += $reach
    $byDate[$date].clicks  += $clicks
    $byDate[$date].results += $results

    # Adset breakdown (only present in adset-level responses)
    if ($e.adset_name) {
        $adset = $e.adset_name
        if (-not $byAdset.ContainsKey($adset)) {
            $byAdset[$adset] = @{
                total = @{ spend=0.0; reach=0; clicks=0; results=0 }
                days  = [ordered]@{}
            }
        }
        $byAdset[$adset].total.spend   += $spend
        $byAdset[$adset].total.reach   += $reach
        $byAdset[$adset].total.clicks  += $clicks
        $byAdset[$adset].total.results += $results
        $byAdset[$adset].days[$date]    = @{ spend=$spend; reach=$reach; clicks=$clicks }
    }
}

@{ byDate=$byDate; byAdset=$byAdset } | ConvertTo-Json -Depth 8
