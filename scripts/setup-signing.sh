#!/usr/bin/env bash
# Creates the self-signed code signing certificate in a dedicated keychain, once per clone.
# A stable certificate keeps the designated requirement stable, so macOS keeps the Accessibility grant across rebuilds.
set -euo pipefail
SIGNING_DIR=$1
KEYCHAIN="$PWD/$SIGNING_DIR/downtab.keychain-db"
KEYCHAIN_PASSWORD=$2

identity() { openssl x509 -in "$SIGNING_DIR/cert.crt" -noout -fingerprint -sha1 | cut -d= -f2 | tr -d :; }
[ -f "$KEYCHAIN" ] && { echo "already done: $KEYCHAIN"; exit; }
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
saved=$(security list-keychains -d user | tr -d '"')
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
# shellcheck disable=SC2086
security list-keychains -d user -s $saved
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$SIGNING_DIR/cert.p12" -k "$KEYCHAIN" -P "$KEYCHAIN_PASSWORD" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
echo "ok, identity $(identity)"
