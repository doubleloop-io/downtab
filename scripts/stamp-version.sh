#!/usr/bin/env bash
# Writes VERSION and the build number into a built bundle's Info.plist: App/Info.plist holds neither.
set -euo pipefail
source "$(dirname "$0")/lib/version.sh"
PLIST=${1:?usage: stamp-version.sh path/to/Info.plist}

version=$(read_version)
build=$(build_number)
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $version" -c "Add :CFBundleVersion string $build" "$PLIST"
echo "version $version ($build)"
