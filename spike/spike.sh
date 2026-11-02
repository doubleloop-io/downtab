#!/usr/bin/env bash
# Single entry point for the throwaway spike. See commands in usage().
set -euo pipefail
cd "$(dirname "$0")"

APP=build/DowntabSpike.app
EXE=DowntabSpike
SIGN=.signing
KC="$PWD/$SIGN/spike.keychain-db"
KC_PASS=spike
LOG=build/spike.log

usage() {
  cat <<U
./spike.sh setup-signing              una tantum: crea il certificato in un keychain dedicato
./spike.sh build                      compila e firma il bundle
./spike.sh start [--timeout S] [--focus public|private]   default: 300 s, public
./spike.sh stop                       arresta (anche: ⌃⌥⇧Q, o il timeout)
./spike.sh list                       scrive l'inventario su build/list.txt e lo stampa
./spike.sh log                        segue il log
./spike.sh stats                      riassume il log dell'ultima esecuzione
U
}

identity() { openssl x509 -in "$SIGN/cert.crt" -noout -fingerprint -sha1 | cut -d= -f2 | tr -d :; }

setup_signing() {
  [ -f "$KC" ] && { echo "già fatto: $KC"; return; }
  mkdir -p "$SIGN"
  cat > "$SIGN/cert.conf" <<C
[ req ]
distinguished_name = dn
prompt = no
[ dn ]
CN = DowntabSpike Local
[ ext ]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,1.3.6.1.5.5.7.3.3
C
  openssl req -x509 -new -newkey rsa:2048 -nodes -days 3650 -config "$SIGN/cert.conf" -extensions ext \
    -keyout "$SIGN/cert.key" -out "$SIGN/cert.crt" 2>/dev/null
  openssl pkcs12 -legacy -export -inkey "$SIGN/cert.key" -in "$SIGN/cert.crt" -out "$SIGN/cert.p12" -passout pass:$KC_PASS
  # create-keychain adds to the user's search list; restore it so the login keychain setup stays untouched.
  local saved; saved=$(security list-keychains -d user | tr -d '"')
  security create-keychain -p "$KC_PASS" "$KC"
  # shellcheck disable=SC2086
  security list-keychains -d user -s $saved
  security unlock-keychain -p "$KC_PASS" "$KC"
  security import "$SIGN/cert.p12" -k "$KC" -P "$KC_PASS" -T /usr/bin/codesign >/dev/null
  security set-key-partition-list -S apple-tool:,apple: -s -k "$KC_PASS" "$KC" >/dev/null
  echo "ok, identità $(identity)"
}

build() {
  [ -f "$KC" ] || { echo "manca la firma: esegui ./spike.sh setup-signing"; exit 1; }
  mkdir -p "$APP/Contents/MacOS" build/module-cache
  swiftc -swift-version 5 -O -module-cache-path build/module-cache \
    -framework AppKit -framework Carbon -framework ApplicationServices \
    Sources/*.swift -o "$APP/Contents/MacOS/$EXE"
  cp Info.plist "$APP/Contents/Info.plist"
  security unlock-keychain -p "$KC_PASS" "$KC"
  codesign --force --keychain "$KC" -s "$(identity)" "$APP"
  codesign --verify "$APP" && codesign -d -r- "$APP" 2>&1 | grep designated
}

start() {
  [ -x "$APP/Contents/MacOS/$EXE" ] || { echo "esegui prima ./spike.sh build"; exit 1; }
  pkill -x "$EXE" 2>/dev/null || true
  [ -f "$LOG" ] && mv "$LOG" build/spike.prev.log
  open "$APP" --args "$@"
  sleep 1
  cat "$LOG"
  if pgrep -x "$EXE" >/dev/null; then
    echo "--> IN ESECUZIONE in background. Il prompt torna subito: è normale. Arresto: ./spike.sh stop oppure ⌃⌥⇧Q"
  else
    echo "--> NON in esecuzione: guarda il log qui sopra"
  fi
}

stats() {
  awk '
    / open /      { for (i=1;i<=NF;i++) { if ($i ~ /^visible_ms=/) { split($i,a,"="); v[++n]=a[2] }
                    if ($i ~ /^apps=/) { split($i,a,"="); if (a[2]>maxa) maxa=a[2] }
                    if ($i ~ /^windows=/) { split($i,a,"="); if (a[2]>maxw) maxw=a[2] } } }
    / release /   { if ($0 ~ /source=tap/) tap++; else if ($0 ~ /source=poll/) poll++; else if ($0 ~ /source=before_hotkey/) early++ }
    /tap_disabled/ { dis++ }
    /tap_reenabled/ { re++ }
    /^.* focus / && /verified/ { print }
    END {
      for (i=1;i<=n;i++) for (j=i+1;j<=n;j++) if (v[j]<v[i]) { t=v[i]; v[i]=v[j]; v[j]=t }
      if (n) printf "aperture=%d mediana=%.1fms p95=%.1fms max=%.1fms (max apps=%d finestre=%d)\n", n, v[int((n+1)/2)], v[int(n*0.95+0.999)], v[n], maxa, maxw
      else print "nessuna apertura misurata"
      printf "rilasci: tap=%d poll_di_riserva=%d prima_dell_hotkey=%d | tap disattivato=%d riattivato=%d\n", tap, poll, early, dis, re
    }' "$LOG"
}

cmd="${1:-}"; [ $# -gt 0 ] && shift
case "$cmd" in
  setup-signing) setup_signing ;;
  build) build ;;
  start) start "$@" ;;
  stop) pkill -x "$EXE" && echo arrestato || echo "non in esecuzione" ;;
  list) pkill -x "$EXE" 2>/dev/null || true; rm -f build/list.txt; open -W "$APP" --args --list; cat build/list.txt 2>/dev/null || cat "$LOG" ;;
  log) tail -f "$LOG" ;;
  stats) stats ;;
  *) usage ;;
esac
