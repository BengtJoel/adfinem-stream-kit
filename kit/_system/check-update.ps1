# AD FINEM Stream Kit - update check (Windows)
#   (no switch)  quiet check, at most every 12 hours; asks "Install now?" only if there is a new version
#   -Json        print {"current","latest","available","notes","page"} for the editor, no window
#   -Install     download the newest Setup and start it
#   -Force       check even if it was checked recently
param([switch]$Json, [switch]$Install, [switch]$Force)
$ErrorActionPreference = 'Stop'
$sys = $PSScriptRoot
$current = (Get-Content (Join-Path $sys 'version.txt') -ErrorAction SilentlyContinue | Select-Object -First 1)
if (-not $current) { $current = '0.0.0' }
$current = $current.Trim()
$cfg = Get-Content (Join-Path $sys 'update.json') -Raw | ConvertFrom-Json
$stateFile = Join-Path $sys 'update_state.json'

function Out-Status($o) { if ($Json) { $o | ConvertTo-Json -Compress } }
function ParseVer($v) { try { [version](($v -replace '^[vV]', '') -replace '[^0-9.].*$', '') } catch { [version]'0.0.0' } }

if (-not $Json -and -not $Install -and -not $Force -and (Test-Path $stateFile)) {
  try {
    $st = Get-Content $stateFile -Raw | ConvertFrom-Json
    if (((Get-Date) - [datetime]$st.lastCheck).TotalHours -lt 12) { exit 0 }
  } catch {}
}

try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$($cfg.repo)/releases/latest" `
         -Headers @{ 'User-Agent' = 'ADFINEM-StreamKit-Updater'; 'Accept' = 'application/vnd.github+json' } -TimeoutSec 15
} catch {
  Out-Status @{ ok = $false; current = $current; error = 'Could not reach GitHub' }
  exit 0
}
@{ lastCheck = (Get-Date).ToString('o') } | ConvertTo-Json | Set-Content $stateFile -Encoding UTF8

$latest = ($rel.tag_name -replace '^[vV]', '')
$available = (ParseVer $latest) -gt (ParseVer $current)
$notes = [string]$rel.body
if ($notes.Length -gt 600) { $notes = $notes.Substring(0, 600) + '...' }
$asset = $rel.assets | Where-Object { $_.name -eq $cfg.asset } | Select-Object -First 1

if ($Json) { Out-Status @{ ok = $true; current = $current; latest = $latest; available = $available; notes = $notes; page = $rel.html_url }; exit 0 }
if (-not $available) {
  if ($Force) { Add-Type -AssemblyName System.Windows.Forms; [void][System.Windows.Forms.MessageBox]::Show("You have the newest version ($current).", 'AD FINEM Stream Kit') }
  exit 0
}
if (-not $asset) { exit 0 }

if (-not $Install) {
  Add-Type -AssemblyName System.Windows.Forms
  $msg = "A new version of the AD FINEM Stream Kit is ready: $latest (you have $current).`n`n"
  if ($notes) { $msg += "What's new:`n$notes`n`n" }
  $msg += "Install it now? Your texts, sponsors and Twitch connection are kept.`nThe installer asks you to close OBS first."
  $ans = [System.Windows.Forms.MessageBox]::Show($msg, 'AD FINEM Stream Kit - update', 'YesNo', 'Information')
  if ($ans -ne 'Yes') { exit 0 }
}
$file = Join-Path $env:TEMP ("AD-FINEM-Stream-Kit-Setup-$latest.exe")
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $file -UseBasicParsing -Headers @{ 'User-Agent' = 'ADFINEM-StreamKit-Updater' }
Start-Process -FilePath $file
