<#
.SYNOPSIS
  Runs terraform plan and apply with timestamps and prints a timing report.
.DESCRIPTION
  The lab must not be deployed yet (the plan must contain changes).
  Raw logs and the report are saved in the timing folder.
#>
[CmdletBinding()]
param(
  [string]$PlanFile = 'main.tfplan'
)

$ErrorActionPreference = 'Continue'
Set-Location (Split-Path -Parent $PSScriptRoot)

if (-not $env:ARM_SUBSCRIPTION_ID) {
  $env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)
}
if (-not $env:ARM_SUBSCRIPTION_ID) {
  Write-Host 'Not signed in to Azure. Run az login first.' -ForegroundColor Red
  exit 1
}

$stamp      = (Get-Date).ToString('yyyyMMdd-HHmmss')
$outDir     = Join-Path (Get-Location) 'timing'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$planLog    = Join-Path $outDir "plan-$stamp.log"
$applyLog   = Join-Path $outDir "apply-$stamp.log"
$reportFile = Join-Path $outDir "report-$stamp.txt"

filter Add-Stamp {
  '{0}  {1}' -f [DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss.fff'), $_
}

function Format-Span([double]$Seconds) {
  $t = [TimeSpan]::FromSeconds([math]::Round($Seconds))
  if ($t.TotalHours -ge 1) { return '{0}h {1:00}m {2:00}s' -f [int]$t.TotalHours, $t.Minutes, $t.Seconds }
  return '{0}m {1:00}s' -f [int]$t.TotalMinutes, $t.Seconds
}

function ConvertTo-Seconds([string]$Text) {
  $s = 0
  if ($Text -match '(\d+)h') { $s += 3600 * [int]$Matches[1] }
  if ($Text -match '(\d+)m') { $s += 60 * [int]$Matches[1] }
  if ($Text -match '(\d+)s') { $s += [int]$Matches[1] }
  return $s
}

# ---- plan ----
Write-Host '== terraform plan ==' -ForegroundColor Cyan
$planStart = [DateTime]::UtcNow
terraform plan -no-color -detailed-exitcode -out $PlanFile 2>&1 | Add-Stamp | Tee-Object -FilePath $planLog
$planExit = $LASTEXITCODE
$planSeconds = ([DateTime]::UtcNow - $planStart).TotalSeconds

if ($planExit -eq 0) {
  Write-Host 'No changes: the lab is already deployed. Run terraform destroy first.' -ForegroundColor Yellow
  exit 0
}
if ($planExit -ne 2) {
  Write-Host "terraform plan failed (exit code $planExit)." -ForegroundColor Red
  exit 1
}

# ---- apply ----
Write-Host '== terraform apply ==' -ForegroundColor Cyan
$applyStart = [DateTime]::UtcNow
terraform apply -no-color $PlanFile 2>&1 | Add-Stamp | Tee-Object -FilePath $applyLog
$applyExit = $LASTEXITCODE
$applySeconds = ([DateTime]::UtcNow - $applyStart).TotalSeconds

if ($applyExit -ne 0) {
  Write-Host "terraform apply failed (exit code $applyExit). No report written." -ForegroundColor Red
  exit 1
}

# ---- parse the apply log ----
$rx = '^(?<ts>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3})\s+(?<res>\S+): (?:Creating\.\.\.|Creation complete after (?<dur>\S+))'
$items = @{}
foreach ($line in (Get-Content $applyLog)) {
  if ($line -match $rx) {
    $ts   = [DateTime]::ParseExact($Matches['ts'], 'yyyy-MM-dd HH:mm:ss.fff', [Globalization.CultureInfo]::InvariantCulture)
    $name = $Matches['res']
    $dur  = $Matches['dur']
    if (-not $items.ContainsKey($name)) {
      $items[$name] = [pscustomobject]@{ Resource = $name; Start = $null; End = $null; Seconds = 0 }
    }
    if ($dur) {
      $items[$name].End = $ts
      $items[$name].Seconds = ConvertTo-Seconds $dur
    } else {
      $items[$name].Start = $ts
    }
  }
}

$done = @($items.Values | Where-Object { $_.Start -and $_.End })
$rows = @($done | ForEach-Object {
  [pscustomobject]@{
    Resource = $_.Resource
    StartSec = [math]::Round(($_.Start - $applyStart).TotalSeconds)
    EndSec   = [math]::Round(($_.End - $applyStart).TotalSeconds)
    DurSec   = $_.Seconds
  }
})

$waitSec = ($rows | Where-Object { $_.Resource -like 'time_sleep.*' } | Measure-Object -Property DurSec -Sum).Sum
if (-not $waitSec) { $waitSec = 0 }

$longest = $rows | Sort-Object DurSec -Descending | Select-Object -First 6 |
  Select-Object Resource, @{ n = 'Duration'; e = { Format-Span $_.DurSec } } | Format-Table -AutoSize | Out-String
$timeline = $rows | Sort-Object StartSec |
  Select-Object Resource, @{ n = 'Start'; e = { Format-Span $_.StartSec } }, @{ n = 'End'; e = { Format-Span $_.EndSec } }, @{ n = 'Duration'; e = { Format-Span $_.DurSec } } |
  Format-Table -AutoSize | Out-String -Width 200

$report = @()
$report += 'Deployment timing report'
$report += ('Date (UTC):        ' + $applyStart.ToString('yyyy-MM-dd HH:mm'))
$report += ('Resources created: ' + $rows.Count)
$report += ('Plan:              ' + (Format-Span $planSeconds))
$report += ('Apply:             ' + (Format-Span $applySeconds))
$report += ('Total:             ' + (Format-Span ($planSeconds + $applySeconds)))
$report += ('Built-in waits:    ' + (Format-Span $waitSec) + ' (time_sleep resources, part of the apply)')
$report += ''
$report += 'Longest resources:'
$report += $longest
$report += 'Timeline (offsets from the start of the apply):'
$report += $timeline

Write-Host ''
$report | Tee-Object -FilePath $reportFile | ForEach-Object { Write-Host $_ }
Write-Host "Logs and report saved in $outDir" -ForegroundColor Green
