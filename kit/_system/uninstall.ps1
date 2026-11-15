param([switch]$Quiet)
# Removes the AD FINEM scene collections (AD FINEM / AD FINEM Forever) from OBS and the desktop / Start menu shortcuts.
# Your kit folder (Documents\AD FINEM Stream Kit) is left alone - delete it yourself if you want.
$scenes = Join-Path $env:APPDATA 'obs-studio\basic\scenes\AD_FINEM.json'
$desk = [Environment]::GetFolderPath('Desktop')
$scenesF = Join-Path $env:APPDATA 'obs-studio\basic\scenes\AD_FINEM_Forever.json'
$items = @($scenes, $scenesF, (Join-Path $desk 'AD FINEM - Customize overlays.lnk'), (Join-Path $desk 'AD FINEM Stream Kit.lnk'),
           (Join-Path ([Environment]::GetFolderPath('Programs')) 'AD FINEM')) | Where-Object { Test-Path $_ }
if (-not $items) { Write-Host 'Nothing to remove.'; return }
Write-Host 'This will remove:'; $items | ForEach-Object { Write-Host "  $_" }
while (Get-Process -Name obs64 -ErrorAction SilentlyContinue) {
  if ($Quiet) { Write-Host 'Close OBS to finish removing the kit...' -ForegroundColor Yellow; Start-Sleep -Seconds 2 }
  else { Write-Host 'Close OBS first, then run this again.' -ForegroundColor Yellow; return }
}
if ($Quiet -or (Read-Host 'Continue? (Y/N)') -match '^[YyJj]') {
  $items | Remove-Item -Recurse; Write-Host 'Removed.' -ForegroundColor Green
  # the music channel: Spotify back to your normal output (VB-CABLE itself stays - other programs may use it)
  try { . (Join-Path $PSScriptRoot 'audio\af-audio.ps1'); if (Find-AfCable) { Reset-AfSpotify } } catch {}
}
