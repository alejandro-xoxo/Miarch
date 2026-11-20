#!/usr/bin/env bash
# After-change checks. Usage: check.sh [file ...]
# Looks for the usual breakages: Hyprland config errors, Quickshell (desktop) errors and syntax errors in the files you give.
# It never changes anything. Exit code 1 if something failed.
fallos=0
ok()   { echo "[OK] $*"; }
mal()  { echo "[FAIL] $*"; fallos=$((fallos + 1)); }
nota() { echo "[--] $*"; }

if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    e="$(hyprctl configerrors 2>&1 | head -5)"
    if [ -z "$e" ]; then ok "Hyprland: no config errors"; else mal "Hyprland config errors:"; echo "$e" | sed 's/^/      /'; fi
else
    nota "Hyprland is not running here: config check skipped"
fi

if command -v qs >/dev/null 2>&1 && pgrep -x qs >/dev/null 2>&1; then
    # the log covers the whole session, so an old error also shows: compare with a run before your change if in doubt
    errores="$(qs log -c miarch 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -i "error" | tail -3)"
    if [ -z "$errores" ]; then ok "Quickshell: no errors in the log"; else mal "Quickshell log has errors (last lines):"; echo "$errores" | sed 's/^/      /' | cut -c1-160; fi
else
    nota "Quickshell is not running: desktop check skipped"
fi

for f in "$@"; do
    if [ ! -f "$f" ]; then mal "$f: no such file"; continue; fi
    case "$f" in
        *.py)   python3 -I -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$f" 2>&1 && ok "$f: python syntax" || mal "$f: python syntax" ;;
        *.json) python3 -I -c "import json,sys; json.load(open(sys.argv[1]))" "$f" 2>&1 && ok "$f: valid json" || mal "$f: invalid json" ;;
        *.lua)  if command -v luac >/dev/null 2>&1; then luac -p "$f" 2>&1 && ok "$f: lua syntax" || mal "$f: lua syntax"; else nota "$f: luac not installed (hyprctl configerrors covers Hyprland files)"; fi ;;
        *)      if head -1 "$f" | grep -q -E '^#!.*(ba)?sh'; then bash -n "$f" 2>&1 && ok "$f: shell syntax" || mal "$f: shell syntax"; else nota "$f: no check for this file type"; fi ;;
    esac
done

[ "$fallos" -eq 0 ] && echo "All checks passed." || echo "$fallos check(s) failed."
exit $(( fallos > 0 ))
