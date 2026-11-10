# AD FINEM Stream Kit - graphical setup (Windows PowerShell 5.1, WinForms)
# Started by the Setup .exe. Asks for webcam + microphone, then runs ..\install.ps1 -Quiet
# and shows its progress. install.ps1 does the real work (same as INSTALL.bat).
$ErrorActionPreference = 'Stop'
$errLog = Join-Path $env:TEMP 'adfinem_setup_gui_error.txt'
trap {   # anything unexpected: write it down and let the Setup .exe use the text installer instead
  try { "$(Get-Date -Format s)  $($_.Exception.Message)`r`n$($_.InvocationInfo.PositionMessage)`r`n$($_.ScriptStackTrace)" | Out-File $errLog -Encoding UTF8 } catch {}
  exit 1
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$setupDir = $PSScriptRoot
$sysDir   = Split-Path -Parent $setupDir
$src      = Split-Path -Parent $sysDir
$dest     = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'AD FINEM Stream Kit'
$newVer   = (Get-Content (Join-Path $sysDir 'version.txt') -ErrorAction SilentlyContinue | Select-Object -First 1)
$oldVer   = (Get-Content (Join-Path $dest '_system\version.txt') -ErrorAction SilentlyContinue | Select-Object -First 1)
if ($newVer) { $newVer = $newVer.Trim() } else { $newVer = '' }
$updating = [bool]$oldVer -or (Test-Path (Join-Path $dest 'settings.js'))
$obsJson  = Join-Path $env:APPDATA 'obs-studio\basic\scenes\AD_FINEM.json'

# ------------------------------------------------------------------ look & feel
function C($r, $g, $b) { [System.Drawing.Color]::FromArgb($r, $g, $b) }
$cBG = C 10 12 17; $cPANEL = C 18 22 31; $cLINE = C 34 40 54; $cTEXT = C 238 241 246; $cMUTED = C 152 160 176
$cCORAL = C 232 120 90; $cAMBER = C 240 176 92; $cGREEN = C 120 200 140
$fonts = New-Object System.Drawing.Text.PrivateFontCollection
try { $fonts.AddFontFile((Join-Path $setupDir 'Archivo-ExtraBold.ttf')) } catch {}
function HeadFont($size) {
  if ($fonts.Families.Count) {
    $fam = $fonts.Families[0]
    foreach ($st in 'Regular', 'Bold') { try { if ($fam.IsStyleAvailable($st)) { return New-Object System.Drawing.Font($fam, [single]$size, [System.Drawing.FontStyle]$st) } } catch {} }
  }
  return New-Object System.Drawing.Font('Segoe UI Semibold', [single]$size)
}
$F_BODY = New-Object System.Drawing.Font('Segoe UI', 10)
$F_SMALL = New-Object System.Drawing.Font('Segoe UI', 9)
$F_BOLD = New-Object System.Drawing.Font('Segoe UI Semibold', 10)

function New-Label($text, $x, $y, $w, $h, $font = $F_BODY, $color = $cTEXT) {
  $l = New-Object System.Windows.Forms.Label
  $l.Text = $text; $l.Location = New-Object System.Drawing.Point($x, $y); $l.Size = New-Object System.Drawing.Size($w, $h)
  $l.Font = $font; $l.ForeColor = $color; $l.BackColor = [System.Drawing.Color]::Transparent
  return $l
}
function New-Button($text, $x, $y, $w, $primary = $false) {
  $b = New-Object System.Windows.Forms.Button
  $b.Text = $text; $b.Location = New-Object System.Drawing.Point($x, $y); $b.Size = New-Object System.Drawing.Size($w, 36)
  $b.FlatStyle = 'Flat'; $b.Font = $F_BOLD; $b.Cursor = 'Hand'
  if ($primary) { $b.BackColor = $cCORAL; $b.ForeColor = $cBG; $b.FlatAppearance.BorderSize = 0 }
  else { $b.BackColor = $cPANEL; $b.ForeColor = $cTEXT; $b.FlatAppearance.BorderColor = $cLINE }
  return $b
}
function New-Check($text, $sub, $x, $y, $checked) {
  # a whole clickable row: tick box + title + one line of explanation
  $c = New-Object System.Windows.Forms.CheckBox
  $c.Text = $text; $c.Checked = [bool]$checked; $c.AutoSize = $true
  $c.Location = New-Object System.Drawing.Point($x, $y)
  $c.Font = $F_BOLD; $c.ForeColor = $cTEXT; $c.BackColor = $cBG; $c.FlatStyle = 'Standard'; $c.Cursor = 'Hand'
  $l = New-Label $sub ($x + 20) ($y + 24) 320 20 $F_SMALL $cMUTED
  $l.BackColor = $cBG; $l.Cursor = 'Hand'
  $l.Tag = $c
  $l.Add_Click({ $this.Tag.Checked = -not $this.Tag.Checked })
  $c.Add_CheckedChanged({ $this.ForeColor = $(if ($this.Checked) { $cTEXT } else { $cMUTED }) })
  $pages[1].Controls.Add($c)
  $pages[1].Controls.Add($l)
  $c.BringToFront()
  return $c
}
function Style-Combo($cb) { $cb.BackColor = $cPANEL; $cb.ForeColor = $cTEXT; $cb.FlatStyle = 'Flat'; $cb.Font = $F_BODY }

# ------------------------------------------------------------------ what's on this PC
function Find-Obs {
  $c = @((Join-Path $env:ProgramFiles 'obs-studio\bin\64bit\obs64.exe'),
         (Join-Path ${env:ProgramFiles(x86)} 'Steam\steamapps\common\OBS Studio\bin\64bit\obs64.exe'))
  try { $r = (Get-ItemProperty 'HKLM:\SOFTWARE\OBS Studio' -ErrorAction Stop).'(default)'; if ($r) { $c = @((Join-Path $r 'bin\64bit\obs64.exe')) + $c } } catch {}
  foreach ($p in $c) { if ($p -and (Test-Path $p)) { return $p } }
  return $null
}
function Get-Cameras {
  $names = New-Object System.Collections.Generic.List[string]
  try {   # DirectShow video devices (what OBS lists): capture + video interfaces of present devices
    $base = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceClasses'
    $present = @{}; Get-CimInstance Win32_PnPEntity -ErrorAction Stop | Where-Object { $_.Status -eq 'OK' } | ForEach-Object { $present[$_.PNPDeviceID.ToUpper()] = $true }
    $video = @{}; Get-ChildItem "$base\{6994ad05-93ef-11d0-a3cc-00a0c9223196}" -ErrorAction Stop | ForEach-Object {
      $di = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).DeviceInstance; if ($di) { $video[$di.ToUpper()] = $true } }
    Get-ChildItem "$base\{65e8773d-8f56-11d0-a3b9-00a0c9223196}" -ErrorAction Stop | ForEach-Object {
      $di = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).DeviceInstance
      if ($di -and $video[$di.ToUpper()] -and $present[$di.ToUpper()]) {
        $fn = (Get-ItemProperty (Join-Path $_.PSPath '#GLOBAL\Device Parameters') -ErrorAction SilentlyContinue).FriendlyName
        if ($fn -and -not $names.Contains($fn)) { $names.Add($fn) }
      }
    }
  } catch {}
  if (-not $names.Count) {
    try { Get-CimInstance Win32_PnPEntity -Filter "PNPClass='Camera' OR PNPClass='Image'" | Where-Object { $_.Status -eq 'OK' } |
          ForEach-Object { if (-not $names.Contains($_.Name)) { $names.Add($_.Name) } } } catch {}
  }
  try {   # virtual cameras (NVIDIA Broadcast, OBS Virtual Camera, ...)
    Get-ChildItem 'Registry::HKEY_CLASSES_ROOT\CLSID\{860BB310-5D01-11d0-BD3B-00A0C911CE86}\Instance' -ErrorAction Stop | ForEach-Object {
      $fn = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).FriendlyName
      if ($fn -and $fn -notlike 'OBS Virtual*' -and -not $names.Contains($fn)) { $names.Add($fn) }
    }
  } catch {}
  return @($names)
}
function Get-Mics {
  $list = @()
  try {
    Get-CimInstance Win32_PnPEntity -Filter "PNPClass='AudioEndpoint'" | Where-Object { $_.Status -eq 'OK' -and $_.PNPDeviceID -like 'SWD\MMDEVAPI\{0.0.1.*' } | ForEach-Object {
      $id = $_.PNPDeviceID.Substring(13)
      $list += [pscustomobject]@{ Name = $_.Name; Id = $id.ToLower() }
    }
  } catch {}
  return @($list | Sort-Object Name)
}
function Get-Current {   # what the existing AD FINEM collection uses (for updates)
  $r = @{ Camera = $null; Mic = $null; Filters = @() }
  if (-not (Test-Path $obsJson)) { return $r }
  try {
    $j = [IO.File]::ReadAllText($obsJson) | ConvertFrom-Json
    $cam = @($j.sources) | Where-Object { $_.id -eq 'dshow_input' } | Select-Object -First 1
    if ($cam -and $cam.settings.video_device_id) { $r.Camera = ($cam.settings.video_device_id.Split(':')[0]).Replace('#3A', ':').Replace('#22', '#') }
    if ($j.AuxAudioDevice1) {
      $r.Mic = $j.AuxAudioDevice1.settings.device_id
      $map = @{ noise_suppress_filter = 'ns'; noise_gate_filter = 'gate'; compressor_filter = 'comp'; limiter_filter = 'limit' }
      $r.Filters = @(@($j.AuxAudioDevice1.filters) | Where-Object { $_ -and $map[$_.id] } | ForEach-Object { $map[$_.id] })
    }
  } catch {}
  return $r
}

$script:obsExe = Find-Obs
$slobs = Test-Path (Join-Path $env:APPDATA 'slobs-client')
$current = Get-Current

# ------------------------------------------------------------------ window
$form = New-Object System.Windows.Forms.Form
$form.Text = 'AD FINEM Stream Kit Setup'
$form.ClientSize = New-Object System.Drawing.Size(760, 540)
$form.StartPosition = 'CenterScreen'; $form.FormBorderStyle = 'FixedSingle'; $form.MaximizeBox = $false
$form.BackColor = $cBG; $form.ForeColor = $cTEXT; $form.Font = $F_BODY
try { $form.Icon = New-Object System.Drawing.Icon((Join-Path $sysDir 'adfinem.ico')) } catch {}

$header = New-Object System.Windows.Forms.Panel
$header.Location = New-Object System.Drawing.Point(0, 0); $header.Size = New-Object System.Drawing.Size(760, 92); $header.BackColor = $cPANEL
$header.Add_Paint({ param($s, $e)
  $r = New-Object System.Drawing.Rectangle(0, 89, 760, 3)
  $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush($r, $cCORAL, $cAMBER, 0.0)
  $e.Graphics.FillRectangle($br, $r); $br.Dispose() })
$logo = New-Object System.Windows.Forms.PictureBox
$logo.Location = New-Object System.Drawing.Point(26, 18); $logo.Size = New-Object System.Drawing.Size(56, 56); $logo.SizeMode = 'Zoom'; $logo.BackColor = $cPANEL
try { $logo.Image = [System.Drawing.Image]::FromFile((Join-Path $setupDir 'emblem.png')) } catch {}
$header.Controls.Add($logo)
$t1 = New-Label 'AD FINEM' 96 18 400 34 (HeadFont 20) $cTEXT; $t1.BackColor = $cPANEL; $header.Controls.Add($t1)
$sub = if ($updating -and $oldVer -and $oldVer.Trim() -ne $newVer) { "STREAM KIT  -  UPDATE $($oldVer.Trim()) > $newVer" } elseif ($updating) { "STREAM KIT $newVer  -  REINSTALL" } else { "STREAM KIT $newVer  -  SETUP" }
$t2 = New-Label $sub 98 54 500 22 $F_BOLD $cAMBER; $t2.BackColor = $cPANEL; $header.Controls.Add($t2)
$form.Controls.Add($header)

$pages = @()
for ($i = 0; $i -lt 4; $i++) {
  $p = New-Object System.Windows.Forms.Panel
  $p.Location = New-Object System.Drawing.Point(0, 92); $p.Size = New-Object System.Drawing.Size(760, 384); $p.BackColor = $cBG; $p.Visible = ($i -eq 0)
  $form.Controls.Add($p); $pages += $p
}
$footer = New-Object System.Windows.Forms.Panel
$footer.Location = New-Object System.Drawing.Point(0, 476); $footer.Size = New-Object System.Drawing.Size(760, 64); $footer.BackColor = $cPANEL
$form.Controls.Add($footer)
$btnBack = New-Button 'Back' 402 14 100; $btnNext = New-Button 'Next' 512 14 110 $true; $btnCancel = New-Button 'Cancel' 632 14 100
$footer.Controls.AddRange(@($btnBack, $btnNext, $btnCancel))
$dots = New-Label '' 26 22 300 20 $F_SMALL $cMUTED; $dots.BackColor = $cPANEL; $footer.Controls.Add($dots)

# ------------------------------------------------------------------ page 1: welcome
$p = $pages[0]
$p.Controls.Add((New-Label ($(if ($updating) { 'Update your stream kit' } else { 'Welcome' })) 40 26 680 36 (HeadFont 16)))
$intro = if ($updating) {
  "This updates the AD FINEM Stream Kit. Your texts, sponsors, alerts, Twitch connection and the scenes you added yourself are kept."
} else {
  "This sets up everything for streaming in Ad Finem colours: OBS scenes with intro, outro and transitions, the in-game overlay with live raid progress, alerts, sponsors, the overlay editor and a Stream Deck page."
}
$p.Controls.Add((New-Label $intro 40 70 680 60 $F_BODY $cMUTED))
$p.Controls.Add((New-Label 'ON THIS PC' 40 146 300 20 $F_BOLD $cCORAL))
$obsLbl = New-Label '' 40 172 460 24 $F_BOLD $cTEXT; $p.Controls.Add($obsLbl)
$btnObs = New-Button 'Install OBS (free)' 520 166 200 $true; $p.Controls.Add($btnObs)
$slLbl = New-Label '' 40 202 680 22 $F_SMALL $cMUTED; $p.Controls.Add($slLbl)
$p.Controls.Add((New-Label 'WHICH WORLD OF WARCRAFT DO YOU STREAM?' 40 238 500 20 $F_BOLD $cCORAL))
# two clickable cards: Retail (coral) / WoW Forever (gold + blue). Picks the intro, outro, loops, colours and Stream Deck icons.
$script:edition = 'retail'
try { $e0 = (Get-Content (Join-Path $dest '_system\edition.txt') -ErrorAction Stop | Select-Object -First 1).Trim().ToLower(); if ($e0 -eq 'forever') { $script:edition = 'forever' } } catch {}
$cards = @{}
function New-EditionCard($key, $title, $sub, $img, $x) {
  $c = New-Object System.Windows.Forms.Panel
  $c.Location = New-Object System.Drawing.Point($x, 264); $c.Size = New-Object System.Drawing.Size(330, 74)
  $c.BackColor = $cPANEL; $c.Cursor = 'Hand'; $c.Tag = $key
  $pb = New-Object System.Windows.Forms.PictureBox
  $pb.Location = New-Object System.Drawing.Point(12, 11); $pb.Size = New-Object System.Drawing.Size(52, 52); $pb.SizeMode = 'Zoom'; $pb.BackColor = $cPANEL; $pb.Cursor = 'Hand'; $pb.Tag = $key
  try { $pb.Image = [System.Drawing.Image]::FromFile((Join-Path $setupDir $img)) } catch {}
  $l1 = New-Label $title 76 14 240 24 $F_BOLD $cTEXT; $l1.BackColor = $cPANEL; $l1.Cursor = 'Hand'; $l1.Tag = $key
  $l2 = New-Label $sub 76 38 245 20 $F_SMALL $cMUTED; $l2.BackColor = $cPANEL; $l2.Cursor = 'Hand'; $l2.Tag = $key
  $c.Controls.AddRange(@($pb, $l1, $l2))
  $c.Add_Paint({ param($s, $e)
    $sel = ($s.Tag -eq $script:edition)
    $col = if ($sel) { if ($s.Tag -eq 'forever') { C 217 164 65 } else { $cCORAL } } else { $cLINE }
    $pen = New-Object System.Drawing.Pen($col, $(if ($sel) { 3 } else { 1 }))
    $e.Graphics.DrawRectangle($pen, 1, 1, $s.Width - 3, $s.Height - 3); $pen.Dispose() })
  $pick = { $script:edition = $this.Tag; foreach ($k in $cards.Keys) { $cards[$k].Invalidate() } }
  foreach ($ctl in @($c, $pb, $l1, $l2)) { $ctl.Add_Click($pick) }
  $pages[0].Controls.Add($c); $cards[$key] = $c
}
New-EditionCard 'retail' 'Retail' 'Live servers - the coral AD FINEM look' 'emblem.png' 40
New-EditionCard 'forever' 'WoW Forever' 'Gold and sapphire look, Forever emblem' 'forever-emblem.png' 390
$p.Controls.Add((New-Label 'You can switch later by running the setup again. Next you pick your webcam and microphone.' 40 348 680 22 $F_SMALL $cMUTED))
function Update-ObsStatus {
  if ($script:obsExe) { $obsLbl.Text = "$([char]0x2713)  OBS Studio is installed"; $obsLbl.ForeColor = $cGREEN; $btnObs.Visible = $false }
  else { $obsLbl.Text = "$([char]0x2715)  OBS Studio is not installed"; $obsLbl.ForeColor = $cAMBER; $btnObs.Visible = $true }
  if ($slobs) { $slLbl.Text = 'Streamlabs Desktop found too - you can import the AD FINEM scenes there (see the README).' }
}
Update-ObsStatus
$script:wingetProc = $null
$btnObs.Add_Click({
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Start-Process 'https://obsproject.com/download'; return }
  $btnObs.Enabled = $false; $btnObs.Text = 'Installing OBS...'
  $script:wingetProc = Start-Process winget -ArgumentList 'install -e --id OBSProject.OBSStudio --accept-package-agreements --accept-source-agreements' -WindowStyle Hidden -PassThru
  $wt = New-Object System.Windows.Forms.Timer; $wt.Interval = 1500
  $wt.Add_Tick({ if ($script:wingetProc.HasExited) { $this.Stop(); $script:obsExe = Find-Obs; $btnObs.Enabled = $true; $btnObs.Text = 'Install OBS (free)'; Update-ObsStatus } })
  $wt.Start()
})

# ------------------------------------------------------------------ page 2: camera + mic
$p = $pages[1]
$p.Controls.Add((New-Label 'Webcam and microphone' 40 20 680 34 (HeadFont 16)))
$p.Controls.Add((New-Label 'WEBCAM' 40 66 300 20 $F_BOLD $cCORAL))
$cbCam = New-Object System.Windows.Forms.ComboBox; $cbCam.DropDownStyle = 'DropDown'
$cbCam.Location = New-Object System.Drawing.Point(40, 90); $cbCam.Size = New-Object System.Drawing.Size(320, 28); Style-Combo $cbCam
$KEEP = '(keep what I have)'; $LATER = '(no webcam / set up later)'
$cams = Get-Cameras
if ($current.Camera) { [void]$cbCam.Items.Add($KEEP) }
foreach ($c in $cams) { [void]$cbCam.Items.Add($c) }
[void]$cbCam.Items.Add($LATER)
$cbCam.SelectedIndex = 0
$p.Controls.Add($cbCam)
$p.Controls.Add((New-Label 'Not in the list? Type its name as OBS shows it.' 40 120 320 20 $F_SMALL $cMUTED))

$p.Controls.Add((New-Label 'MICROPHONE' 400 66 300 20 $F_BOLD $cCORAL))
$cbMic = New-Object System.Windows.Forms.ComboBox; $cbMic.DropDownStyle = 'DropDownList'
$cbMic.Location = New-Object System.Drawing.Point(400, 90); $cbMic.Size = New-Object System.Drawing.Size(320, 28); Style-Combo $cbMic
$mics = Get-Mics
$micIds = @()
if ($current.Mic) { [void]$cbMic.Items.Add($KEEP); $micIds += '' }
[void]$cbMic.Items.Add('Windows default microphone'); $micIds += 'default'
foreach ($m in $mics) { [void]$cbMic.Items.Add($m.Name); $micIds += $m.Id }
$cbMic.SelectedIndex = 0
$p.Controls.Add($cbMic)
$p.Controls.Add((New-Label 'Desktop audio uses your default speakers/headset.' 400 120 320 20 $F_SMALL $cMUTED))

$p.Controls.Add((New-Label 'MAKE MY MIC SOUND GOOD' 40 160 400 20 $F_BOLD $cCORAL))
$fresh = -not $current.Mic -or -not $current.Filters
$has = { param($k) $fresh -or ($current.Filters -contains $k) }
$ckNs    = New-Check 'Noise suppression' 'Removes fans, keyboard clicks and background hum' 40 188 (& $has 'ns')
$ckGate  = New-Check 'Noise gate' 'Silence between your words - no breathing or room noise' 400 188 (& $has 'gate')
$ckComp  = New-Check 'Compressor' 'Evens out quiet talking and loud callouts' 40 246 (& $has 'comp')
$ckLimit = New-Check 'Limiter' 'Stops shouting from clipping and hurting ears' 400 246 (& $has 'limit')
$p.Controls.Add((New-Label 'Fine-tune later in OBS: in the Audio Mixer click the three dots next to Mic/Aux > Filters.' 40 312 680 40 $F_SMALL $cMUTED))
$origFilters = (@('ns', 'gate', 'comp', 'limit') | Where-Object { & $has $_ }) -join ','

# ------------------------------------------------------------------ page 3: installing
$p = $pages[2]
$stTitle = New-Label 'Setting up...' 40 20 680 34 (HeadFont 16); $p.Controls.Add($stTitle)
$stLbl = New-Label 'Starting' 40 62 520 22 $F_BOLD $cAMBER; $p.Controls.Add($stLbl)
$btnCloseObs = New-Button 'Close OBS for me' 540 56 180 $true; $btnCloseObs.Visible = $false; $p.Controls.Add($btnCloseObs)
$bar = New-Object System.Windows.Forms.ProgressBar
$bar.Location = New-Object System.Drawing.Point(40, 96); $bar.Size = New-Object System.Drawing.Size(680, 10); $bar.Maximum = 6; $bar.Style = 'Continuous'
$p.Controls.Add($bar)
$log = New-Object System.Windows.Forms.ListBox
$log.Location = New-Object System.Drawing.Point(40, 122); $log.Size = New-Object System.Drawing.Size(680, 246)
$log.BackColor = $cPANEL; $log.ForeColor = $cMUTED; $log.BorderStyle = 'None'; $log.Font = $F_SMALL
$p.Controls.Add($log)
$btnCloseObs.Add_Click({ Get-Process -Name obs64, obs32 -ErrorAction SilentlyContinue | ForEach-Object { [void]$_.CloseMainWindow() } })

# ------------------------------------------------------------------ page 4: done
$p = $pages[3]
$doneTitle = New-Label 'All set - to the end' 40 26 680 36 (HeadFont 18); $p.Controls.Add($doneTitle)
$doneText = New-Label '' 40 72 680 110 $F_BODY $cMUTED; $p.Controls.Add($doneText)
$btnOpenObs = New-Button 'Open OBS' 40 200 200 $true
$btnEditor = New-Button 'Customize overlays' 254 200 200
$btnDeck = New-Button 'Add Stream Deck page' 468 200 200
$p.Controls.AddRange(@($btnOpenObs, $btnEditor, $btnDeck))
$p.Controls.Add((New-Label 'Updates are offered automatically when OBS starts.' 40 262 680 22 $F_SMALL $cMUTED))
$btnOpenObs.Add_Click({ if ($script:obsExe) { Start-Process -FilePath $script:obsExe -WorkingDirectory (Split-Path $script:obsExe) } })
$btnEditor.Add_Click({ Start-Process powershell -WindowStyle Minimized -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Minimized', '-File', "`"$(Join-Path $dest '_system\editor.ps1')`"") })
$btnDeck.Add_Click({ $f = Join-Path $dest 'AD FINEM.streamDeckProfile'; if (Test-Path $f) { Start-Process $f } })

# ------------------------------------------------------------------ flow
$script:page = 0
function Show-Page($n) {
  $script:page = $n
  for ($i = 0; $i -lt 4; $i++) { $pages[$i].Visible = ($i -eq $n) }
  $btnBack.Visible = ($n -eq 1)
  $btnNext.Visible = ($n -lt 2) -or ($n -eq 3)
  $btnNext.Text = @('Next', $(if ($updating) { 'Update' } else { 'Install' }), '', 'Finish')[$n]
  $btnCancel.Visible = ($n -lt 2)
  $dots.Text = @('Step 1 of 3', 'Step 2 of 3', 'Step 3 of 3', 'Done')[$n]
}
$btnBack.Add_Click({ Show-Page 0 })
$btnCancel.Add_Click({ $form.Close() })
$btnNext.Add_Click({
  switch ($script:page) {
    0 { Show-Page 1 }
    1 { Start-Install }
    3 { $form.Close() }
  }
})

$script:proc = $null; $script:readPos = 0; $script:exitCode = 2   # 0 installed, 2 cancelled, 3 install failed
$outFile = Join-Path $env:TEMP 'adfinem_setup_out.txt'
$errFile = Join-Path $env:TEMP 'adfinem_setup_err.txt'

function Start-Install {
  Show-Page 2
  $args2 = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$(Join-Path $sysDir 'install.ps1')`"", '-Quiet')
  $cam = $cbCam.Text.Trim()
  if ($cam -and $cam -ne $KEEP -and $cam -ne $LATER) { $args2 += @('-Camera', "`"$($cam.Replace('"', ''))`"") }
  $micId = $micIds[$cbMic.SelectedIndex]
  if ($micId) { $args2 += @('-Mic', "`"$micId`"") }
  $f = @(); if ($ckNs.Checked) { $f += 'ns' }; if ($ckGate.Checked) { $f += 'gate' }; if ($ckComp.Checked) { $f += 'comp' }; if ($ckLimit.Checked) { $f += 'limit' }
  $fs = $f -join ','
  if ($fresh -or $fs -ne $origFilters) { $args2 += @('-MicFilters', $(if ($fs) { $fs } else { 'none' })) }
  $args2 += @('-Edition', $script:edition)
  Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue
  $script:proc = Start-Process powershell -ArgumentList $args2 -WindowStyle Hidden -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile
  $null = $script:proc.Handle   # keep the handle so ExitCode is readable later (PowerShell quirk)
  $script:readPos = 0
  $timer.Start()
}

function Read-NewLines {
  if (-not (Test-Path $outFile)) { return @() }
  try {
    $fsr = New-Object IO.FileStream($outFile, 'Open', 'Read', 'ReadWrite')
    [void]$fsr.Seek($script:readPos, 'Begin')
    $sr = New-Object IO.StreamReader($fsr, [Text.Encoding]::UTF8)
    $txt = $sr.ReadToEnd(); $sr.Close()
  } catch { return @() }
  $cut = $txt.LastIndexOf("`n")
  if ($cut -lt 0) { return @() }
  $script:readPos += [Text.Encoding]::UTF8.GetByteCount($txt.Substring(0, $cut + 1))
  return @($txt.Substring(0, $cut).Split("`n") | ForEach-Object { $_.TrimEnd("`r") } | Where-Object { $_ })
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 300
$timer.Add_Tick({
  foreach ($line in (Read-NewLines)) {
    if ($line -match '^@@STEP (\d+) (.*)$') { $bar.Value = [Math]::Min(6, [int]$matches[1] - 1); $stLbl.Text = $matches[2]; [void]$log.Items.Add(''); [void]$log.Items.Add($matches[2].ToUpper()) }
    elseif ($line -match '^@@LOG (.*)$') { [void]$log.Items.Add('   ' + $matches[1]) }
    elseif ($line -eq '@@OBS_OPEN') { $stLbl.Text = 'OBS is open - close it to continue'; $btnCloseObs.Visible = $true }
    elseif ($line -eq '@@OBS_CLOSED') { $btnCloseObs.Visible = $false }
    if ($log.Items.Count) { $log.TopIndex = $log.Items.Count - 1 }
  }
  if ($script:proc -and $script:proc.HasExited) {
    $this.Stop()
    foreach ($line in (Read-NewLines)) { if ($line -match '^@@LOG (.*)$') { [void]$log.Items.Add('   ' + $matches[1]) } }
    $ok = ($script:proc.ExitCode -eq 0) -or (Get-Content $outFile -ErrorAction SilentlyContinue | Where-Object { $_ -eq '@@DONE' })
    if ($ok) {
      $script:exitCode = 0
      $bar.Value = 6
      $lines = @("Open OBS and choose Scene Collection > AD FINEM.")
      if (-not $script:obsExe) { $lines = @('Install OBS Studio, then run this setup again to add the scenes.') }
      $lines += "Change texts, alerts and sponsors with ""AD FINEM - Customize overlays"" on your desktop."
      $lines += "Your webcam shows the AD FINEM picture until the camera is on."
      $doneText.Text = $lines -join "`r`n`r`n"
      $btnOpenObs.Visible = [bool]$script:obsExe
      $btnDeck.Visible = Test-Path (Join-Path $dest 'AD FINEM.streamDeckProfile')
      Show-Page 3
    } else {
      $script:exitCode = 3
      $stTitle.Text = 'Something went wrong'; $stTitle.ForeColor = $cCORAL
      $err = (Get-Content $errFile -ErrorAction SilentlyContinue | Where-Object { $_ } | Select-Object -First 6) -join ' '
      $stLbl.Text = 'Nothing is lost - run the setup again, or INSTALL.bat in the kit folder.'
      if ($err) { [void]$log.Items.Add(''); [void]$log.Items.Add('ERROR: ' + $err) }
      $log.TopIndex = [Math]::Max(0, $log.Items.Count - 1)
      $btnCancel.Text = 'Close'; $btnCancel.Visible = $true
    }
  }
})

$form.Add_FormClosing({ param($s, $e)
  if ($script:proc -and -not $script:proc.HasExited) {
    $r = [System.Windows.Forms.MessageBox]::Show('Setup is still running. Stop it?', 'AD FINEM Stream Kit', 'YesNo', 'Warning')
    if ($r -ne 'Yes') { $e.Cancel = $true } else { try { $script:proc.Kill() } catch {} }
  }
})

Show-Page 0
[void]$form.ShowDialog()
exit $script:exitCode
