#!/bin/bash
# Parse-check every GDScript; prints "file:line message" for errors.
cd "$(dirname "$0")/.."
timeout 200 godot --headless --path . --import 2>&1 | grep -A1 "SCRIPT ERROR: Parse Error" | grep -v "^--" | paste - - | sed -E 's/SCRIPT ERROR: Parse Error: (.*)\s+at: GDScript::reload \((.*)\)/\2  \1/' | sort -u
