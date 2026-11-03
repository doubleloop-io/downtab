#!/usr/bin/env bash
# Renders the hand-tuned SVGs in App/Icon into App/AppIcon.icns. The .icns is committed, so `make bundle`
# never needs rsvg-convert; rerun this only after editing an SVG.
set -euo pipefail
SRC=App/Icon
OUT=App/AppIcon.icns

command -v rsvg-convert >/dev/null || { echo "rsvg-convert missing: brew install librsvg"; exit 1; }

iconset=$(mktemp -d)/AppIcon.iconset
mkdir -p "$iconset"

# 16, 32 and 64 px have their own simplified drawings; 128 and up scale the detailed ones.
render() { rsvg-convert -w "$2" -h "$2" "$SRC/$1" -o "$iconset/$3"; }
render icon-16.svg 16 icon_16x16.png
render icon-32.svg 32 icon_16x16@2x.png
render icon-32.svg 32 icon_32x32.png
render icon-64.svg 64 icon_32x32@2x.png
render icon-128.svg 128 icon_128x128.png
render icon-512.svg 256 icon_128x128@2x.png
render icon-512.svg 256 icon_256x256.png
render icon-512.svg 512 icon_256x256@2x.png
render icon-512.svg 512 icon_512x512.png
render icon-512.svg 1024 icon_512x512@2x.png

iconutil -c icns "$iconset" -o "$OUT"
rm -rf "$(dirname "$iconset")"
echo "wrote $OUT"
