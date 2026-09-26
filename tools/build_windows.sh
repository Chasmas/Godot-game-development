#!/bin/bash
# Builds the Windows game exe and its installer.
#   tools/build_windows.sh [path-to-godot]
# Needs: Godot 4.4.1 + its export templates, NSIS (makensis). On Linux the
# exe icon/version info is written by rcedit through Wine (set in Godot's
# Editor Settings > Export > Windows); on Windows rcedit.exe alone.
# Output: ../build/HotshotCalifornia.exe and ../build/HOTSHOT_CALIFORNIA_Setup.exe
set -e
cd "$(dirname "$0")/.."
GODOT="${1:-${GODOT:-godot}}"
VERSION=$(grep '^config/version=' project.godot | sed -E 's/.*"([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
mkdir -p ../build
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Windows Desktop" ../build/HotshotCalifornia.exe
makensis -V2 -DVERSION="$VERSION" -DEXE="../../build/HotshotCalifornia.exe" -DOUT="../../build/HOTSHOT_CALIFORNIA_Setup.exe" installer/setup_bootstrap.nsi
ls -la ../build
