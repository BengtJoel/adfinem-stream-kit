; "Customize overlays.exe" - starts the AD FINEM overlay editor (kit\_system\editor.ps1) with no console window.
; An .exe because Stream Deck's "Open" action (and some launchers) do not run .bat files reliably.
; Built by .github/workflows/release.yml before the zip and the Setup: makensis launcher.nsi
Unicode true
Name "AD FINEM - Customize overlays"
OutFile "kit\Customize overlays.exe"
RequestExecutionLevel user
SilentInstall silent
Icon "kit\_system\adfinem.ico"
VIProductVersion "1.0.0.0"
VIAddVersionKey "ProductName" "AD FINEM Stream Kit"
VIAddVersionKey "FileDescription" "AD FINEM - Customize overlays"
VIAddVersionKey "CompanyName" "Ad Finem"
VIAddVersionKey "FileVersion" "1.0.0"
VIAddVersionKey "LegalCopyright" "Ad Finem"

Section
  IfFileExists "$EXEDIR\_system\editor.ps1" +3
    MessageBox MB_ICONEXCLAMATION "Please unzip the AD FINEM Stream Kit folder first, then run this again."
    Quit
  StrCpy $R0 '"$WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$EXEDIR\_system\editor.ps1"'
  System::Call '*(i 68, p 0, p 0, p 0, i 0, i 0, i 0, i 0, i 0, i 0, i 0, i 0, &i2 0, &i2 0, p 0, p 0, p 0, p 0)p.r1'
  System::Call '*(p 0, p 0, i 0, i 0)p.r2'
  ; CREATE_NO_WINDOW: the editor runs in the browser; it stops by itself after 45 minutes without use
  System::Call 'kernel32::CreateProcessW(p 0, w R0, p 0, p 0, i 0, i 0x08000000, p 0, w "$EXEDIR", p r1, p r2)i.r3'
  IntCmp $3 0 failed
  System::Call '*$2(p .r4, p .r5)'
  System::Call 'kernel32::CloseHandle(p r4)'
  System::Call 'kernel32::CloseHandle(p r5)'
  Goto done
  failed:
  Exec '"$EXEDIR\Customize overlays.bat"'
  done:
  System::Free $1
  System::Free $2
SectionEnd
