; AD FINEM Stream Kit - Windows installer (NSIS 3). Built by .github/workflows/release.yml (or: makensis -DVERSION=1.0.0 setup.nsi)
; Installs per user (no admin). The real work is done by kit\_system\install.ps1 (same as INSTALL.bat),
; which keeps the streamer's settings, sponsors, Twitch connection and OBS picks on updates.
Unicode true
!ifndef VERSION
  !define VERSION "1.0.0"
!endif
!define NAME "AD FINEM Stream Kit"
!define UNKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\ADFINEMStreamKit"

Name "${NAME}"
OutFile "release\AD-FINEM-Stream-Kit-Setup.exe"
RequestExecutionLevel user
InstallDir "$LOCALAPPDATA\AD FINEM Stream Kit"
SetCompressor /SOLID lzma
BrandingText "Ad Finem - to the end"
VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "${NAME}"
VIAddVersionKey "FileDescription" "${NAME} Setup"
VIAddVersionKey "CompanyName" "Ad Finem"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "Ad Finem"

!include "MUI2.nsh"
!define MUI_ICON "kit\_system\adfinem.ico"
!define MUI_UNICON "kit\_system\adfinem.ico"
!define MUI_WELCOMEPAGE_TITLE "AD FINEM Stream Kit ${VERSION}"
!define MUI_WELCOMEPAGE_TEXT "This sets up the AD FINEM stream package:$\r$\n$\r$\n  - OBS scenes, overlays, intro/outro and stinger$\r$\n  - Alerts, sponsors and live raid progress$\r$\n  - The overlay editor and a Stream Deck page$\r$\n$\r$\nUpdating? Your texts, sponsors, Twitch connection, webcam and game capture are kept.$\r$\n$\r$\nA window shows the steps. If OBS is open it asks you to close it."
!define MUI_FINISHPAGE_TITLE "Ready - to the end"
!define MUI_FINISHPAGE_TEXT "Open OBS and pick Scene Collection > AD FINEM.$\r$\n$\r$\nChange texts, alerts and sponsors with $\"AD FINEM - Customize overlays$\" on your desktop. Updates are offered automatically."
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Open the overlay editor"
!define MUI_FINISHPAGE_RUN_FUNCTION OpenEditor
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Function OpenEditor
  Exec '"$WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File "$DOCUMENTS\AD FINEM Stream Kit\_system\editor.ps1"'
FunctionEnd

Section "Install"
  InitPluginsDir
  SetOutPath "$PLUGINSDIR\kit"
  File /r "kit\*.*"
  DetailPrint "Setting up the kit and OBS (see the window)..."
  StrCpy $1 ""
  IfSilent 0 +2
    StrCpy $1 "-Quiet"
  ExecWait '"$WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$PLUGINSDIR\kit\_system\install.ps1" $1' $0
  IntCmp $0 0 setup_ok
    MessageBox MB_ICONEXCLAMATION "The setup step reported a problem (code $0). Run INSTALL.bat in Documents\AD FINEM Stream Kit to see what happened."
  setup_ok:
  SetOutPath "$INSTDIR"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  File "kit\_system\adfinem.ico"
  WriteRegStr HKCU "${UNKEY}" "DisplayName" "${NAME}"
  WriteRegStr HKCU "${UNKEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNKEY}" "Publisher" "Ad Finem"
  WriteRegStr HKCU "${UNKEY}" "URLInfoAbout" "https://ad-finem.eu"
  WriteRegStr HKCU "${UNKEY}" "DisplayIcon" "$INSTDIR\adfinem.ico"
  WriteRegStr HKCU "${UNKEY}" "InstallLocation" "$DOCUMENTS\AD FINEM Stream Kit"
  WriteRegStr HKCU "${UNKEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegDWORD HKCU "${UNKEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNKEY}" "NoRepair" 1
SectionEnd

Section "Uninstall"
  ExecWait '"$WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$DOCUMENTS\AD FINEM Stream Kit\_system\uninstall.ps1" -Quiet'
  MessageBox MB_YESNO|MB_ICONQUESTION "Also delete the kit folder (Documents\AD FINEM Stream Kit) with your texts, sponsors and Twitch connection?" IDNO keep
    RMDir /r "$DOCUMENTS\AD FINEM Stream Kit"
  keep:
  DeleteRegKey HKCU "${UNKEY}"
  Delete "$INSTDIR\Uninstall.exe"
  Delete "$INSTDIR\adfinem.ico"
  RMDir "$INSTDIR"
SectionEnd
