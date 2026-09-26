; HOTSHOT CALIFORNIA - Setup.exe
; A silent wrapper: shows the VHS splash, unpacks the game to a temp folder
; and runs it in installer mode (--hotshot-install), where the game draws
; its own installer - the motel in the rain, the neon logo, the title
; music, the install as a tape rewinding (scripts/ui/installer.gd).
; Per-user install, so no admin prompt.
;   makensis -DVERSION=0.5.0 -DEXE=..\..\build\HotshotCalifornia.exe -DOUT=..\..\build\HOTSHOT_CALIFORNIA_Setup.exe installer/setup_bootstrap.nsi

Unicode true
SetCompressor /SOLID lzma
SetCompressorDictSize 64
RequestExecutionLevel user
SilentInstall silent
ManifestDPIAware true

!ifndef VERSION
  !define VERSION "0.5.0"
!endif
!ifndef EXE
  !define EXE "..\build\HotshotCalifornia.exe"
!endif
!ifndef OUT
  !define OUT "..\build\HOTSHOT_CALIFORNIA_Setup.exe"
!endif

Name "HOTSHOT CALIFORNIA"
Caption "HOTSHOT CALIFORNIA Setup"
OutFile "${OUT}"
Icon "..\icon.ico"
VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "HOTSHOT CALIFORNIA"
VIAddVersionKey "CompanyName" "Inverted Index Studio"
VIAddVersionKey "FileDescription" "HOTSHOT CALIFORNIA Setup"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "(c) 2026 Gilberto Lopes / Inverted Index Studio"

Section
  InitPluginsDir
  File "/oname=$PLUGINSDIR\splash.bmp" "art\splash.bmp"
  File "/oname=$PLUGINSDIR\splash.wav" "art\splash.wav"
  advsplash::show 1500 300 250 -1 "$PLUGINSDIR\splash"
  Pop $0
  File "/oname=$PLUGINSDIR\HotshotCalifornia.exe" "${EXE}"
  ExecWait '"$PLUGINSDIR\HotshotCalifornia.exe" --hotshot-install'
SectionEnd
