#!/usr/bin/env bash
# Zips the signed app, Emergency restore and the license as Downtab/{Downtab.app,EmergencyRestore,LICENSE},
# then checks the signatures survive unzipping. ditto keeps the bundle's symlinks and permissions; without
# --noextattr it also stores local metadata (com.apple.provenance) as ._ files, which a plain `unzip` extracts into
# the bundle, breaking its seal.
set -euo pipefail
source "$(dirname "$0")/lib/version.sh"
app=$1 restore=$2 zip=$3

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir "$stage/Downtab"
ditto "$app" "$stage/Downtab/$(basename "$app")"
ditto "$restore" "$stage/Downtab/EmergencyRestore"
# The GPL requires the license text to travel with the binary.
cp LICENSE "$stage/Downtab/LICENSE"
rm -f "$zip"
ditto -c -k --norsrc --noextattr --noacl --keepParent "$stage/Downtab" "$zip"

mkdir "$stage/check"
# The strictest extractor: Archive Utility and ditto would hide stray ._ entries by merging them.
/usr/bin/unzip -q "$zip" -d "$stage/check"
listing=$(cd "$stage/check" && find . -mindepth 1 -maxdepth 2 | sort | tr '\n' ' ')
[ "$listing" = "./Downtab ./Downtab/Downtab.app ./Downtab/EmergencyRestore ./Downtab/LICENSE " ] || fail "unexpected zip layout: $listing"
codesign --verify --strict "$stage/check/Downtab/Downtab.app" || fail "Downtab.app signature broken after unzip"
codesign --verify --strict "$stage/check/Downtab/EmergencyRestore" || fail "EmergencyRestore signature broken after unzip"
echo "packaged $zip"
