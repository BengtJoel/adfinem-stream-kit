# AD FINEM Stream Kit - music routing helper (Windows 10 2004+ / 11)
# Dot-source it (". af-audio.ps1") and use:
#   Get-AfEndpoints                    every active playback/recording device: Id, Name, Flow, IsDefault
#   Find-AfCable                       @{ Input = <playback id>; Output = <recording id> } of VB-CABLE, or $null
#   Install-AfCable [-Log {..}]        downloads VB-Audio's VB-CABLE driver pack and installs it silently (admin
#                                      prompt), then puts your default playback/recording devices back
#   Set-AfAppOutput 'Spotify' $id      sends one app's sound to a playback device (Windows remembers it per app,
#                                      like Settings > Sound > Volume mixer > the app > Output device)
#   Get-AfAppOutput 'Spotify'          the device id the app is set to ('' = Windows default)
# Run directly for a quick report:  powershell -File af-audio.ps1
$ErrorActionPreference = 'Stop'

if (-not ('AfAudio.Api' -as [type])) {
Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace AfAudio {
  public enum EDataFlow { Render = 0, Capture = 1, All = 2 }
  public enum ERole { Console = 0, Multimedia = 1, Communications = 2 }

  [StructLayout(LayoutKind.Sequential)] public struct PROPERTYKEY { public Guid fmtid; public int pid; }
  [StructLayout(LayoutKind.Explicit)] public struct PROPVARIANT {
    [FieldOffset(0)] public ushort vt; [FieldOffset(8)] public IntPtr p;
  }

  [ComImport, Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IPropertyStore {
    int GetCount(out int c); int GetAt(int i, out PROPERTYKEY k);
    int GetValue(ref PROPERTYKEY k, out PROPVARIANT v);
  }
  [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IMMDevice {
    int Activate(ref Guid iid, int ctx, IntPtr p, [MarshalAs(UnmanagedType.IUnknown)] out object o);
    int OpenPropertyStore(int access, out IPropertyStore ps);
    int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
    int GetState(out int state);
  }
  [ComImport, Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IMMDeviceCollection { int GetCount(out int c); int Item(int i, out IMMDevice d); }
  [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IMMDeviceEnumerator {
    int EnumAudioEndpoints(EDataFlow flow, int mask, out IMMDeviceCollection c);
    int GetDefaultAudioEndpoint(EDataFlow flow, ERole role, out IMMDevice d);
  }
  [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumerator { }

  // undocumented but stable since Windows 7 (used by SoundSwitch, EarTrumpet, NirSoft): set the default device
  [ComImport, Guid("f8679f50-850a-41cf-9c72-430f290290c8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IPolicyConfig {
    int GetMixFormat(); int GetDeviceFormat(); int ResetDeviceFormat(); int SetDeviceFormat();
    int GetProcessingPeriod(); int SetProcessingPeriod(); int GetShareMode(); int SetShareMode();
    int GetPropertyValue(); int SetPropertyValue();
    [PreserveSig] int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string id, ERole role);
    int SetEndpointVisibility();
  }
  [ComImport, Guid("870af99c-171d-4f9e-af0d-e63df40c2bc9")] class CPolicyConfigClient { }

  // per-app output device (what Settings > Volume mixer > App > Output device does), Windows 10 2004+
  [ComImport, Guid("ab3d4648-e242-459f-b02f-541c70306324"), InterfaceType(ComInterfaceType.InterfaceIsIInspectable)]
  interface IAudioPolicyConfigFactory21H2 {
    int a1(); int a2(); int a3(); int a4(); int a5(); int a6(); int a7(); int a8(); int a9(); int a10();
    int a11(); int a12(); int a13(); int a14(); int a15(); int a16(); int a17(); int a18(); int a19();
    [PreserveSig] int SetPersistedDefaultAudioEndpoint(uint pid, EDataFlow flow, ERole role, IntPtr deviceId);
    [PreserveSig] int GetPersistedDefaultAudioEndpoint(uint pid, EDataFlow flow, ERole role, out IntPtr deviceId);
    [PreserveSig] int ClearAllPersistedApplicationDefaultEndpoints();
  }
  [ComImport, Guid("2a59116d-6c4f-45e0-a74f-707e3fef9258"), InterfaceType(ComInterfaceType.InterfaceIsIInspectable)]
  interface IAudioPolicyConfigFactoryOld {
    int a1(); int a2(); int a3(); int a4(); int a5(); int a6(); int a7(); int a8(); int a9(); int a10();
    int a11(); int a12(); int a13(); int a14(); int a15(); int a16(); int a17(); int a18(); int a19();
    [PreserveSig] int SetPersistedDefaultAudioEndpoint(uint pid, EDataFlow flow, ERole role, IntPtr deviceId);
    [PreserveSig] int GetPersistedDefaultAudioEndpoint(uint pid, EDataFlow flow, ERole role, out IntPtr deviceId);
    [PreserveSig] int ClearAllPersistedApplicationDefaultEndpoints();
  }

  public class Endpoint {
    public string Id; public string Name; public string Flow; public bool IsDefault;
  }

  public static class Api {
    [DllImport("combase.dll")] static extern int WindowsCreateString([MarshalAs(UnmanagedType.LPWStr)] string s, int len, out IntPtr h);
    [DllImport("combase.dll")] static extern int WindowsDeleteString(IntPtr h);
    [DllImport("combase.dll")] static extern IntPtr WindowsGetStringRawBuffer(IntPtr h, out uint len);
    [DllImport("combase.dll")] static extern int RoGetActivationFactory(IntPtr cls, ref Guid iid, out IntPtr f);

    static PROPERTYKEY PKEY_FriendlyName = new PROPERTYKEY { fmtid = new Guid("a45c254e-df1c-4efd-8020-67d146a850e0"), pid = 14 };

    public static List<Endpoint> List() {
      var res = new List<Endpoint>();
      var en = (IMMDeviceEnumerator)new MMDeviceEnumerator();
      foreach (EDataFlow flow in new[] { EDataFlow.Render, EDataFlow.Capture }) {
        string def = null; IMMDevice d0;
        if (en.GetDefaultAudioEndpoint(flow, ERole.Console, out d0) == 0 && d0 != null) d0.GetId(out def);
        IMMDeviceCollection col; en.EnumAudioEndpoints(flow, 1 /* active */, out col);
        int n; col.GetCount(out n);
        for (int i = 0; i < n; i++) {
          IMMDevice d; col.Item(i, out d);
          string id; d.GetId(out id);
          string name = id;
          IPropertyStore ps;
          if (d.OpenPropertyStore(0, out ps) == 0) {
            PROPVARIANT v; var k = PKEY_FriendlyName;
            if (ps.GetValue(ref k, out v) == 0 && v.vt == 31 /* VT_LPWSTR */) name = Marshal.PtrToStringUni(v.p);
          }
          res.Add(new Endpoint { Id = id, Name = name, Flow = flow == EDataFlow.Render ? "playback" : "recording", IsDefault = id == def });
        }
      }
      return res;
    }

    public static string GetDefault(EDataFlow flow, ERole role) {
      var en = (IMMDeviceEnumerator)new MMDeviceEnumerator(); IMMDevice d; string id = null;
      if (en.GetDefaultAudioEndpoint(flow, role, out d) == 0 && d != null) d.GetId(out id);
      return id;
    }

    public static void SetDefault(string id, ERole role) {
      var pc = (IPolicyConfig)new CPolicyConfigClient();
      Marshal.ThrowExceptionForHR(pc.SetDefaultEndpoint(id, role));
    }

    static object Factory() {
      IntPtr cls; string name = "Windows.Media.Internal.AudioPolicyConfig";
      Marshal.ThrowExceptionForHR(WindowsCreateString(name, name.Length, out cls));
      try {
        foreach (var g in new[] { typeof(IAudioPolicyConfigFactory21H2).GUID, typeof(IAudioPolicyConfigFactoryOld).GUID }) {
          Guid iid = g; IntPtr f;
          if (RoGetActivationFactory(cls, ref iid, out f) == 0 && f != IntPtr.Zero) {
            object o = Marshal.GetObjectForIUnknown(f); Marshal.Release(f); return o;
          }
        }
      } finally { WindowsDeleteString(cls); }
      throw new NotSupportedException("This Windows version cannot set an app's output device (needs Windows 10 2004 or later).");
    }

    // full device interface path that the per-app setting wants
    static string Path(string mmId, EDataFlow flow) {
      if (string.IsNullOrEmpty(mmId)) return "";
      return @"\\?\SWD#MMDEVAPI#" + mmId + (flow == EDataFlow.Render ? "#{e6327cad-dcec-4949-ae8a-991e976a79d2}" : "#{2eef81be-33fa-4800-9670-1cd474972c3f}");
    }

    public static void SetAppDevice(uint pid, string mmId, EDataFlow flow) {
      object f = Factory(); IntPtr h = IntPtr.Zero; string p = Path(mmId, flow);
      if (p.Length > 0) Marshal.ThrowExceptionForHR(WindowsCreateString(p, p.Length, out h));
      try {
        foreach (ERole role in new[] { ERole.Console, ERole.Multimedia }) {
          int hr = (f is IAudioPolicyConfigFactory21H2)
            ? ((IAudioPolicyConfigFactory21H2)f).SetPersistedDefaultAudioEndpoint(pid, flow, role, h)
            : ((IAudioPolicyConfigFactoryOld)f).SetPersistedDefaultAudioEndpoint(pid, flow, role, h);
          Marshal.ThrowExceptionForHR(hr);
        }
      } finally { if (h != IntPtr.Zero) WindowsDeleteString(h); }
    }

    public static string GetAppDevice(uint pid, EDataFlow flow) {
      object f = Factory(); IntPtr h;
      int hr = (f is IAudioPolicyConfigFactory21H2)
        ? ((IAudioPolicyConfigFactory21H2)f).GetPersistedDefaultAudioEndpoint(pid, flow, ERole.Multimedia, out h)
        : ((IAudioPolicyConfigFactoryOld)f).GetPersistedDefaultAudioEndpoint(pid, flow, ERole.Multimedia, out h);
      if (hr != 0 || h == IntPtr.Zero) return "";
      uint len; string s = Marshal.PtrToStringUni(WindowsGetStringRawBuffer(h, out len), (int)len); WindowsDeleteString(h);
      int a = s.IndexOf("{0."); int b = a >= 0 ? s.IndexOf('#', a) : -1;
      return (a >= 0 && b > a) ? s.Substring(a, b - a) : s;
    }
  }
}
'@
}

function Get-AfEndpoints { [AfAudio.Api]::List() }

function Find-AfCable {
  $all = @(Get-AfEndpoints)
  $in  = $all | Where-Object { $_.Flow -eq 'playback'  -and $_.Name -match 'CABLE Input' }  | Select-Object -First 1
  $out = $all | Where-Object { $_.Flow -eq 'recording' -and $_.Name -match 'CABLE Output' } | Select-Object -First 1
  if ($in -and $out) { return @{ Input = $in.Id; Output = $out.Id; InputName = $in.Name; OutputName = $out.Name } }
  return $null
}

function Get-AfDefaults {
  $d = @{}
  foreach ($f in 'Render', 'Capture') { foreach ($r in 'Console', 'Multimedia', 'Communications') {
    try { $d["$f/$r"] = [AfAudio.Api]::GetDefault([AfAudio.EDataFlow]$f, [AfAudio.ERole]$r) } catch {} } }
  $d
}
function Restore-AfDefaults($saved) {
  foreach ($k in $saved.Keys) {
    if (-not $saved[$k]) { continue }
    $f, $r = $k.Split('/')
    try { if ([AfAudio.Api]::GetDefault([AfAudio.EDataFlow]$f, [AfAudio.ERole]$r) -ne $saved[$k]) { [AfAudio.Api]::SetDefault($saved[$k], [AfAudio.ERole]$r) } } catch {}
  }
}

# VB-CABLE by VB-Audio (donationware: https://vb-audio.com/Cable/). We download the official
# driver pack from VB-Audio at install time - it is not part of the kit.
$AF_CABLE_PACKS = @(
  'https://download.vb-audio.com/Download_CABLE/VBCABLE_Driver_Pack46.zip',
  'https://download.vb-audio.com/Download_CABLE/VBCABLE_Driver_Pack45.zip',
  'https://download.vb-audio.com/Download_CABLE/VBCABLE_Driver_Pack43.zip'
)
function Install-AfCable([scriptblock]$Log = { param($t) Write-Host $t }) {
  if (Find-AfCable) { & $Log 'VB-CABLE is already installed.'; return $true }
  $saved = Get-AfDefaults
  $tmp = Join-Path $env:TEMP ('adfinem_vbcable_' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $zip = Join-Path $tmp 'vbcable.zip'; $ok = $false
  foreach ($u in $AF_CABLE_PACKS) {
    try { & $Log "Downloading VB-CABLE from vb-audio.com..."; Invoke-WebRequest -Uri $u -OutFile $zip -UseBasicParsing -TimeoutSec 60; $ok = $true; break } catch {}
  }
  if (-not $ok) { & $Log 'Could not download VB-CABLE (no internet?).'; return $false }
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [IO.Compression.ZipFile]::ExtractToDirectory($zip, $tmp)
  $arch = $env:PROCESSOR_ARCHITECTURE; if ($env:PROCESSOR_ARCHITEW6432) { $arch = $env:PROCESSOR_ARCHITEW6432 }
  $names = $(if ($arch -eq 'ARM64') { @('VBCABLE_Setup_arm64.exe', 'VBCABLE_Setup_ARM64.exe', 'VBCABLE_Setup_x64.exe') } elseif ($arch -eq 'AMD64') { @('VBCABLE_Setup_x64.exe') } else { @('VBCABLE_Setup.exe') })
  $setup = $null
  foreach ($n in $names) { $f = Get-ChildItem $tmp -Recurse -Filter $n -ErrorAction SilentlyContinue | Select-Object -First 1; if ($f) { $setup = $f.FullName; break } }
  if (-not $setup) { & $Log 'The VB-CABLE package looks different than expected.'; return $false }
  & $Log 'Installing VB-CABLE (Windows asks for permission)...'
  try {
    $p = Start-Process -FilePath $setup -ArgumentList '-i', '-h' -Verb RunAs -WorkingDirectory (Split-Path $setup) -PassThru -Wait
  } catch { & $Log 'VB-CABLE was not installed (permission was not given).'; return $false }
  for ($i = 0; $i -lt 20 -and -not (Find-AfCable); $i++) { Start-Sleep -Milliseconds 500 }
  Restore-AfDefaults $saved           # Windows likes to make a new device the default - put yours back
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  if (Find-AfCable) { & $Log 'VB-CABLE installed.'; return $true }
  & $Log 'VB-CABLE is installed but Windows needs a restart before it shows up.'
  return $false
}

function Get-AfAppProcess([string]$name) {
  Get-Process -Name $name -ErrorAction SilentlyContinue | Sort-Object StartTime | Select-Object -First 1
}
function Set-AfAppOutput([string]$app, [string]$deviceId) {
  $p = Get-AfAppProcess $app
  if (-not $p) { return $false }
  [AfAudio.Api]::SetAppDevice([uint32]$p.Id, $deviceId, [AfAudio.EDataFlow]::Render)
  return $true
}
function Get-AfAppOutput([string]$app) {
  $p = Get-AfAppProcess $app
  if (-not $p) { return $null }
  [AfAudio.Api]::GetAppDevice([uint32]$p.Id, [AfAudio.EDataFlow]::Render)
}

# Spotify: started for a moment if it is not running, so Windows can store its output device
function Find-AfSpotify {
  foreach ($c in @((Join-Path $env:APPDATA 'Spotify\Spotify.exe'), (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\Spotify.exe'))) {
    if (Test-Path $c) { return $c }
  }
  try { $pkg = Get-AppxPackage -Name '*Spotify*' -ErrorAction Stop | Select-Object -First 1; if ($pkg) { return 'spotify:' } } catch {}
  return $null
}
function Set-AfSpotifyToCable([scriptblock]$Log = { param($t) Write-Host $t }) {
  $cable = Find-AfCable
  if (-not $cable) { & $Log 'VB-CABLE not found - Spotify left as it is.'; return $false }
  $started = $false
  if (-not (Get-AfAppProcess 'Spotify')) {
    $exe = Find-AfSpotify
    if (-not $exe) { & $Log 'Spotify is not installed - you can send any app to "CABLE Input" later.'; return $false }
    try { Start-Process $exe -WindowStyle Minimized; $started = $true } catch { return $false }
    for ($i = 0; $i -lt 30 -and -not (Get-AfAppProcess 'Spotify'); $i++) { Start-Sleep -Milliseconds 500 }
    Start-Sleep -Seconds 2
  }
  try {
    if (Set-AfAppOutput 'Spotify' $cable.Input) { & $Log 'Spotify now plays into the stream music channel (CABLE Input).'; return $true }
  } catch { & $Log "Could not set Spotify's output: $($_.Exception.Message)" }
  return $false
}

# Uninstall: Spotify back to the Windows default device (it would otherwise keep playing into the cable)
function Reset-AfSpotify([scriptblock]$Log = { param($t) Write-Host $t }) {
  $started = $false
  if (-not (Get-AfAppProcess 'Spotify')) {
    $exe = Find-AfSpotify; if (-not $exe) { return }
    try { Start-Process $exe -WindowStyle Minimized; $started = $true } catch { return }
    for ($i = 0; $i -lt 30 -and -not (Get-AfAppProcess 'Spotify'); $i++) { Start-Sleep -Milliseconds 500 }
    Start-Sleep -Seconds 2
  }
  try { if (Set-AfAppOutput 'Spotify' '') { & $Log 'Spotify plays to your normal speakers/headset again.' } } catch {}
}

if ($MyInvocation.InvocationName -ne '.') {
  Get-AfEndpoints | Format-Table Flow, IsDefault, Name, Id -AutoSize
  $c = Find-AfCable; "VB-CABLE: " + $(if ($c) { "$($c.InputName) / $($c.OutputName)" } else { 'not installed' })
  $s = Get-AfAppOutput 'Spotify'; "Spotify output: " + $(if ($null -eq $s) { 'Spotify not running' } elseif ($s) { $s } else { 'Windows default' })
}
