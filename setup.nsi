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
Caption "${NAME} ${VERSION}"
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
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_RIGHT
!define MUI_HEADERIMAGE_BITMAP "kit\_system\setup\nsis-header.bmp"
!define MUI_HEADERIMAGE_UNBITMAP "kit\_system\setup\nsis-header.bmp"
!define MUI_PAGE_HEADER_TEXT "AD FINEM Stream Kit ${VERSION}"
!define MUI_PAGE_HEADER_SUBTEXT "Getting the setup ready - one moment..."
!define MUI_INSTFILESPAGE_FINISHHEADER_TEXT "Preparing the setup"
!define MUI_INSTFILESPAGE_FINISHHEADER_SUBTEXT ""
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"
AutoCloseWindow true
ShowInstDetails nevershow

;  $R0 = command line  ->  $0 = exit code ("error" if it could not start)
Function RunNoWindow
  System::Call '*(i 68, p 0, p 0, p 0, i 0, i 0, i 0, i 0, i 0, i 0, i 0, i 0, &i2 0, &i2 0, p 0, p 0, p 0, p 0)p.r1'
  System::Call '*(p 0, p 0, i 0, i 0)p.r2'
  System::Call 'kernel32::CreateProcessW(p 0, w R0, p 0, p 0, i 0, i 0x08000000, p 0, p 0, p r1, p r2)i.r3'
  StrCpy $0 "error"
  IntCmp $3 0 cleanup
  System::Call '*$2(p .r4, p .r5)'
  System::Call 'kernel32::WaitForSingleObject(p r4, i -1)'
  System::Call 'kernel32::GetExitCodeProcess(p r4, *i .r0)'
  System::Call 'kernel32::CloseHandle(p r4)'
  System::Call 'kernel32::CloseHandle(p r5)'
  cleanup:
  System::Free $1
  System::Free $2
FunctionEnd

Section "Install"
  DetailPrint "Unpacking the AD FINEM Stream Kit..."
  InitPluginsDir
  SetOutPath "$PLUGINSDIR\kit"
  File /r "kit\*.*"
  HideWindow
  ; the graphical setup: 0 = installed, 2 = cancelled, 3 = failed (already shown), other = could not start
  ; started with CREATE_NO_WINDOW: no console at all (with Windows Terminal as the default console,
  ; "-WindowStyle Hidden" still opens a terminal window)
  StrCpy $R0 '"$WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -STA -File "$PLUGINSDIR\kit\_system\setup\setup-gui.ps1"'
  Call RunNoWindow
  StrCmp $0 "0" registered
  StrCmp $0 "2" done
  StrCmp $0 "3" done
  ; fallback: the text installer in a console window
  ExecWait '"$WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$PLUGINSDIR\kit\_system\install.ps1"' $0
  StrCmp $0 "0" registered done
  registered:
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
  done:
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
