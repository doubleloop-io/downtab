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

# The events below assume the default shortcuts: pin them for this launch only, through the volatile argument
# domain, so the user's own preferences neither break the smoke nor get overwritten.
shortcut_arg() { printf '<%s>' "$(printf '{"modifiers":["option"],"keyCode":%d}' "$1" | xxd -p | tr -d '\n')"; }
# Keystrokes that reach the terminal instead of Downtab would be read by the shell after the script exits.
discard_typeahead() { [ -t 0 ] && while read -r -s -t 1 -n 1000 _; do :; done || true; }

crash_reports() { find "$REPORTS" -maxdepth 1 -name "$EXE*" 2>/dev/null | sort; }
fail() { echo "smoke failed: $*"; exit 1; }

# A locked screen or another app holding secure input swallows the posted events: the smoke would fail looking like a
# Downtab bug.
console_session() { ioreg -n Root -d1 -w0 | grep IOConsoleUsers; }
console_session | grep -q '"CGSSessionScreenIsLocked"=Yes' && fail "the screen is locked: unlock it and run again"
secure_input_pid=$(console_session | grep -o '"kCGSSessionSecureInputPID"=[0-9]*' | cut -d= -f2 || true)
[ -z "$secure_input_pid" ] \
  || fail "secure input is on (held by $(ps -o comm= -p "$secure_input_pid" || echo "pid $secure_input_pid")): close the password prompt or app holding it and run again"

crash_reports >"$WORK/before"
log stream --level info --predicate 'subsystem == "io.doubleloop.downtab"' >"$WORK/log" &
LOG_PID=$!
sleep 1

open "$APP" --args -appShortcut "$(shortcut_arg 48)" -windowShortcut "$(shortcut_arg 50)"
# Without the tap the ⌥ events would reach no thread-crossing code, and the smoke would pass for nothing.
for _ in $(seq 50); do grep -q "$TAP_STARTED" "$WORK/log" && break; sleep 0.1; done
grep -q "$TAP_STARTED" "$WORK/log" \
  || fail "modifier release tap not started: is the Accessibility permission granted to Downtab?"

# key code 48 = Tab, 50 = `, 53 = Esc. ⌥Tab, ⌥⇧Tab, ⌥` and ⌥⇧` release ⌥ at the end, so each one confirms.
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
    key code 50 using option down
    delay 0.5
    key code 50 using {option down, shift down}
    delay 0.5
    key down option
    key code 48
    delay 0.3
    key code 53
    key up option
end tell
EOF
sleep 2
discard_typeahead

grep -q "activate pid=" "$WORK/log" || fail "no switch happened: Downtab did not intercept the posted shortcuts"
pgrep -x "$EXE" >/dev/null || fail "$EXE is no longer running"
crash_reports >"$WORK/after"
new_reports=$(comm -13 "$WORK/before" "$WORK/after")
[ -z "$new_reports" ] || fail "new crash report: $new_reports"
echo "smoke ok"
