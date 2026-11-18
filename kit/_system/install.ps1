# AD FINEM Stream Kit - installer (Windows PowerShell 5.1+)
# Started by the Setup .exe (or INSTALL.bat). Safe to run again - also used for updates:
# your settings, sponsors, Twitch connection and the webcam/game/audio you picked in OBS are kept.
param(
  [switch]$Quiet,                 # no questions (updates, and the graphical setup)
  [string]$Camera = $null,        # webcam name as Windows shows it; '' = leave as it is
  [string]$Mic = $null,           # 'default', a Windows audio endpoint id, or '' = leave as it is
  [string]$MicFilters = $null,    # e.g. 'ns,gate,comp,limit'; 'none' = no kit filters; '' = leave as it is
  [string]$Edition = $null,       # 'retail', 'monogram' (Retail, Monogram look), 'forever' (WoW Forever look), 'both' / 'both-monogram' (two OBS scene collections); '' = keep the one installed
  [string]$Music = 'auto'         # 'auto': stream music channel (VB-CABLE + Spotify + "AF Music" in OBS); 'off': leave audio alone
)

$ErrorActionPreference = 'Stop'
Remove-TypeData System.Array -ErrorAction SilentlyContinue      # PS 5.1: keeps arrays as arrays in ConvertTo-Json
try { $Host.UI.RawUI.WindowTitle = 'AD FINEM Stream Kit - Installer' } catch {}

# In -Quiet mode (graphical setup, updates) everything goes to stdout as @@ lines the setup window reads.
# Straight to stdout, NOT the PowerShell pipeline: Say is also used inside functions that return the scene
# collection, and pipeline output would end up inside the JSON file (OBS then can't read it).
function Say($text, $color = 'Gray') { if ($Quiet) { [Console]::Out.WriteLine("@@LOG " + $text.Trim()); [Console]::Out.Flush() } else { Write-Host $text -ForegroundColor $color } }
function Step($n, $text) { if ($Quiet) { [Console]::Out.WriteLine("@@STEP $n $text"); [Console]::Out.Flush() } else { Write-Host ''; Write-Host "[$n] $text" -ForegroundColor DarkYellow } }
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
  # "AF Music": the stream music channel (VB-CABLE's CABLE Output) as an extra OBS audio device, so it is in
  # every scene. The kit's OBS script decides if you hear it (Stream Deck "Music" key / hotkey).
  if ($script:musicDevice) {
    $slots = 'AuxAudioDevice2', 'AuxAudioDevice3', 'AuxAudioDevice4'
    $slot = $slots | Where-Object { $c.PSObject.Properties[$_] -and $c.$_.name -eq 'AF Music' } | Select-Object -First 1
    if (-not $slot) { $slot = $slots | Where-Object { -not $c.PSObject.Properties[$_] } | Select-Object -First 1 }
    if ($slot) {
      if ($c.PSObject.Properties[$slot]) { $m = $c.$slot; Set-Prop $m.settings 'device_id' $script:musicDevice }
      else {
        $m = New-Filter 'AF Music' 'wasapi_input_capture' 'wasapi_input_capture' ([pscustomobject]@{ device_id = $script:musicDevice })
        Set-Prop $m 'mixers' 255; Set-Prop $m 'volume' 0.35; Set-Prop $m 'monitoring_type' 1; Set-Prop $m 'filters' @()
        Set-Prop $c $slot $m
      }
      Say '    Music channel "AF Music" is in every scene (Spotify plays into it).' 'Green'
    } else { Say '    (All extra OBS audio slots are in use - "AF Music" was not added.)' 'Yellow' }
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
    if (-not $told) { Say '    OBS is open. Please close OBS - the update continues by itself.' 'Yellow'; [Console]::Out.WriteLine('@@OBS_OPEN'); $told = $true }
    Start-Sleep -Seconds 2
  } else {
    Say '    OBS is open. Please close OBS, then press Enter here.' 'Yellow'
    [void](Read-Host)
  }
}
Say '    OK' 'Green'
if ($told) { [Console]::Out.WriteLine('@@OBS_CLOSED') }

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
  if (-not $Quiet) { $a = Read-Host '    Which look? R = Retail, M = Retail (Monogram look), F = WoW Forever, B = both (Retail + Forever)'; if ($a -match '^[Ff]') { $Edition = 'forever' } elseif ($a -match '^[Mm]') { $Edition = 'monogram' } elseif ($a -match '^[Bb]') { $Edition = 'both' } }
} }
$Edition = $Edition.ToLower()
$Edition = $(if ($Edition -in 'forever', 'monogram', 'both', 'both-monogram') { $Edition } else { 'retail' })
# which edition folder is laid over the kit itself: Forever, Monogram, or nothing (Retail).
# "both-monogram" = the AD FINEM collection in the Monogram look + the AD FINEM Forever collection.
$script:Looks = @('forever', 'monogram')
function Get-EdSrc([string]$name) {
  $e = Join-Path $src "editions\$name"; if (-not (Test-Path $e)) { $e = Join-Path $dest "editions\$name" }
  if (Test-Path $e) { $e } else { $null }
}
function Get-EdFiles([string]$edSrc) {
  foreach ($f in Get-ChildItem $edSrc -Recurse -File) {
    $rel = $f.FullName.Substring($edSrc.TrimEnd('\').Length).TrimStart('\')
    if ($rel -like 'streamdeck_icons\*' -or $rel -eq 'texts.json') { continue }   # Stream Deck icons + standard texts are used separately
    [pscustomobject]@{ File = $f; Rel = $rel }
  }
}
function Set-Edition([string]$ed) {
  $bk = Join-Path $dest '_system\edition_backup'
  # 1) put the Retail files back wherever another look is installed (so looks never stack)
  foreach ($name in $script:Looks) {
    if ($name -eq $ed) { continue }
    $edSrc = Get-EdSrc $name; if (-not $edSrc) { continue }
    foreach ($e in Get-EdFiles $edSrc) {
      $d = Join-Path $dest $e.Rel; $b = Join-Path $bk $e.Rel
      if (-not ((Test-Path $d) -and (Get-Item $d).Length -eq $e.File.Length)) { continue }
      $r = Join-Path $src $e.Rel
      if ((Test-Path $r) -and (Get-Item $r).Length -ne $e.File.Length) { Copy-Item $r $d -Force }
      elseif (Test-Path $b) { Copy-Item $b $d -Force }
    }
  }
  # 2) lay the chosen look over the kit (the Retail file is kept in _system\edition_backup)
  if ($ed -notin $script:Looks) { return }
  $edSrc = Get-EdSrc $ed; if (-not $edSrc) { return }
  foreach ($e in Get-EdFiles $edSrc) {
    $d = Join-Path $dest $e.Rel; $b = Join-Path $bk $e.Rel
    if ((Test-Path $d) -and (Get-Item $d).Length -eq $e.File.Length) { continue }
    if ((Test-Path $d) -and -not (Test-Path $b)) { New-Item -ItemType Directory -Force -Path (Split-Path $b) | Out-Null; Copy-Item $d $b -Force }   # keep the Retail file
    New-Item -ItemType Directory -Force -Path (Split-Path $d) | Out-Null
    Copy-Item $e.File.FullName $d -Force
  }
}
# Retail + Forever side by side: "<overlay>-forever.html" copies that load the Forever colours, emblem and alert
function New-ForeverOverlays {
  $ov = Join-Path $dest 'overlays'
  foreach ($n in 'starting', 'brb', 'ending', 'ingame', 'alerts', 'sponsors') {
    $f = Join-Path $ov "$n.html"; if (-not (Test-Path $f)) { continue }
    $t = [IO.File]::ReadAllText($f, (New-Object Text.UTF8Encoding $false))
    $t = $t.Replace('<script src="../settings.js"></script>', '<script>window.AF_SETTINGS_SRC = "../settings-forever.js";</script><script src="../settings-forever.js"></script>')
    # the Forever copies use only the Forever colours (the kit's own edition.css may be the Monogram look)
    $t = $t.Replace('<link rel="stylesheet" href="edition.css">', '<link rel="stylesheet" href="../editions/forever/overlays/edition.css">')
    $t = $t.Replace('"img/adfinem-emblem-gradient.svg"', '"../editions/forever/overlays/img/adfinem-emblem-gradient.svg"')
    $t = $t.Replace('"img/webcam_placeholder.jpg"', '"../editions/forever/overlays/img/webcam_placeholder.jpg"')
    $t = $t.Replace('"../videos/alert_1x1_alpha.webm"', '"../editions/forever/videos/alert_1x1_alpha.webm"')
    [IO.File]::WriteAllText((Join-Path $ov "$n-forever.html"), $t, (New-Object Text.UTF8Encoding $false))
  }
}

# the kit's standard texts mention Mythic raiding - swap them for neutral ones with WoW Forever
# (only texts still exactly as shipped; anything the streamer wrote themselves is left alone)
function Set-EditionTexts([string]$ed, [string]$sf = $null) {
  $map = Join-Path $dest 'editions\forever\texts.json'; if (-not $sf) { $sf = Join-Path $dest 'settings.js' }
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
  # both: the kit itself stays Retail, the Forever collection uses its own copies (below);
  # (each with its own settings file)
  Set-Edition $(if ($Edition -eq 'both') { 'retail' } elseif ($Edition -eq 'both-monogram') { 'monogram' } else { $Edition })
  if ($Edition -like 'both*') {
    # each collection gets its own settings: settings.js (Retail) and settings-forever.js (WoW Forever)
    $sfF = Join-Path $dest 'settings-forever.js'
    if (-not (Test-Path $sfF) -and (Test-Path (Join-Path $dest 'settings.js'))) { Copy-Item (Join-Path $dest 'settings.js') $sfF }
    Set-EditionTexts 'forever' $sfF
    Set-EditionTexts 'retail'
    New-ForeverOverlays
  } else { Set-EditionTexts $Edition }
  [IO.File]::WriteAllText((Join-Path $dest '_system\edition.js'), "window.AF_EDITION = `"$Edition`";`n", (New-Object Text.UTF8Encoding $false))
  New-Item -ItemType Directory -Force -Path (Split-Path $edFile) | Out-Null
  Set-Content -Path $edFile -Value $Edition -Encoding ASCII
  Say "    Look: $(@{ forever = 'WoW Forever (gold + sapphire)'; both = 'Retail AND WoW Forever (two scene collections)'; 'both-monogram' = 'Retail in the Monogram look AND WoW Forever (two scene collections)'; monogram = 'Retail - Monogram look'; retail = 'Retail' }[$Edition])" 'Green'
} catch { Say "    (Could not switch the look: $($_.Exception.Message))" 'Yellow' }

$oldEditor = Join-Path $dest 'Customize overlays.html'          # replaced by "Customize overlays.bat"
if (Test-Path $oldEditor) { Remove-Item $oldEditor -Force }

# ---------------------------------------------------------------- 4. OBS scene collection
Step 4 'Adding the AD FINEM scene collection to OBS'
# Music for the stream: VB-CABLE (free, from vb-audio.com) is the "cable" Spotify plays into. OBS puts it on
# the stream and plays it in your headphones only when you want (the Music key).
$script:musicDevice = $null
if ($Music -ne 'off' -and [Environment]::OSVersion.Version.Build -ge 19041) {
  try {
    . (Join-Path $dest '_system\audio\af-audio.ps1')
    $log = { param($t) Say "    $t" }
    if (-not (Find-AfCable)) { [void](Install-AfCable -Log $log) }
    $cable = Find-AfCable
    Repair-AfDefaults -Log $log           # the cable must never be your default speaker or microphone
    if ($cable) {
      $script:musicDevice = $cable.Output
      [void](Set-AfSpotifyToCable -Log $log)
    }
  } catch { Say "    (Music channel skipped: $($_.Exception.Message))" 'Yellow' }
}
$scenesDir = Join-Path $env:APPDATA 'obs-studio\basic\scenes'
New-Item -ItemType Directory -Force -Path $scenesDir | Out-Null
$template = [IO.File]::ReadAllText((Join-Path $dest '_system\obs_template.json'))
$kitPath  = $dest.Replace('\', '/')
$base     = $template.Replace('__KIT__', $kitPath)
function Get-JsonOnly($out) {   # the collection JSON from a function's output (drops any stray lines before it)
  $t = (@($out) | ForEach-Object { "$_" }) -join "`n"
  $i = $t.IndexOf('{'); if ($i -gt 0) { $t = $t.Substring($i) }
  [void]($t | ConvertFrom-Json)    # throws if it is not valid - then the file is not written
  return $t
}
function Write-Collection([string]$fileName, [string]$json) {
  $target = Join-Path $scenesDir $fileName
  $fresh = -not (Test-Path $target)
  if (-not $fresh) {
    $bk = Join-Path $dest '_system\backup'
    New-Item -ItemType Directory -Force -Path $bk | Out-Null
    Copy-Item $target (Join-Path $bk ($fileName.Replace('.json', '') + '_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.json'))
    try {
      $merged = Get-JsonOnly (Merge-Collection $json (Get-JsonOnly ([IO.File]::ReadAllText($target))))
      if ($merged) { $json = $merged; Say '    Kept your webcam, game capture, audio devices and your own scenes.' 'Green' }
    } catch { Say "    (Could not keep your old OBS picks: $($_.Exception.Message) - set webcam/game again.)" 'Yellow' }
  }
  if ($fresh -and -not $MicFilters) { $MicFilters = 'ns,gate,comp,limit' }   # new setups get a clean mic
  try { $json = Get-JsonOnly (Set-Devices $json) } catch { Say "    (Could not set camera/mic: $($_.Exception.Message) - pick them in OBS.)" 'Yellow' }
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
}
Write-Collection 'AD_FINEM.json' $base
$fTarget = Join-Path $scenesDir 'AD_FINEM_Forever.json'
if ($Edition -like 'both*') {
  # second collection "AD FINEM Forever": same scenes, Forever videos, colours and webcam picture
  $fj = ([regex]'"name":\s*"AD FINEM"').Replace($base, '"name": "AD FINEM Forever"', 1)
  $fj = $fj.Replace("$kitPath/videos/", "$kitPath/editions/forever/videos/")
  $fj = $fj.Replace("$kitPath/overlays/img/webcam_placeholder.jpg", "$kitPath/editions/forever/overlays/img/webcam_placeholder.jpg")
  foreach ($n in 'starting', 'brb', 'ending', 'ingame', 'alerts', 'sponsors') { $fj = $fj.Replace("$kitPath/overlays/$n.html", "$kitPath/overlays/$n-forever.html") }
  Write-Collection 'AD_FINEM_Forever.json' $fj
  Say '    In OBS: Scene Collection > "AD FINEM" (Retail) or "AD FINEM Forever".' 'Green'
} elseif (Test-Path $fTarget) {   # switched away from "both": put the Forever collection away (backup kept)
  $bk = Join-Path $dest '_system\backup'; New-Item -ItemType Directory -Force -Path $bk | Out-Null
  Move-Item $fTarget (Join-Path $bk ('AD_FINEM_Forever_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.json')) -Force
  Say '    Removed the "AD FINEM Forever" collection (backup in _system\backup).' 'Gray'
}

# ---------------------------------------------------------------- 5. shortcuts
Step 5 'Creating shortcuts (desktop + Start menu)'
try {
  $ws = New-Object -ComObject WScript.Shell
  $ico = (Join-Path $dest '_system\adfinem.ico') + ',0'
  $edExe = Join-Path $dest 'Customize overlays.exe'
  function New-EditorLink($path) {
    $s = $ws.CreateShortcut($path)
    if (Test-Path $edExe) { $s.TargetPath = $edExe; $s.Arguments = '' }   # no console window
    else {
      $s.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
      $s.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File "' + (Join-Path $dest '_system\editor.ps1') + '"'
      $s.WindowStyle = 7
    }
    $s.WorkingDirectory = $dest; $s.IconLocation = $ico
    $s.Description = 'Change texts, alerts, goal and sponsors on the AD FINEM stream overlays'
    $s.Save()
  }
  function New-FolderLink($path) { $s = $ws.CreateShortcut($path); $s.TargetPath = $dest; $s.IconLocation = $ico; $s.Save() }
  $desk = [Environment]::GetFolderPath('Desktop')
  New-EditorLink (Join-Path $desk 'AD FINEM - Customize overlays.lnk')
  New-FolderLink (Join-Path $desk 'AD FINEM Stream Kit.lnk')
  # Start menu > AD FINEM: findable by typing "AD FINEM" or "Customize" in Start, even if the desktop icons are gone
  $start = Join-Path ([Environment]::GetFolderPath('Programs')) 'AD FINEM'
  New-Item -ItemType Directory -Force -Path $start | Out-Null
  New-EditorLink (Join-Path $start 'AD FINEM - Customize overlays.lnk')
  New-FolderLink (Join-Path $start 'AD FINEM Stream Kit folder.lnk')
  $u = $ws.CreateShortcut((Join-Path $start 'Uninstall AD FINEM Stream Kit.lnk'))
  $u.TargetPath = Join-Path $dest 'UNINSTALL.bat'; $u.WorkingDirectory = $dest; $u.IconLocation = $ico; $u.Save()
  Say '    "AD FINEM - Customize overlays" is on your desktop and in the Start menu (type "AD FINEM").' 'Green'
} catch { Say '    Could not create shortcuts (not a problem - use "Customize overlays.exe" in the kit folder).' 'Yellow' }

# ---------------------------------------------------------------- 6. Stream Deck
Step 6 'Making the Stream Deck page'
try {
  $sdMode = & (Join-Path $dest '_system\streamdeck\make-profile.ps1') -Dest $dest -Edition $Edition
  if ($sdMode -eq 'obs') {
    Say '    Have a Stream Deck? Double-click "AD FINEM.streamDeckProfile" in the kit folder.' 'Green'
    Say '    The keys light up with OBS: mic muted, scene on screen, recording, live.' 'Green'
  } elseif ($sdMode -eq 'keys') {
    Say '    Have a Stream Deck? Double-click "AD FINEM.streamDeckProfile" in the kit folder.' 'Green'
    if (Test-Path (Join-Path $env:APPDATA 'Elgato\StreamDeck')) {
      Say '    Tip: install the free "OBS Studio" plugin in the Stream Deck app (Marketplace) and run' 'Yellow'
      Say '    setup again - then the keys show when the mic is muted, which scene is on, and when you are live.' 'Yellow'
    }
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
Write-Host '   "AD FINEM - Customize overlays" (desktop or Start menu), edit, click Save.'
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

if ($Quiet) { [Console]::Out.WriteLine('@@DONE'); [Console]::Out.Flush() }
exit 0
