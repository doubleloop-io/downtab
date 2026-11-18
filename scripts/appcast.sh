#!/usr/bin/env bash
# Signs the final DMG with the Sparkle key and writes the Appcast that offers it: one item, the released version.
# Run after notarize.sh: stapling changes the DMG, so a signature taken before it would not match.
set -euo pipefail
source "$(dirname "$0")/lib/version.sh"
app=$1 dmg=$2 appcast=$3

plist=$app/Contents/Info.plist
version=$(plist_value "$plist" CFBundleShortVersionString)
build=$(plist_value "$plist" CFBundleVersion)
minimum_system=$(plist_value "$plist" LSMinimumSystemVersion)
public_key=$(plist_value "$plist" SUPublicEDKey)
[ "$version" = "$(read_version)" ] || fail "$app is $version, $VERSION_FILE is $(read_version): run make notarize-check"
notes=$(changelog_section "$version")
[ -n "$notes" ] || fail "$CHANGELOG_FILE has no ## [$version] section"
[[ $notes != *"]]>"* ]] || fail "the ## [$version] notes contain ]]>, which would end the Appcast's CDATA"
url=https://github.com/$RELEASE_REPO/releases/download/v$version/$(basename "$dmg")

keychain_key=$("$SPARKLE_BIN/generate_keys" -p --account "$SPARKLE_ACCOUNT" 2>&1) \
  || fail "Sparkle key unreadable (account $SPARKLE_ACCOUNT): $keychain_key"
[ "$keychain_key" = "$public_key" ] \
  || fail "the keychain's Sparkle key ($keychain_key) is not $app's SUPublicEDKey ($public_key): Sparkle would refuse the update"
signature=$("$SPARKLE_BIN/sign_update" --account "$SPARKLE_ACCOUNT" -p "$dmg" 2>&1) || fail "signing $dmg failed: $signature"
verification=$("$SPARKLE_BIN/sign_update" --account "$SPARKLE_ACCOUNT" --verify "$dmg" "$signature" 2>&1) \
  || fail "the Sparkle signature of $dmg does not verify: $verification"
length=$(wc -c <"$dmg" | tr -d " ")

draft=$(mktemp)
trap 'rm -f "$draft"' EXIT
cat >"$draft" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
<channel>
<title>Downtab</title>
<item>
<title>$version</title>
<sparkle:version>$build</sparkle:version>
<sparkle:shortVersionString>$version</sparkle:shortVersionString>
<sparkle:minimumSystemVersion>$minimum_system</sparkle:minimumSystemVersion>
<sparkle:hardwareRequirements>arm64</sparkle:hardwareRequirements>
<description sparkle:format="markdown"><![CDATA[$notes
]]></description>
<enclosure url="$url" type="application/octet-stream" length="$length" sparkle:edSignature="$signature" />
</item>
</channel>
</rss>
XML

errors=$(xmllint --noout "$draft" 2>&1) || fail "invalid Appcast XML: $errors"
item='//*[local-name()="item"]'
[ "$(appcast_value "$draft" "$item/*[local-name()=\"version\"]")" = "$build" ] \
  && [ "$(appcast_value "$draft" "$item/*[local-name()=\"shortVersionString\"]")" = "$version" ] \
  && [ "$(appcast_value "$draft" "$item/*[local-name()=\"enclosure\"]/@url")" = "$url" ] \
  || fail "the Appcast does not carry $app's version $version ($build) at $url"
mv "$draft" "$appcast"
echo "appcast $appcast: $version ($build), signed"
