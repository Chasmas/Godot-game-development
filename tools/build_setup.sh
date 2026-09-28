#!/bin/bash
# Builds the Windows game and its installer without NSIS:
#   tools/build_setup.sh [path-to-godot]
# The game exe is its own installer: named "..._Setup.exe" it opens the
# themed setup (licence, folder, shortcuts, uninstall entry) and copies
# itself into place as HotshotCalifornia.exe (see scripts/systems/boot.gd
# and scripts/ui/installer.gd).
# Needs Godot 4.4.1 with its export templates installed.
# Output: ../build/HotshotCalifornia.exe and ../build/HOTSHOT_CALIFORNIA_<version>_Setup.exe
set -e
cd "$(dirname "$0")/.."
GODOT="${1:-${GODOT:-godot}}"
VERSION=$(grep '^config/version=' project.godot | sed -E 's/.*"([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
mkdir -p ../build
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Windows Desktop" ../build/HotshotCalifornia.exe
cp ../build/HotshotCalifornia.exe "../build/HOTSHOT_CALIFORNIA_${VERSION}_Setup.exe"
ls -la ../build
