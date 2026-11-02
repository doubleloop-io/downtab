#!/usr/bin/env bash
# Launches the bundle, posts synthetic keyboard events and fails if the app died or left a crash report.
# Posting events needs the Accessibility permission for the terminal running this script.
set -euo pipefail
APP=${1:?usage: smoke.sh path/to/Downtab.app}
EXE=Downtab
REPORTS="$HOME/Library/Logs/DiagnosticReports"
TAP_STARTED="modifier release tap started"
WORK=$(mktemp -d)
LOG_PID=
trap 'kill "$LOG_PID" 2>/dev/null || true; pkill -x "$EXE" || true; rm -rf "$WORK"' EXIT

crash_reports() { find "$REPORTS" -maxdepth 1 -name "$EXE*" 2>/dev/null | sort; }
fail() { echo "smoke failed: $*"; exit 1; }

crash_reports >"$WORK/before"
log stream --level info --predicate 'subsystem == "local.downtab"' >"$WORK/log" &
LOG_PID=$!
sleep 1

open "$APP"
# Without the tap the ⌥ events would reach no thread-crossing code, and the smoke would pass for nothing.
for _ in $(seq 50); do grep -q "$TAP_STARTED" "$WORK/log" && break; sleep 0.1; done
grep -q "$TAP_STARTED" "$WORK/log" \
  || fail "modifier release tap not started: is the Accessibility permission granted to Downtab?"

# key code 48 = Tab, 53 = Esc. ⌥Tab and ⌥⇧Tab release ⌥ at the end, so each one confirms.
osascript >/dev/null <<'EOF' || fail "cannot post events: grant the Accessibility permission to this terminal"
tell application "System Events"
    key down option
    delay 0.2
    key up option
    delay 0.2
    key code 48 using option down
    delay 0.5
    key code 48 using {option down, shift down}
    delay 0.5
    key down option
    key code 48
    delay 0.3
    key code 53
    key up option
end tell
EOF
sleep 2

pgrep -x "$EXE" >/dev/null || fail "$EXE is no longer running"
crash_reports >"$WORK/after"
new_reports=$(comm -13 "$WORK/before" "$WORK/after")
[ -z "$new_reports" ] || fail "new crash report: $new_reports"
echo "smoke ok"
