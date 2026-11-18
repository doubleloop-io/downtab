#!/usr/bin/env bash
# Manual checklist, Updates: a local Appcast offering a copy of the built app as version 9.9.9, plus an older copy to
# update. Needs the Developer ID and the Sparkle key in the login keychain (the release Mac); macOS may ask once to
# let sign_update use the key.
set -euo pipefail
source "$(dirname "$0")/lib/version.sh"
APP=${1:?usage: update-fixture.sh path/to/Downtab.app}
DIR=/tmp/downtab-update
VERSION=9.9.9
BUILD=99999

[ -x "$SPARKLE_BIN/sign_update" ] || swift package resolve
rm -rf "$DIR"
mkdir -p "$DIR/feed" "$DIR/dmg"
ditto "$APP" "$DIR/Downtab.app"

ditto "$APP" "$DIR/dmg/Downtab.app"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $BUILD" \
  "$DIR/dmg/Downtab.app/Contents/Info.plist"
codesign --force --options runtime --timestamp -s "$DEVELOPER_ID" "$DIR/dmg/Downtab.app"
hdiutil create -quiet -volname Downtab -srcfolder "$DIR/dmg" -format UDZO "$DIR/feed/Downtab.dmg"
signature=$("$SPARKLE_BIN/sign_update" --account "$SPARKLE_ACCOUNT" "$DIR/feed/Downtab.dmg")

cat >"$DIR/feed/appcast.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
<channel>
<title>Downtab</title>
<item>
<title>$VERSION</title>
<sparkle:version>$BUILD</sparkle:version>
<sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
<sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
<sparkle:hardwareRequirements>arm64</sparkle:hardwareRequirements>
<description sparkle:format="markdown"><![CDATA[### Added

- **Bold** entry with a [link](https://downtab.doubleloop.io/)
- Entry with \`code\` and *italics*

### Fixed

- Last entry
]]></description>
<enclosure url="http://localhost:8000/Downtab.dmg" type="application/octet-stream" $signature />
</item>
</channel>
</rss>
EOF
echo "fixture ok: $DIR/Downtab.app updates to $VERSION from http://localhost:8000/appcast.xml"
