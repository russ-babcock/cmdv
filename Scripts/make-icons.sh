#!/bin/bash
# Builds Resources/AppIcon.icns from the design source in CmdV-final/.
#
# The art ships at every size macOS asks for (16 through 1024), so nothing is
# resampled here. Replacing the icon means replacing the PNGs in
# CmdV-final/app-icon/ and re-running this; any size the set stops supplying is
# downscaled from the 1024 master instead.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ART_DIR="$ROOT_DIR/CmdV-final/app-icon"
WORK_DIR="$(mktemp -d)"
ICONSET="$WORK_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"
trap 'rm -rf "$WORK_DIR"' EXIT

MASTER="$ART_DIR/CmdV-1024.png"
if [[ ! -f "$MASTER" ]]; then
    echo "error: $MASTER not found." >&2
    exit 1
fi

# name:size:source — the supplied sizes are used verbatim so the art is never
# resampled when an exact rendering already exists.
entries=(
    "icon_16x16.png:16:$ART_DIR/CmdV-16.png"
    "icon_16x16@2x.png:32:$ART_DIR/CmdV-32.png"
    "icon_32x32.png:32:$ART_DIR/CmdV-32.png"
    "icon_32x32@2x.png:64:$ART_DIR/CmdV-64.png"
    "icon_128x128.png:128:$ART_DIR/CmdV-128.png"
    "icon_128x128@2x.png:256:$ART_DIR/CmdV-256.png"
    "icon_256x256.png:256:$ART_DIR/CmdV-256.png"
    "icon_256x256@2x.png:512:$ART_DIR/CmdV-512.png"
    "icon_512x512.png:512:$ART_DIR/CmdV-512.png"
    "icon_512x512@2x.png:1024:$MASTER"
)

echo "==> Assembling iconset…"
for entry in "${entries[@]}"; do
    name="${entry%%:*}"
    rest="${entry#*:}"
    size="${rest%%:*}"
    source="${rest#*:}"

    [[ -f "$source" ]] || source="$MASTER"

    actual="$(sips -g pixelWidth "$source" | awk '/pixelWidth/{print $2}')"
    if [[ "$actual" == "$size" ]]; then
        cp "$source" "$ICONSET/$name"
    else
        sips -z "$size" "$size" "$source" --out "$ICONSET/$name" > /dev/null
    fi
done

echo "==> Packaging .icns…"
iconutil -c icns "$ICONSET" -o "$ROOT_DIR/Resources/AppIcon.icns"

echo "==> Done: Resources/AppIcon.icns"
