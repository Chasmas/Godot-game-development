#!/bin/bash
# Runs every automated test headless: smoke (full playthrough), edge cases,
# enemy stress. Usage: tools/run_tests.sh [path-to-godot]
# Each suite has a hard wall-clock limit so a hang fails instead of stalling.
cd "$(dirname "$0")/.."
GODOT="${1:-${GODOT:-godot}}"
status=0
timeout 300 "$GODOT" --headless --path . --import >/dev/null 2>&1
for suite in smoke_test edge_test chapter3_test stress_test; do
	echo "=== $suite"
	timeout 600 "$GODOT" --headless --path . "res://tools/$suite.tscn" --quit-after 120000 2>&1 \
		| grep -E "^\s+(ok|FAIL)|FAIL|DONE|SCRIPT ERROR|^\s+[0-9]+ +[0-9]" 
	code=${PIPESTATUS[0]}
	[ "$code" -ne 0 ] && status=1 && echo "!!! $suite exited with $code"
done
echo "=== i18n coverage"
for loc in data/i18n/*.json; do
	name=$(basename "$loc" .json)
	case "$name" in _*) continue ;; esac
	python3 tools/i18n_extract.py --check "$name" | tail -1 || status=1
done
exit $status
