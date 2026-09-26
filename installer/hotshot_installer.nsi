; HOTSHOT CALIFORNIA - Windows installer (NSIS 3, Modern UI 2)
; Build with tools/build_windows.sh, or by hand:
;   makensis -DVERSION=0.4.0 -DEXE=..\..\build\HotshotCalifornia.exe -DOUT=..\..\build\HOTSHOT_CALIFORNIA_Setup.exe installer/hotshot_installer.nsi
; Installs per machine to Program Files, adds Start Menu + desktop shortcuts,
; registers an uninstaller in Apps & features. Saves live in the user's
; AppData (Godot user://) and are never touched by the uninstaller.

Unicode true
SetCompressor /SOLID lzma
RequestExecutionLevel admin
ManifestDPIAware true

!ifndef VERSION
  !define VERSION "0.4.0"
!endif
!ifndef EXE
  !define EXE "..\build\HotshotCalifornia.exe"
!endif
!ifndef OUT
  !define OUT "..\build\HOTSHOT_CALIFORNIA_Setup.exe"
!endif

!define APPNAME "HOTSHOT CALIFORNIA"
!define PUBLISHER "Inverted Index Studio"
!define EXENAME "HotshotCalifornia.exe"
!define UNINSTKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\HotshotCalifornia"

Name "${APPNAME}"
OutFile "${OUT}"
InstallDir "$PROGRAMFILES64\${APPNAME}"
InstallDirRegKey HKLM "${UNINSTKEY}" "InstallLocation"
BrandingText "${PUBLISHER}"

VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "${APPNAME}"
VIAddVersionKey "CompanyName" "${PUBLISHER}"
VIAddVersionKey "FileDescription" "${APPNAME} Setup"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "(c) 2026 Gilberto Lopes / ${PUBLISHER}"

!include "MUI2.nsh"
!include "x64.nsh"

!define MUI_ICON "..\icon.ico"
!define MUI_UNICON "..\icon.ico"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "${APPNAME}"
!define MUI_WELCOMEPAGE_TEXT "California, 1988. Somebody is filming.$\r$\n$\r$\nThis will install ${APPNAME} ${VERSION} on your computer.$\r$\n$\r$\nClick Next to continue."
!define MUI_FINISHPAGE_RUN "$INSTDIR\${EXENAME}"
!define MUI_FINISHPAGE_RUN_TEXT "Play ${APPNAME} now"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "Portuguese"

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "${APPNAME} needs a 64-bit version of Windows."
    Abort
  ${EndIf}
  SetRegView 64
  SetShellVarContext all   ; machine-wide install: shortcuts for every user
FunctionEnd

Function un.onInit
  SetRegView 64
  SetShellVarContext all
FunctionEnd

Section "Game" SecGame
  SectionIn RO
  SetOutPath "$INSTDIR"
  File "/oname=${EXENAME}" "${EXE}"
  File "/oname=${APPNAME}.ico" "..\icon.ico"
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  CreateDirectory "$SMPROGRAMS\${APPNAME}"
  CreateShortcut "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk" "$INSTDIR\${EXENAME}" "" "$INSTDIR\${EXENAME}" 0
  CreateShortcut "$SMPROGRAMS\${APPNAME}\Uninstall ${APPNAME}.lnk" "$INSTDIR\Uninstall.exe"
  CreateShortcut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\${EXENAME}" "" "$INSTDIR\${EXENAME}" 0

  WriteRegStr HKLM "${UNINSTKEY}" "DisplayName" "${APPNAME}"
  WriteRegStr HKLM "${UNINSTKEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "${UNINSTKEY}" "Publisher" "${PUBLISHER}"
  WriteRegStr HKLM "${UNINSTKEY}" "DisplayIcon" "$INSTDIR\${EXENAME},0"
  WriteRegStr HKLM "${UNINSTKEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${UNINSTKEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKLM "${UNINSTKEY}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
  WriteRegDWORD HKLM "${UNINSTKEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINSTKEY}" "NoRepair" 1
  SectionGetSize ${SecGame} $0
  WriteRegDWORD HKLM "${UNINSTKEY}" "EstimatedSize" $0
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\${EXENAME}"
  Delete "$INSTDIR\${APPNAME}.ico"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  Delete "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk"
  Delete "$SMPROGRAMS\${APPNAME}\Uninstall ${APPNAME}.lnk"
  RMDir "$SMPROGRAMS\${APPNAME}"
  Delete "$DESKTOP\${APPNAME}.lnk"
  DeleteRegKey HKLM "${UNINSTKEY}"
SectionEnd
