# AD FINEM Stream Kit - overlay editor helper
# Serves the kit folder to your browser on this computer only (127.0.0.1) so the
# editor's Save button writes straight to settings.js in this folder - no file dialog.
# Started by "Customize overlays.bat" or the desktop shortcut. Stops by itself after
# 45 minutes without use, or when you close this window.

param([int]$Port = 47821, [switch]$NoBrowser, [int]$IdleMinutes = 45)
$ErrorActionPreference = 'Stop'
try { $Host.UI.RawUI.WindowTitle = 'AD FINEM - overlay editor (close this window when you are done)' } catch {}

$self  = (Resolve-Path (Split-Path -Parent $PSScriptRoot)).Path.TrimEnd('\', '/')
$root  = $self

# Always edit the kit that OBS actually uses. If this copy is not the one OBS loads
# (for example a second unzipped copy), find the right one from OBS's scene files.
function Find-ObsKit {
  $dir = Join-Path $env:APPDATA 'obs-studio\basic\scenes'
  if (-not (Test-Path $dir)) { return $null }
  $files = Get-ChildItem $dir -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '\.json(\.bak)?$' } | Sort-Object LastWriteTime -Descending
  foreach ($f in $files) {
    try { $txt = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8) } catch { continue }
    $m = [regex]::Matches($txt, '"local_file"\s*:\s*"([^"]+?)/overlays/(?:ingame|starting|brb|ending)\.html"')
    foreach ($x in $m) {
      $sep = [IO.Path]::DirectorySeparatorChar
      $cand = $x.Groups[1].Value.Replace('\\', '/').Replace('/', $sep).TrimEnd($sep)
      if ((Test-Path (Join-Path $cand 'settings.js')) -and (Test-Path (Join-Path $cand 'overlays'))) { return $cand }
    }
  }
  return $null
}
$obsKit = Find-ObsKit
if (-not $obsKit) {
  $md = [Environment]::GetFolderPath('MyDocuments')
  if ($md) {
    $guess = Join-Path $md 'AD FINEM Stream Kit'
    if (Test-Path (Join-Path $guess 'settings.js')) { $obsKit = $guess }
  }
}
if ($obsKit) { $root = (Resolve-Path $obsKit).Path.TrimEnd('\', '/') }
$token = [guid]::NewGuid().ToString('N')
$settingsPath = Join-Path $root 'settings.js'

$listener = $null
for ($p = $Port; $p -lt $Port + 30; $p++) {
  try {
    $listener = New-Object System.Net.Sockets.TcpListener ([System.Net.IPAddress]::Loopback), $p
    $listener.Start(); $Port = $p; break
  } catch { $listener = $null }
}
if (-not $listener) { Write-Host 'Could not start the editor helper (no free port).' -ForegroundColor Red; Read-Host 'Press Enter'; exit 1 }

$mime = @{
  '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'; '.css' = 'text/css; charset=utf-8'
  '.json' = 'application/json; charset=utf-8'; '.txt' = 'text/plain; charset=utf-8'; '.svg' = 'image/svg+xml'
  '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.gif' = 'image/gif'; '.woff2' = 'font/woff2'
  '.webm' = 'video/webm'; '.mp4' = 'video/mp4'; '.ico' = 'image/x-icon'; '.webp' = 'image/webp'
}

function Read-Request($stream) {
  $buf = New-Object System.Collections.Generic.List[byte]
  while ($true) {
    $b = $stream.ReadByte()
    if ($b -lt 0) { break }
    $buf.Add([byte]$b); $n = $buf.Count
    if ($n -ge 4 -and $buf[$n - 4] -eq 13 -and $buf[$n - 3] -eq 10 -and $buf[$n - 2] -eq 13 -and $buf[$n - 1] -eq 10) { break }
    if ($n -gt 65536) { break }
  }
  if ($buf.Count -eq 0) { return $null }
  $lines = [Text.Encoding]::ASCII.GetString($buf.ToArray()) -split "`r`n"
  $first = $lines[0] -split ' '
  $headers = @{}
  foreach ($l in $lines | Select-Object -Skip 1) { if ($l -match '^([^:]+):\s*(.*)$') { $headers[$matches[1].ToLower()] = $matches[2] } }
  $body = New-Object byte[] 0
  if ($headers['content-length']) {
    $len = [int]$headers['content-length']
    if ($len -gt 0 -and $len -le 9437184) {
      $body = New-Object byte[] $len; $read = 0
      while ($read -lt $len) { $r = $stream.Read($body, $read, $len - $read); if ($r -le 0) { break }; $read += $r }
    }
  }
  return @{ Method = $first[0]; Target = $first[1]; Headers = $headers; Body = $body }
}

function Send($stream, [int]$code, [string]$ctype, [byte[]]$bytes, [string]$extra = '') {
  $text = @{ 200 = 'OK'; 302 = 'Found'; 400 = 'Bad Request'; 403 = 'Forbidden'; 404 = 'Not Found'; 405 = 'Method Not Allowed' }[$code]
  $hdr = "HTTP/1.1 $code $text`r`nContent-Type: $ctype`r`nContent-Length: $($bytes.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n$extra`r`n"
  $h = [Text.Encoding]::ASCII.GetBytes($hdr)
  $stream.Write($h, 0, $h.Length)
  if ($bytes.Length) { $stream.Write($bytes, 0, $bytes.Length) }
  $stream.Flush()
}

function Json($obj) { return [Text.Encoding]::UTF8.GetBytes(($obj | ConvertTo-Json -Compress)) }

$editorUrl = "http://127.0.0.1:$Port/_system/editor.html"
Write-Host ''
Write-Host '  AD FINEM - overlay editor is running.' -ForegroundColor DarkYellow
Write-Host "  Saving goes straight to: $settingsPath"
if ($root -ne $self) { Write-Host '  (This is the kit OBS uses - not the copy you started the editor from.)' -ForegroundColor DarkGray }
elseif (-not $obsKit) { Write-Host '  Note: OBS is not set up with this kit yet - run INSTALL.bat first.' -ForegroundColor Yellow }
Write-Host '  Keep this window open while you edit. Close it when you are done.'
Write-Host ''
if (-not $NoBrowser) { Start-Process $editorUrl }

$last = Get-Date
$stop = $false
while (-not $stop) {
  if (-not $listener.Pending()) {
    Start-Sleep -Milliseconds 40
    if (((Get-Date) - $last).TotalMinutes -gt $IdleMinutes) { break }
    continue
  }
  $client = $listener.AcceptTcpClient()
  $last = Get-Date
  try {
    $client.ReceiveTimeout = 5000
    $stream = $client.GetStream()
    $req = Read-Request $stream
    if (-not $req) { continue }
    $path = ($req.Target -split '\?')[0]
    $query = if ($req.Target -match '\?(.*)$') { $matches[1] } else { '' }

    if ($req.Method -eq 'POST' -and $path -eq '/api/save') {
      if ($req.Headers['x-af-token'] -ne $token) { Send $stream 403 'application/json' (Json @{ ok = $false; error = 'not allowed' }); continue }
      $text = [Text.Encoding]::UTF8.GetString($req.Body)
      if ($text -notmatch 'window\.AF_SETTINGS\s*=' -or $text.Length -gt 500000) { Send $stream 400 'application/json' (Json @{ ok = $false; error = 'not a settings file' }); continue }
      # ?file=settings-forever = the WoW Forever collection's own settings (Retail + Forever installed)
      $sp = $(if ($query -match '(?:^|&)file=settings-forever(?:&|$)') { Join-Path $root 'settings-forever.js' } else { $settingsPath })
      if (Test-Path $sp) {
        $bk = Join-Path $root '_system\backup'
        New-Item -ItemType Directory -Force -Path $bk | Out-Null
        Copy-Item $sp (Join-Path $bk ([IO.Path]::GetFileNameWithoutExtension($sp) + '_previous.js')) -Force
      }
      [IO.File]::WriteAllText($sp, $text, (New-Object Text.UTF8Encoding $false))
      Write-Host ("  Saved " + (Split-Path $sp -Leaf) + ' ' + (Get-Date -Format 'HH:mm:ss')) -ForegroundColor Green
      Send $stream 200 'application/json' (Json @{ ok = $true; path = $sp })
      continue
    }
    if ($path -eq '/api/version' -or ($req.Method -eq 'POST' -and $path -eq '/api/update')) {
      # kit updates (GitHub releases) - see check-update.ps1
      if ($req.Headers['x-af-token'] -ne $token) { Send $stream 403 'application/json' (Json @{ ok = $false }); continue }
      $cu = Join-Path $root '_system\check-update.ps1'
      if (-not (Test-Path $cu)) { Send $stream 200 'application/json' (Json @{ ok = $false }); continue }
      if ($path -eq '/api/update') {
        Start-Process powershell -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$cu`"", '-Install')
        Send $stream 200 'application/json' (Json @{ ok = $true }); continue
      }
      $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Json 2>$null | Out-String
      if (-not $out.Trim()) { $out = '{"ok":false}' }
      $j = $out.Trim() | ConvertFrom-Json
      $j | Add-Member -NotePropertyName canInstall -NotePropertyValue $true -Force
      Send $stream 200 'application/json' ([Text.Encoding]::UTF8.GetBytes(($j | ConvertTo-Json -Compress)))
      continue
    }
    if ($req.Method -eq 'POST' -and $path -eq '/api/upload') {
      # sponsor logos: saved in the kit's "sponsors" folder
      if ($req.Headers['x-af-token'] -ne $token) { Send $stream 403 'application/json' (Json @{ ok = $false; error = 'not allowed' }); continue }
      $orig = if ($query -match '(?:^|&)name=([^&]*)') { [Uri]::UnescapeDataString($matches[1]) } else { 'logo.png' }
      $orig = [IO.Path]::GetFileName($orig.Replace('\', '/').Split('/')[-1])
      $ext = [IO.Path]::GetExtension($orig).ToLower()
      if (@('.png', '.jpg', '.jpeg', '.webp', '.svg', '.gif') -notcontains $ext) { Send $stream 400 'application/json' (Json @{ ok = $false; error = 'use a PNG, JPG, WEBP, SVG or GIF image' }); continue }
      if ($req.Body.Length -eq 0 -or $req.Body.Length -gt 8388608) { Send $stream 400 'application/json' (Json @{ ok = $false; error = 'image is empty or too big (max 8 MB)' }); continue }
      $base = [regex]::Replace([IO.Path]::GetFileNameWithoutExtension($orig), '[^A-Za-z0-9_-]+', '-').Trim('-')
      if (-not $base) { $base = 'logo' }
      $dir = Join-Path $root 'sponsors'
      New-Item -ItemType Directory -Force -Path $dir | Out-Null
      $file = "$base$ext"; $n = 2
      while (Test-Path (Join-Path $dir $file)) { $file = "$base-$n$ext"; $n++ }
      [IO.File]::WriteAllBytes((Join-Path $dir $file), $req.Body)
      Send $stream 200 'application/json' (Json @{ ok = $true; path = "sponsors/$file" })
      continue
    }
    if ($req.Method -eq 'POST' -and $path -eq '/api/file') {
      # small data files the overlays read: the Twitch connection and "send test alert"
      $vars = @{ 'twitch_auth' = 'AF_TWITCH_AUTH'; 'alert_test' = 'AF_ALERT_TEST' }
      $name = if ($query -match '(?:^|&)name=([a-z_]+)') { $matches[1] } else { '' }
      if ($req.Headers['x-af-token'] -ne $token) { Send $stream 403 'application/json' (Json @{ ok = $false; error = 'not allowed' }); continue }
      if (-not $vars.ContainsKey($name) -or $req.Body.Length -gt 20000) { Send $stream 400 'application/json' (Json @{ ok = $false; error = 'bad request' }); continue }
      $raw = [Text.Encoding]::UTF8.GetString($req.Body).Trim()
      if ($raw -eq 'null' -or $raw -eq '') { $out = 'null' }
      else {
        try { $out = ($raw | ConvertFrom-Json) | ConvertTo-Json -Compress -Depth 5 }
        catch { Send $stream 400 'application/json' (Json @{ ok = $false; error = 'not json' }); continue }
      }
      [IO.File]::WriteAllText((Join-Path (Join-Path $root '_system') "$name.js"), "window.$($vars[$name]) = $out;`n", (New-Object Text.UTF8Encoding $false))
      Send $stream 200 'application/json' (Json @{ ok = $true })
      continue
    }
    if ($req.Method -eq 'POST' -and $path -eq '/api/close') {
      if ($req.Headers['x-af-token'] -eq $token) { Send $stream 200 'application/json' (Json @{ ok = $true }); $stop = $true }
      else { Send $stream 403 'application/json' (Json @{ ok = $false }) }
      continue
    }
    if ($req.Method -ne 'GET') { Send $stream 405 'text/plain' ([Text.Encoding]::ASCII.GetBytes('method not allowed')); continue }
    if ($path -eq '/' -or $path -eq '') { Send $stream 302 'text/plain' (New-Object byte[] 0) "Location: /_system/editor.html`r`n"; continue }

    $rel = [Uri]::UnescapeDataString($path.TrimStart('/')).Replace('/', [IO.Path]::DirectorySeparatorChar)
    $base = if ($rel -like '_system*editor.html') { $self } else { $root }
    $full = [IO.Path]::GetFullPath((Join-Path $base $rel))
    if (-not $full.StartsWith($base + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path $full -PathType Leaf)) {
      Send $stream 404 'text/plain' ([Text.Encoding]::ASCII.GetBytes('not found')); continue
    }
    $ext = [IO.Path]::GetExtension($full).ToLower()
    $ctype = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
    if ($full -like '*editor.html') {
      $html = [IO.File]::ReadAllText($full).Replace('__AF_TOKEN__', $token).Replace('__AF_SAVE_PATH__', $settingsPath.Replace('\', '\\'))
      Send $stream 200 $ctype ([Text.Encoding]::UTF8.GetBytes($html))
    } else {
      Send $stream 200 $ctype ([IO.File]::ReadAllBytes($full))
    }
  } catch {
    Write-Host "  (request error: $($_.Exception.Message))" -ForegroundColor DarkGray
  } finally {
    $client.Close()
  }
}
$listener.Stop()
Write-Host '  Editor helper stopped.'
