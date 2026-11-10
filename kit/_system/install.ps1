# AD FINEM Stream Kit - installer (Windows PowerShell 5.1+)
# Started by the Setup .exe (or INSTALL.bat). Safe to run again - also used for updates:
# your settings, sponsors, Twitch connection and the webcam/game/audio you picked in OBS are kept.
param(
  [switch]$Quiet,                 # no questions (updates, and the graphical setup)
  [string]$Camera = $null,        # webcam name as Windows shows it; '' = leave as it is
  [string]$Mic = $null,           # 'default', a Windows audio endpoint id, or '' = leave as it is
  [string]$MicFilters = $null,    # e.g. 'ns,gate,comp,limit'; 'none' = no kit filters; '' = leave as it is
  [string]$Edition = $null        # 'retail' or 'forever' (WoW Forever look); '' = keep the one installed
)

$ErrorActionPreference = 'Stop'
Remove-TypeData System.Array -ErrorAction SilentlyContinue      # PS 5.1: keeps arrays as arrays in ConvertTo-Json
try { $Host.UI.RawUI.WindowTitle = 'AD FINEM Stream Kit - Installer' } catch {}

# In -Quiet mode (graphical setup, updates) everything goes to stdout as @@ lines the setup window reads.
function Say($text, $color = 'Gray') { if ($Quiet) { Write-Output ("@@LOG " + $text.Trim()) } else { Write-Host $text -ForegroundColor $color } }
function Step($n, $text) { if ($Quiet) { Write-Output "@@STEP $n $text" } else { Write-Host ''; Write-Host "[$n] $text" -ForegroundColor DarkYellow } }
if ($Quiet) { try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {} }

# Update = new kit scenes, but keep what the streamer set up in OBS themselves.
function Set-Prop($obj, $name, $value) { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force }
function Merge-Collection([string]$newJson, [string]$oldJson) {
  $new = $newJson | ConvertFrom-Json
  $old = $oldJson | ConvertFrom-Json
  $userIds = @('dshow_input', 'game_capture', 'window_capture', 'monitor_capture', 'wasapi_input_capture', 'wasapi_output_capture',
               'wasapi_process_output_capture', 'v4l2_input', 'xcomposite_input', 'pipewire-screen-capture-source',
               'pipewire-desktop-capture-source', 'pipewire-window-capture-source', 'pipewire-camera-source',
               'pulse_input_capture', 'pulse_output_capture', 'av_capture_input', 'screen_capture')
  $oldBy = @{}; foreach ($s in @($old.sources)) { $oldBy[$s.name] = $s }
  # 1. the camera, game window and audio devices they picked
  foreach ($s in @($new.sources)) {
    $o = $oldBy[$s.name]
    if ($o -and $o.id -eq $s.id -and $userIds -contains $o.id) {
      foreach ($k in 'settings', 'volume', 'muted', 'filters', 'monitoring_type', 'mixers', 'sync', 'balance') {
        if ($o.PSObject.Properties[$k]) { Set-Prop $s $k $o.$k }
      }
    }
  }
  foreach ($p in @($old.PSObject.Properties)) { if ($p.Name -match '^(Desktop|Aux)AudioDevice\d$') { Set-Prop $new $p.Name $p.Value } }
  # 2. where they moved/resized the webcam and game
  $oldScenes = @{}; foreach ($s in @($old.sources)) { if ($s.id -eq 'scene') { $oldScenes[$s.name] = $s } }
  foreach ($s in @($new.sources)) {
    if ($s.id -ne 'scene' -or -not $oldScenes[$s.name]) { continue }
    foreach ($it in @($s.settings.items)) {
      $src = $oldBy[$it.name]
      if (-not $src -or $userIds -notcontains $src.id) { continue }
      $oi = @($oldScenes[$s.name].settings.items) | Where-Object { $_.name -eq $it.name } | Select-Object -First 1
      if ($oi) { foreach ($k in 'pos', 'scale', 'rot', 'bounds', 'bounds_type', 'bounds_align', 'align', 'crop_left', 'crop_top', 'crop_right', 'crop_bottom', 'visible') {
        if ($oi.PSObject.Properties[$k]) { Set-Prop $it $k $oi.$k } } }
    }
  }
  # 3. sources and scenes they added themselves (anything not named "AF ..." by the kit)
  $newNames = @{}; foreach ($s in @($new.sources)) { $newNames[$s.name] = $true }
  $extra = @(@($old.sources) | Where-Object { -not $newNames[$_.name] -and $_.name -notlike 'AF *' })
  if ($extra.Count) {
    $new.sources = @($new.sources) + $extra
    $order = @($new.scene_order | ForEach-Object { $_.name })
    foreach ($o in @($old.scene_order)) {
      if ($order -notcontains $o.name -and ($extra | Where-Object { $_.name -eq $o.name -and $_.id -eq 'scene' })) { $new.scene_order = @($new.scene_order) + $o }
    }
  }
  if ($old.groups) { $gNames = @($new.groups | ForEach-Object { $_.name }); $new.groups = @($new.groups) + @(@($old.groups) | Where-Object { $gNames -notcontains $_.name }) }
  # 4. their Stream Deck/hotkey changes for the kit's script, and their other scripts
  $oldScripts = @(); if ($old.modules -and $old.modules.'scripts-tool') { $oldScripts = @($old.modules.'scripts-tool') }
  $newScripts = @($new.modules.'scripts-tool')
  foreach ($ns in $newScripts) {
    $os = $oldScripts | Where-Object { $_.path -like '*adfinem-hotkeys.lua' } | Select-Object -First 1
    if ($ns.path -like '*adfinem-hotkeys.lua' -and $os) { Set-Prop $ns 'settings' $os.settings }
  }
  if ($old.modules) { foreach ($p in @($old.modules.PSObject.Properties)) { if (-not $new.modules.PSObject.Properties[$p.Name]) { Set-Prop $new.modules $p.Name $p.Value } } }
  $others = @($oldScripts | Where-Object { $_.path -notlike '*adfinem-hotkeys.lua' })
  if ($others.Count) { Set-Prop $new.modules 'scripts-tool' (@($newScripts) + $others) }
  $out = $new | ConvertTo-Json -Depth 100
  # sanity check before using it
  $chk = $out | ConvertFrom-Json
  if (@($chk.sources).Count -lt @(($newJson | ConvertFrom-Json).sources).Count -or -not $chk.scene_order) { throw 'merge check failed' }
  return $out
}

$src  = Split-Path -Parent $PSScriptRoot
$docs = [Environment]::GetFolderPath('MyDocuments')
$dest = Join-Path $docs 'AD FINEM Stream Kit'

Write-Host ''
Write-Host '  ===============================================' -ForegroundColor DarkYellow
Write-Host '     AD FINEM  -  STREAM KIT INSTALLER'           -ForegroundColor White
Write-Host '  ===============================================' -ForegroundColor DarkYellow
Say "  Installs to: $dest"

# The camera and microphone picked in the setup window, plus the mic clean-up filters.
function New-Filter($name, $id, $vid, $settings) {
  [pscustomobject]@{ name = $name; uuid = [guid]::NewGuid().ToString(); id = $id; versioned_id = $vid; settings = $settings
    mixers = 0; sync = 0; flags = 0; volume = 1.0; balance = 0.5; enabled = $true; muted = $false
    'push-to-mute' = $false; 'push-to-mute-delay' = 0; 'push-to-talk' = $false; 'push-to-talk-delay' = 0
    hotkeys = [pscustomobject]@{}; deinterlace_mode = 0; deinterlace_field_order = 0; monitoring_type = 0
    private_settings = [pscustomobject]@{} }
}
function Set-Devices([string]$json) {
  $c = $json | ConvertFrom-Json
  if ($Camera) {
    $cam = @($c.sources) | Where-Object { $_.id -eq 'dshow_input' } | Select-Object -First 1
    if ($cam) {
      $enc = $Camera.Replace('#', '#22').Replace(':', '#3A')
      if (-not $cam.settings) { Set-Prop $cam 'settings' ([pscustomobject]@{}) }
      Set-Prop $cam.settings 'video_device_id' ($enc + ':')
      Set-Prop $cam.settings 'active' $true
      Say "    Webcam: $Camera" 'Green'
    }
  }
  if ($Mic -or $MicFilters) {
    $aux = $c.AuxAudioDevice1
    if ($aux) {
      if ($Mic) { Set-Prop $aux.settings 'device_id' $Mic; Say "    Microphone: $(if ($Mic -eq 'default') { 'Windows default' } else { $Mic })" 'Green' }
      if ($MicFilters) {
        $kitIds = @('noise_suppress_filter', 'noise_gate_filter', 'compressor_filter', 'limiter_filter')
        $keep = @(@($aux.filters) | Where-Object { $_ -and $kitIds -notcontains $_.id })
        $list = @()
        $want = $MicFilters.Split(',') | ForEach-Object { $_.Trim() }
        if ($want -contains 'ns')    { $list += New-Filter 'Noise Suppression' 'noise_suppress_filter' 'noise_suppress_filter_v2' ([pscustomobject]@{ method = 'rnnoise'; suppress_level = -30 }) }
        if ($want -contains 'gate')  { $list += New-Filter 'Noise Gate' 'noise_gate_filter' 'noise_gate_filter' ([pscustomobject]@{ open_threshold = -26.0; close_threshold = -32.0; attack_time = 25; hold_time = 200; release_time = 150 }) }
        if ($want -contains 'comp')  { $list += New-Filter 'Compressor' 'compressor_filter' 'compressor_filter' ([pscustomobject]@{ ratio = 4.0; threshold = -18.0; attack_time = 6; release_time = 60; output_gain = 0.0 }) }
        if ($want -contains 'limit') { $list += New-Filter 'Limiter' 'limiter_filter' 'limiter_filter' ([pscustomobject]@{ threshold = -3.0; release_time = 60 }) }
        Set-Prop $aux 'filters' (@($list) + $keep)
        Say "    Mic filters: $(if ($list.Count) { ($list | ForEach-Object { $_.name }) -join ', ' } else { 'none' })" 'Green'
      }
    }
  }
  # the placeholder picture sits exactly where the webcam is
  foreach ($s in @($c.sources)) {
    if ($s.id -ne 'scene') { continue }
    $items = @($s.settings.items)
    $ph = $items | Where-Object { $_.name -eq 'AF Webcam Placeholder' } | Select-Object -First 1
    $wc = $items | Where-Object { $n = $_.name; @($c.sources) | Where-Object { $_.name -eq $n -and $_.id -eq 'dshow_input' } } | Select-Object -First 1
    if ($ph -and $wc) { foreach ($k in 'pos', 'scale', 'rot', 'bounds', 'bounds_type', 'bounds_align', 'align') { if ($wc.PSObject.Properties[$k]) { Set-Prop $ph $k $wc.$k } } }
  }
  return ($c | ConvertTo-Json -Depth 100)
}

# ---------------------------------------------------------------- 1. OBS
Step 1 'Checking for OBS Studio'
$obsExe = $null
$candidates = @(
  (Join-Path $env:ProgramFiles 'obs-studio\bin\64bit\obs64.exe'),
  (Join-Path ${env:ProgramFiles(x86)} 'Steam\steamapps\common\OBS Studio\bin\64bit\obs64.exe')
)
try {
  $reg = (Get-ItemProperty 'HKLM:\SOFTWARE\OBS Studio' -ErrorAction Stop).'(default)'
  if ($reg) { $candidates = @((Join-Path $reg 'bin\64bit\obs64.exe')) + $candidates }
} catch {}
foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { $obsExe = $c; break } }

$slobs = Test-Path (Join-Path $env:APPDATA 'slobs-client')
if ($obsExe) {
  Say "    Found: $obsExe" 'Green'
} elseif ($slobs) {
  Say '    Streamlabs Desktop found - you can use the kit there (see the end of this window).' 'Green'
} else {
  Say '    OBS Studio was not found.' 'Yellow'
  $ans = if ($Quiet) { 'N' } else { Read-Host '    Install OBS Studio now? (Y/N)' }
  if ($ans -match '^[YyJj]') {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
      winget install -e --id OBSProject.OBSStudio --accept-package-agreements --accept-source-agreements
      $obsExe = Join-Path $env:ProgramFiles 'obs-studio\bin\64bit\obs64.exe'
      if (-not (Test-Path $obsExe)) { $obsExe = $null }
    } else {
      Say '    winget is not available. Download OBS from https://obsproject.com and run this installer again.' 'Yellow'
      Start-Process 'https://obsproject.com/download'
    }
  } else {
    Say '    Skipped. The kit is still installed; install OBS later and run INSTALL.bat again.' 'Yellow'
  }
}

# ---------------------------------------------------------------- 2. OBS must be closed
Step 2 'Making sure OBS is closed'
$told = $false
while (Get-Process -Name obs64, obs32 -ErrorAction SilentlyContinue) {
  if ($Quiet) {
    if (-not $told) { Say '    OBS is open. Please close OBS - the update continues by itself.' 'Yellow'; Write-Output '@@OBS_OPEN'; $told = $true }
    Start-Sleep -Seconds 2
  } else {
    Say '    OBS is open. Please close OBS, then press Enter here.' 'Yellow'
    [void](Read-Host)
  }
}
Say '    OK' 'Green'
if ($told) { Write-Output '@@OBS_CLOSED' }

# ---------------------------------------------------------------- 3. copy the kit
Step 3 'Copying the kit'
if ((Resolve-Path $src).Path.TrimEnd('\') -ieq $dest.TrimEnd('\')) {
  Say '    Already running from the installed folder - nothing to copy.' 'Green'
} else {
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  $keepSettings = Test-Path (Join-Path $dest 'settings.js')
  $rcLog = Join-Path $env:TEMP 'adfinem_copy_log.txt'
  # /COPY:DT /DCOPY:T: copy data + timestamps only - attributes can't always be set in OneDrive folders
  robocopy "$src" "$dest" /E /R:2 /W:1 /COPY:DT /DCOPY:T /NP /XF 'settings.js' 'twitch_auth.js' "/LOG:$rcLog" | Out-Null
  $rc = $LASTEXITCODE
  # check every file arrived (robocopy can report "failed" for things that don't matter); fix any that didn't
  $bad = @()
  foreach ($f in Get-ChildItem $src -Recurse -File) {
    if ($f.Name -in 'settings.js', 'twitch_auth.js') { continue }
    $rel = $f.FullName.Substring($src.TrimEnd('\').Length).TrimStart('\')
    $d = Join-Path $dest $rel
    if (-not (Test-Path $d) -or (Get-Item $d).Length -ne $f.Length) {
      try {
        New-Item -ItemType Directory -Force -Path (Split-Path $d) | Out-Null
        if (Test-Path $d) { (Get-Item $d -Force).Attributes = 'Normal' }
        Copy-Item $f.FullName $d -Force
      } catch {}
      if (-not (Test-Path $d) -or (Get-Item $d).Length -ne $f.Length) { $bad += $rel }
    }
  }
  if ($bad.Count) { throw "Could not copy: $($bad -join ', '). Is a kit file open in another program? (details: $rcLog)" }
  if ($rc -ge 8) { Say "    (Copy reported warnings - all files checked and in place.)" 'Gray' }
  if ($keepSettings) {
    Say '    Updated the kit. Your own settings.js was kept.' 'Green'
  } else {
    Copy-Item (Join-Path $src 'settings.js') (Join-Path $dest 'settings.js')
    Say '    Copied.' 'Green'
  }
}

# ---- game edition: Retail (the kit as it is) or WoW Forever (files from editions\forever laid over it)
$edFile = Join-Path $dest '_system\edition.txt'
if (-not $Edition) { try { $Edition = (Get-Content $edFile -ErrorAction Stop | Select-Object -First 1).Trim() } catch {
  $Edition = 'retail'
  if (-not $Quiet) { $a = Read-Host '    Which game do you stream? R = Retail, F = WoW Forever'; if ($a -match '^[Ff]') { $Edition = 'forever' } }
} }
$Edition = $(if ($Edition -match '^forever$') { 'forever' } else { 'retail' })
function Set-Edition([string]$ed) {
  $edSrc = Join-Path $src 'editions\forever'
  if (-not (Test-Path $edSrc)) { $edSrc = Join-Path $dest 'editions\forever' }
  if (-not (Test-Path $edSrc)) { return }
  $bk = Join-Path $dest '_system\edition_backup'
  foreach ($f in Get-ChildItem $edSrc -Recurse -File) {
    $rel = $f.FullName.Substring($edSrc.TrimEnd('\').Length).TrimStart('\')
    if ($rel -like 'streamdeck_icons\*' -or $rel -eq 'texts.json') { continue }   # Stream Deck icons + standard texts are used separately
    $d = Join-Path $dest $rel; $b = Join-Path $bk $rel
    $isForever = (Test-Path $d) -and (Get-Item $d).Length -eq $f.Length
    if ($ed -eq 'forever') {
      if ($isForever) { continue }
      if (Test-Path $d) { New-Item -ItemType Directory -Force -Path (Split-Path $b) | Out-Null; Copy-Item $d $b -Force }   # keep the Retail file
      New-Item -ItemType Directory -Force -Path (Split-Path $d) | Out-Null
      Copy-Item $f.FullName $d -Force
    } elseif ($isForever) {
      $r = Join-Path $src $rel
      if ((Test-Path $r) -and (Get-Item $r).Length -ne $f.Length) { Copy-Item $r $d -Force }
      elseif (Test-Path $b) { Copy-Item $b $d -Force }
    }
  }
}
# the kit's standard texts mention Mythic raiding - swap them for neutral ones with WoW Forever
# (only texts still exactly as shipped; anything the streamer wrote themselves is left alone)
function Set-EditionTexts([string]$ed) {
  $map = Join-Path $dest 'editions\forever\texts.json'; $sf = Join-Path $dest 'settings.js'
  if (-not (Test-Path $map) -or -not (Test-Path $sf)) { return }
  $utf8 = New-Object Text.UTF8Encoding $false
  $txt = [IO.File]::ReadAllText($sf, $utf8); $orig = $txt
  foreach ($e in @([IO.File]::ReadAllText($map, $utf8) | ConvertFrom-Json)) {
    if ($ed -eq 'forever') { $from = $e.retail; $to = $e.forever } elseif ($e.back) { $from = $e.forever; $to = $e.retail } else { continue }
    $pat = '("' + [regex]::Escape($e.key) + '"\s*:\s*)"' + [regex]::Escape($from) + '"'
    $txt = [regex]::Replace($txt, $pat, { param($m) $m.Groups[1].Value + '"' + $to + '"' })
  }
  if ($txt -ne $orig) { [IO.File]::WriteAllText($sf, $txt, $utf8); Say '    Standard texts set for this game (your own texts were kept).' 'Gray' }
}
try {
  Set-Edition $Edition
  Set-EditionTexts $Edition
  New-Item -ItemType Directory -Force -Path (Split-Path $edFile) | Out-Null
  Set-Content -Path $edFile -Value $Edition -Encoding ASCII
  Say "    Look: $(if ($Edition -eq 'forever') { 'WoW Forever (gold + sapphire)' } else { 'Retail' })" 'Green'
} catch { Say "    (Could not switch the look: $($_.Exception.Message))" 'Yellow' }

$oldEditor = Join-Path $dest 'Customize overlays.html'          # replaced by "Customize overlays.bat"
if (Test-Path $oldEditor) { Remove-Item $oldEditor -Force }

# ---------------------------------------------------------------- 4. OBS scene collection
Step 4 'Adding the "AD FINEM" scene collection to OBS'
$scenesDir = Join-Path $env:APPDATA 'obs-studio\basic\scenes'
New-Item -ItemType Directory -Force -Path $scenesDir | Out-Null
$target = Join-Path $scenesDir 'AD_FINEM.json'
$freshCollection = -not (Test-Path $target)
if (Test-Path $target) {
  $bk = Join-Path $dest '_system\backup'
  New-Item -ItemType Directory -Force -Path $bk | Out-Null
  Copy-Item $target (Join-Path $bk ("AD_FINEM_" + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.json'))
  Say '    Replaced an earlier AD FINEM collection (backup in _system\backup).' 'Gray'
}
$template = [IO.File]::ReadAllText((Join-Path $dest '_system\obs_template.json'))
$kitPath  = $dest.Replace('\', '/')
$json     = $template.Replace('__KIT__', $kitPath)
if (Test-Path $target) {
  try {
    $merged = Merge-Collection $json ([IO.File]::ReadAllText($target))
    if ($merged) { $json = $merged; Say '    Kept your webcam, game capture, audio devices and your own scenes.' 'Green' }
  } catch { Say "    (Could not keep your old OBS picks: $($_.Exception.Message) - set webcam/game again.)" 'Yellow' }
}
if ($freshCollection -and -not $MicFilters) { $MicFilters = 'ns,gate,comp,limit' }   # new setups get a clean mic
try { $json = Set-Devices $json } catch { Say "    (Could not set camera/mic: $($_.Exception.Message) - pick them in OBS.)" 'Yellow' }
[IO.File]::WriteAllText($target, $json, (New-Object Text.UTF8Encoding $false))
Say "    Written: $target" 'Green'

# check that every file the scenes use is there
$missing = @()
foreach ($m in [regex]::Matches($json, '"(?:local_file|path)":\s*"([^"]+)"')) {
  $p = $m.Groups[1].Value.Replace('/', '\')
  if (-not (Test-Path $p)) { $missing += $p }
}
if ($missing.Count) {
  Say '    Note - these files are missing (those scenes will be empty until you add them):' 'Yellow'
  $missing | ForEach-Object { Say "      $_" 'Yellow' }
}

# ---------------------------------------------------------------- 5. shortcuts
Step 5 'Creating desktop shortcuts'
try {
  $desk = [Environment]::GetFolderPath('Desktop')
  $ws = New-Object -ComObject WScript.Shell
  $s1 = $ws.CreateShortcut((Join-Path $desk 'AD FINEM - Customize overlays.lnk'))
  $s1.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $s1.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File "' + (Join-Path $dest '_system\editor.ps1') + '"'
  $s1.WorkingDirectory = $dest
  $s1.IconLocation = (Join-Path $dest '_system\adfinem.ico') + ',0'
  $s1.Description = 'Change the texts on the AD FINEM stream overlays'
  $s1.WindowStyle = 7
  $s1.Save()
  $s2 = $ws.CreateShortcut((Join-Path $desk 'AD FINEM Stream Kit.lnk'))
  $s2.TargetPath = $dest; $s2.IconLocation = (Join-Path $dest '_system\adfinem.ico') + ',0'; $s2.Save()
  Say '    "AD FINEM - Customize overlays" and "AD FINEM Stream Kit" are on your desktop.' 'Green'
} catch { Say '    Could not create shortcuts (not a problem).' 'Yellow' }

# ---------------------------------------------------------------- 6. Stream Deck
Step 6 'Making the Stream Deck page'
try {
  $sdSrc = Join-Path $dest '_system\streamdeck\profile'
  if (Test-Path $sdSrc) {
    $tmp = Join-Path $env:TEMP ('adfinem_sd_' + [guid]::NewGuid().ToString('N'))
    Copy-Item $sdSrc $tmp -Recurse
    $fIcons = Join-Path $dest 'editions\forever\streamdeck_icons'
    if ($Edition -eq 'forever' -and (Test-Path $fIcons)) {
      Get-ChildItem $tmp -Recurse -Filter '*.png' | Where-Object { $_.Directory.Name -eq 'Images' } | ForEach-Object {
        $fi = Join-Path $fIcons $_.Name; if (Test-Path $fi) { Copy-Item $fi $_.FullName -Force } }
    }
    $editorPath = (Join-Path $dest 'Customize overlays.bat').Replace('\', '\\')
    Get-ChildItem $tmp -Recurse -Filter 'manifest.json' | ForEach-Object {
      $t = [IO.File]::ReadAllText($_.FullName).Replace('__EDITOR__', $editorPath)
      [IO.File]::WriteAllText($_.FullName, $t, (New-Object Text.UTF8Encoding $false))
    }
    $sdFile = Join-Path $dest 'AD FINEM.streamDeckProfile'
    if (Test-Path $sdFile) { Remove-Item $sdFile -Force }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($tmp, $sdFile)
    Remove-Item $tmp -Recurse -Force
    Say '    Have a Stream Deck? Double-click "AD FINEM.streamDeckProfile" in the kit folder.' 'Green'
  }
} catch { Say '    Could not make the Stream Deck page (not a problem).' 'Yellow' }

# ---------------------------------------------------------------- done
Write-Host ''
Write-Host '  ===============================================' -ForegroundColor DarkYellow
Write-Host '   DONE! In OBS:'                                   -ForegroundColor White
Write-Host '    1. Menu: Scene Collection > AD FINEM'
Write-Host '    2. Settings > Video: Base and Output = 1920x1080'
Write-Host '    3. Scene "AF - In-Game": double-click "Webcam (pick your camera)"'
Write-Host '       and choose your camera.'
Write-Host ''
Write-Host '   To change texts and set up alerts: double-click'
Write-Host '   "AD FINEM - Customize overlays" on your desktop, edit, click Save.'
Write-Host '   OBS updates by itself within a few seconds.'
if ($slobs) {
  Write-Host ''
  Write-Host '   STREAMLABS DESKTOP:' -ForegroundColor White
  Write-Host '    Scene Collections (top left) > Manage Scene Collections > Import'
  Write-Host '    > pick "AD FINEM" from OBS. Then see README.txt > STREAMLABS DESKTOP.'
}
Write-Host '  ===============================================' -ForegroundColor DarkYellow
Write-Host ''
if ($obsExe -and -not $Quiet) {
  $go = Read-Host 'Start OBS now? (Y/N)'
  if ($go -match '^[YyJj]') { Start-Process -FilePath $obsExe -WorkingDirectory (Split-Path $obsExe) }
}

if ($Quiet) { Write-Output '@@DONE' }
exit 0
