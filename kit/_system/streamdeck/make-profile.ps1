# Makes "AD FINEM.streamDeckProfile" in the kit folder from one of the ready-made templates.
#   -Dest     the kit folder (Documents\AD FINEM Stream Kit)
#   -Edition  retail | forever | both
# Uses the version where the keys show what OBS is doing (mic muted, scene on screen, live...) when
# Elgato's free "OBS Studio" plugin is installed in the Stream Deck app, otherwise plain key commands.
# Writes one line: "obs" or "keys" (or "none" if there is no template).
param([Parameter(Mandatory)][string]$Dest, [string]$Edition = 'retail')
$ErrorActionPreference = 'Stop'
$Edition = $(if ($Edition -match '^forever$') { 'forever' } elseif ($Edition -match '^both$') { 'both' } else { 'retail' })
$plugin = Join-Path $env:APPDATA 'Elgato\StreamDeck\Plugins\com.elgato.obsstudio.sdPlugin'
$mode = $(if (Test-Path $plugin) { 'obs' } else { 'keys' })
$tpl = Join-Path $Dest "_system\streamdeck\templates\$Edition-$mode"
if (-not (Test-Path $tpl)) { Write-Output 'none'; return }
$tmp = Join-Path $env:TEMP ('adfinem_sd_' + [guid]::NewGuid().ToString('N'))
Copy-Item $tpl $tmp -Recurse
$editor = Join-Path $Dest 'Customize overlays.exe'      # the Stream Deck's Open action runs .exe reliably, .bat not always
if (-not (Test-Path $editor)) { $editor = Join-Path $Dest 'Customize overlays.bat' }
# Stream Deck 7 reads "Open" as a command line: a path with spaces must be in quotes (as its own file picker saves it)
$editorPath = '\"' + $editor.Replace('\', '\\') + '\"'
Get-ChildItem $tmp -Recurse -Filter 'manifest.json' | ForEach-Object {
  $t = [IO.File]::ReadAllText($_.FullName).Replace('__EDITOR__', $editorPath)
  [IO.File]::WriteAllText($_.FullName, $t, (New-Object Text.UTF8Encoding $false))
}
$sdFile = Join-Path $Dest 'AD FINEM.streamDeckProfile'
if (Test-Path $sdFile) { Remove-Item $sdFile -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($tmp, $sdFile)
Remove-Item $tmp -Recurse -Force
Write-Output $mode
