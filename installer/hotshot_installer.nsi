; HOTSHOT CALIFORNIA - Windows installer (NSIS 3, Modern UI 2)
; Build with tools/build_windows.sh, or by hand:
;   makensis -DVERSION=0.4.0 -DEXE=..\..\build\HotshotCalifornia.exe -DOUT=..\..\build\HOTSHOT_CALIFORNIA_Setup.exe installer/hotshot_installer.nsi
; Installs per machine to Program Files, adds Start Menu + desktop shortcuts,
; registers an uninstaller in Apps & features. Saves live in the user's
; AppData (Godot user://) and are never touched by the uninstaller.
;
; Look: the game's title screen. VHS splash with tape static, a sunset
; sidebar and neon header (installer/art, built by installer/make_art.py from
; the game's own title renders), dark ink windows with cream text, a pink
; progress bar and a cyan install log. Copy is written in the game's voice
; and localized (English / Portuguese, picked from the Windows language).

Unicode true
SetCompressor /SOLID lzma
SetCompressorDictSize 64
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

; the game's palette (RRGGBB for NSIS colour options)
!define C_INK   "0B0614"
!define C_PAPER "F4F0E8"
!define C_DIM   "8A7FA0"
!define C_PINK  "FF3D7F"
!define C_CYAN  "35E0FF"

Name "${APPNAME}"
Caption "${APPNAME}  ${VERSION}"
OutFile "${OUT}"
InstallDir "$PROGRAMFILES64\${APPNAME}"
InstallDirRegKey HKLM "${UNINSTKEY}" "InstallLocation"
BrandingText "${PUBLISHER}  ·  v${VERSION}"

VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "${APPNAME}"
VIAddVersionKey "CompanyName" "${PUBLISHER}"
VIAddVersionKey "FileDescription" "${APPNAME} Setup"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "(c) 2026 Gilberto Lopes / ${PUBLISHER}"

!include "MUI2.nsh"
!include "x64.nsh"
!include "WinMessages.nsh"

; ---------------------------------------------------------------- look
!define MUI_ICON "..\icon.ico"
!define MUI_UNICON "..\icon.ico"
!define MUI_BGCOLOR "${C_INK}"
!define MUI_TEXTCOLOR "${C_PAPER}"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_RIGHT
!define MUI_HEADERIMAGE_BITMAP "art\header.bmp"
!define MUI_HEADERIMAGE_UNBITMAP "art\header.bmp"
!define MUI_HEADER_TRANSPARENT_TEXT
!define MUI_WELCOMEFINISHPAGE_BITMAP "art\sidebar.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "art\sidebar.bmp"
!define MUI_INSTFILESPAGE_COLORS "${C_CYAN} ${C_INK}"
!define MUI_INSTFILESPAGE_PROGRESSBAR "colored"
!define MUI_ABORTWARNING
!define MUI_UNABORTWARNING
!define MUI_CUSTOMFUNCTION_GUIINIT hsGuiInit
!define MUI_CUSTOMFUNCTION_UNGUIINIT un.hsGuiInit

; ---------------------------------------------------------------- pages
!define MUI_WELCOMEPAGE_TITLE "$(WelcomeTitle)"
!define MUI_WELCOMEPAGE_TITLE_3LINES
!define MUI_WELCOMEPAGE_TEXT "$(WelcomeText)"
!insertmacro MUI_PAGE_WELCOME
!define MUI_PAGE_HEADER_TEXT "$(DirHeader)"
!define MUI_PAGE_HEADER_SUBTEXT "$(DirSub)"
!define MUI_DIRECTORYPAGE_TEXT_TOP "$(DirText)"
!define MUI_PAGE_CUSTOMFUNCTION_SHOW DarkInner
!insertmacro MUI_PAGE_DIRECTORY
!define MUI_PAGE_HEADER_TEXT "$(InstHeader)"
!define MUI_PAGE_HEADER_SUBTEXT "$(InstSub)"
!define MUI_INSTFILESPAGE_FINISHHEADER_TEXT "$(InstDoneHeader)"
!define MUI_INSTFILESPAGE_FINISHHEADER_SUBTEXT "$(InstDoneSub)"
!define MUI_PAGE_CUSTOMFUNCTION_SHOW DarkInner
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_TITLE "$(FinishTitle)"
!define MUI_FINISHPAGE_TITLE_3LINES
!define MUI_FINISHPAGE_TEXT "$(FinishText)"
!define MUI_FINISHPAGE_RUN "$INSTDIR\${EXENAME}"
!define MUI_FINISHPAGE_RUN_TEXT "$(FinishRun)"
!insertmacro MUI_PAGE_FINISH

!define MUI_WELCOMEPAGE_TITLE "$(UnWelcomeTitle)"
!define MUI_WELCOMEPAGE_TITLE_3LINES
!define MUI_WELCOMEPAGE_TEXT "$(UnWelcomeText)"
!insertmacro MUI_UNPAGE_WELCOME
!define MUI_PAGE_CUSTOMFUNCTION_SHOW un.DarkInner
!insertmacro MUI_UNPAGE_CONFIRM
!define MUI_PAGE_CUSTOMFUNCTION_SHOW un.DarkInner
!insertmacro MUI_UNPAGE_INSTFILES
!define MUI_FINISHPAGE_TITLE "$(UnFinishTitle)"
!define MUI_FINISHPAGE_TITLE_3LINES
!define MUI_FINISHPAGE_TEXT "$(UnFinishText)"
!insertmacro MUI_UNPAGE_FINISH

!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "Portuguese"

; ---------------------------------------------------------------- copy
LangString WelcomeTitle   ${LANG_ENGLISH} "Rolling. Speed.$\r$\nHOTSHOT CALIFORNIA."
LangString WelcomeTitle   ${LANG_PORTUGUESE} "A gravar. Velocidade.$\r$\nHOTSHOT CALIFORNIA."
LangString WelcomeText    ${LANG_ENGLISH} "California, 1988. There's a package on your doorstep, a motel in Barstow, and somebody filming everything.$\r$\n$\r$\nThis will install ${APPNAME} ${VERSION}.$\r$\n$\r$\nClick Next when you're ready for your close-up."
LangString WelcomeText    ${LANG_PORTUGUESE} "Califórnia, 1988. Há um embrulho à sua porta, um motel em Barstow e alguém a filmar tudo.$\r$\n$\r$\nVai ser instalado ${APPNAME} ${VERSION}.$\r$\n$\r$\nClique em Seguinte para o grande plano."
LangString DirHeader      ${LANG_ENGLISH} "Location scouting"
LangString DirHeader      ${LANG_PORTUGUESE} "Escolha de local"
LangString DirSub         ${LANG_ENGLISH} "Where should we set up the shoot?"
LangString DirSub         ${LANG_PORTUGUESE} "Onde vamos montar a rodagem?"
LangString DirText        ${LANG_ENGLISH} "${APPNAME} will be installed in the folder below. To pick another location, click Browse."
LangString DirText        ${LANG_PORTUGUESE} "${APPNAME} vai ser instalado na pasta abaixo. Para escolher outro local, clique em Procurar."
LangString InstHeader     ${LANG_ENGLISH} "Loading the tape..."
LangString InstHeader     ${LANG_PORTUGUESE} "A carregar a cassete..."
LangString InstSub        ${LANG_ENGLISH} "Rewinding. Please be kind."
LangString InstSub        ${LANG_PORTUGUESE} "A rebobinar. Seja simpático."
LangString InstDoneHeader ${LANG_ENGLISH} "Tape loaded"
LangString InstDoneHeader ${LANG_PORTUGUESE} "Cassete carregada"
LangString InstDoneSub    ${LANG_ENGLISH} "Everything is on set."
LangString InstDoneSub    ${LANG_PORTUGUESE} "Está tudo no plateau."
LangString FinishTitle    ${LANG_ENGLISH} "That's a wrap."
LangString FinishTitle    ${LANG_PORTUGUESE} "Está feito."
LangString FinishText     ${LANG_ENGLISH} "${APPNAME} is installed. You'll find it in the Start menu and on your desktop.$\r$\n$\r$\nSomebody's filming. Make it look good."
LangString FinishText     ${LANG_PORTUGUESE} "${APPNAME} está instalado. Vai encontrá-lo no menu Iniciar e no ambiente de trabalho.$\r$\n$\r$\nAlguém está a filmar. Faça com que fique bonito."
LangString FinishRun      ${LANG_ENGLISH} "Action! (play now)"
LangString FinishRun      ${LANG_PORTUGUESE} "Ação! (jogar agora)"
LangString UnWelcomeTitle ${LANG_ENGLISH} "Cut."
LangString UnWelcomeTitle ${LANG_PORTUGUESE} "Corta."
LangString UnWelcomeText  ${LANG_ENGLISH} "This will remove ${APPNAME} from your computer.$\r$\n$\r$\nYour saves and settings stay where they are, in case you want another take."
LangString UnWelcomeText  ${LANG_PORTUGUESE} "Isto vai remover ${APPNAME} do seu computador.$\r$\n$\r$\nOs seus jogos guardados e definições ficam onde estão, para o caso de querer outro take."
LangString UnFinishTitle  ${LANG_ENGLISH} "Print it."
LangString UnFinishTitle  ${LANG_PORTUGUESE} "Fica esse."
LangString UnFinishText   ${LANG_ENGLISH} "${APPNAME} has been removed.$\r$\n$\r$\nThanks for watching. Be kind, rewind."
LangString UnFinishText   ${LANG_PORTUGUESE} "${APPNAME} foi removido.$\r$\n$\r$\nObrigado por assistir. Seja simpático, rebobine."
LangString Need64         ${LANG_ENGLISH} "${APPNAME} needs a 64-bit version of Windows."
LangString Need64         ${LANG_PORTUGUESE} "${APPNAME} precisa de uma versão de 64 bits do Windows."

; ---------------------------------------------------------------- theming
; Paint a dialog and everything in it in the game's colours. Buttons keep the
; system look (Windows doesn't let installers recolour them); labels, text
; fields, group boxes and lists go dark.
!macro DARKEN_DIALOG HWND
  SetCtlColors ${HWND} ${C_PAPER} ${C_INK}
  StrCpy $R9 0
  !define /redef _L ${__LINE__}
  loop${_L}:
    FindWindow $R9 "" "" ${HWND} $R9
    StrCmp $R9 0 done${_L}
    SetCtlColors $R9 ${C_PAPER} ${C_INK}
    Goto loop${_L}
  done${_L}:
!macroend

!macro THEME_MAIN
  ; main window: dark body, dim branding line
  !insertmacro DARKEN_DIALOG $HWNDPARENT
  GetDlgItem $0 $HWNDPARENT 1028
  SetCtlColors $0 ${C_DIM} ${C_INK}
  GetDlgItem $0 $HWNDPARENT 1256
  SetCtlColors $0 ${C_DIM} ${C_INK}
  ; page title in neon pink, subtitle in cream, over the dark header
  GetDlgItem $0 $HWNDPARENT 1037
  SetCtlColors $0 ${C_PINK} transparent
  GetDlgItem $0 $HWNDPARENT 1038
  SetCtlColors $0 ${C_PAPER} transparent
!macroend

Function hsGuiInit
  !insertmacro THEME_MAIN
FunctionEnd

Function un.hsGuiInit
  !insertmacro THEME_MAIN
FunctionEnd

Function DarkInner
  FindWindow $1 "#32770" "" $HWNDPARENT
  !insertmacro DARKEN_DIALOG $1
FunctionEnd

Function un.DarkInner
  FindWindow $1 "#32770" "" $HWNDPARENT
  !insertmacro DARKEN_DIALOG $1
FunctionEnd

; ---------------------------------------------------------------- init
Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "$(Need64)"
    Abort
  ${EndIf}
  SetRegView 64
  SetShellVarContext all   ; machine-wide install: shortcuts for every user
  ; VHS splash with tape static while the installer opens
  IfSilent splash_done
  InitPluginsDir
  File "/oname=$PLUGINSDIR\splash.bmp" "art\splash.bmp"
  File "/oname=$PLUGINSDIR\splash.wav" "art\splash.wav"
  advsplash::show 1700 350 250 -1 "$PLUGINSDIR\splash"
  Pop $0
  splash_done:
FunctionEnd

Function un.onInit
  SetRegView 64
  SetShellVarContext all
FunctionEnd

; ---------------------------------------------------------------- install
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
