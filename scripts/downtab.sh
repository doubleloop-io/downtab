#!/usr/bin/env bash
# Local developer commands. CI only runs `build` and `test`: signing material never leaves this Mac.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/Downtab.app
EXE=Downtab
SIGNING_DIR=.signing
KEYCHAIN="$PWD/$SIGNING_DIR/downtab.keychain-db"
KEYCHAIN_PASSWORD=downtab

usage() {
  cat <<USAGE
./scripts/downtab.sh setup-signing   once per clone: create the self-signed certificate in a dedicated keychain
./scripts/downtab.sh build           debug build (swift build)
./scripts/downtab.sh test            check the core boundary, then run the tests (swift test)
./scripts/downtab.sh check-core      fail if the Switcher core imports anything but Foundation or calls private APIs
./scripts/downtab.sh bundle          release build, assemble and sign $APP
./scripts/downtab.sh run             bundle, then launch the app (stops a running instance first)
./scripts/downtab.sh stop            quit the running app
USAGE
}

# Workaround: with Swift 6.4's default build system, any `swift build` before `swift test` drops the
# Swift Testing macro plugin path ("plugin for module 'TestingMacros' not found"). Passing it explicitly
# on every build and test keeps the build configuration identical across commands.
swiftpm() {
  local plugins; plugins="$(dirname "$(xcrun -f swift)")/../lib/swift/host/plugins/testing"
  swift "$@" -Xswiftc -plugin-path -Xswiftc "$plugins"
}

identity() { openssl x509 -in "$SIGNING_DIR/cert.crt" -noout -fingerprint -sha1 | cut -d= -f2 | tr -d :; }

setup_signing() {
  [ -f "$KEYCHAIN" ] && { echo "already done: $KEYCHAIN"; return; }
  mkdir -p "$SIGNING_DIR"
  cat > "$SIGNING_DIR/cert.conf" <<CERT_CONF
[ req ]
distinguished_name = dn
prompt = no
[ dn ]
CN = Downtab Local
[ ext ]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,1.3.6.1.5.5.7.3.3
CERT_CONF
  openssl req -x509 -new -newkey rsa:2048 -nodes -days 3650 -config "$SIGNING_DIR/cert.conf" -extensions ext \
    -keyout "$SIGNING_DIR/cert.key" -out "$SIGNING_DIR/cert.crt" 2>/dev/null
  openssl pkcs12 -legacy -export -inkey "$SIGNING_DIR/cert.key" -in "$SIGNING_DIR/cert.crt" -out "$SIGNING_DIR/cert.p12" -passout pass:$KEYCHAIN_PASSWORD
  # create-keychain adds to the user's search list; restore it so the login keychain setup stays untouched.
  local saved; saved=$(security list-keychains -d user | tr -d '"')
  security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
  # shellcheck disable=SC2086
  security list-keychains -d user -s $saved
  security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
  security import "$SIGNING_DIR/cert.p12" -k "$KEYCHAIN" -P "$KEYCHAIN_PASSWORD" -T /usr/bin/codesign >/dev/null
  security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
  echo "ok, identity $(identity)"
}

# Allowlist, not denylist: any import form (`import class X.Y`, `internal import X`, `@_exported import X`)
# of a module outside this list fails, so AppKit, AX (ApplicationServices, HIServices) and private frameworks stay out.
CORE_ALLOWED_MODULES="Foundation"

check_core() {
  local violations
  violations=$(grep -rnE '^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*((public|package|internal|fileprivate|private)[[:space:]]+)?import[[:space:]]' Sources/SwitcherCore \
    | awk -v allowed=" $CORE_ALLOWED_MODULES " '{
        line = $0; sub(/^[^:]*:[0-9]+:/, "", line)
        n = split(line, w, /[[:space:]]+/)
        for (i = 1; i <= n; i++) if (w[i] == "import") break
        m = w[i + 1]
        if (m ~ /^(class|struct|enum|protocol|typealias|func|var|let)$/) m = w[i + 2]
        sub(/\..*/, "", m)
        if (index(allowed, " " m " ") == 0) print
      }' || true)
  violations+=$(grep -rnE '@_silgen_name|dlopen|dlsym' Sources/SwitcherCore || true)
  if [ -n "$violations" ]; then
    echo "$violations"
    echo "Switcher core must stay pure (allowed imports: $CORE_ALLOWED_MODULES): remove the lines above"; exit 1
  fi
  echo "core boundary ok"
}

quit_running_app() {
  pkill -x "$EXE" || return 1
  # `open` would reactivate a still-exiting instance instead of launching the new build.
  while pgrep -x "$EXE" >/dev/null; do sleep 0.1; done
}

bundle() {
  [ -f "$KEYCHAIN" ] || { echo "signing missing: run ./scripts/downtab.sh setup-signing"; exit 1; }
  swiftpm build -c release --product "$EXE"
  rm -rf "$APP"
  mkdir -p "$APP/Contents/MacOS"
  cp "$(swift build -c release --show-bin-path)/$EXE" "$APP/Contents/MacOS/$EXE"
  cp App/Info.plist "$APP/Contents/Info.plist"
  security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
  codesign --force --keychain "$KEYCHAIN" -s "$(identity)" "$APP"
  codesign --verify "$APP" && codesign -d -r- "$APP" 2>&1 | grep designated
}

run() {
  quit_running_app || true
  bundle
  # Launch through LaunchServices so macOS attributes permissions to the bundle, not to the terminal.
  open "$APP"
  echo "running: look for the Downtab icon in the menu bar"
}

cmd="${1:-}"; [ $# -gt 0 ] && shift
case "$cmd" in
  setup-signing) setup_signing ;;
  build) swiftpm build ;;
  test) check_core; swiftpm test ;;
  check-core) check_core ;;
  bundle) bundle ;;
  run) run ;;
  stop) quit_running_app && echo stopped || echo "not running" ;;
  *) usage ;;
esac
