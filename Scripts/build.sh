#!/bin/bash
# Builds CmdV.app: compiles the SwiftPM package, assembles a real app bundle,
# embeds Sparkle, and signs it with a stable identity so Accessibility
# permission grants survive rebuilds. Ad-hoc signing ("-") has no certificate
# at all, so macOS can only recognize a rebuilt binary by its exact hash —
# which changes every build — forcing a fresh Accessibility grant each time.
# Signing with any real certificate (even a local self-signed one) lets TCC
# match by signer identity instead, so the grant sticks across rebuilds.
#
# Usage:
#   Scripts/build.sh                # debug build
#   Scripts/build.sh --release      # release build
#   DEVELOPER_ID="Developer ID Application: Name (TEAMID)" Scripts/build.sh --release
#                                    # sign with a real Apple-issued certificate instead
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIG="debug"
if [[ "${1:-}" == "--release" ]]; then
    CONFIG="release"
fi

APP_NAME="CmdV"
BUNDLE_ID="com.babcock.cmdv"
VERSION="${CMDV_VERSION:-0.1.0}"
BUILD_NUMBER="${CMDV_BUILD:-$(date +%Y%m%d%H%M%S)}"
LOCAL_DEV_IDENTITY="CmdV Local Dev"
if [[ -n "${DEVELOPER_ID:-}" ]]; then
    SIGN_IDENTITY="$DEVELOPER_ID"
elif security find-identity -v -p codesigning 2>/dev/null | grep -q "$LOCAL_DEV_IDENTITY"; then
    SIGN_IDENTITY="$LOCAL_DEV_IDENTITY"
else
    SIGN_IDENTITY="-"   # ad-hoc fallback — Accessibility grants won't survive rebuilds
fi

echo "==> Building ($CONFIG)…"
if [[ "$CONFIG" == "release" ]]; then
    swift build -c release
    BIN_DIR="$(swift build -c release --show-bin-path)"
else
    swift build
    BIN_DIR="$(swift build --show-bin-path)"
fi

APP_BUNDLE="$ROOT_DIR/build/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"

echo "==> Assembling $APP_NAME.app…"
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"

cp "$BIN_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"

# Info.plist with version/build substituted.
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" \
    "$ROOT_DIR/Resources/Info.plist" > "$CONTENTS_DIR/Info.plist"

# App icon, if it's been generated yet (milestone 10).
if [[ -f "$ROOT_DIR/Resources/AppIcon.icns" ]]; then
    cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# SwiftPM resource bundles (e.g. GRDB's) live next to the built binary and
# must ship inside Contents/Resources for the app to find them at runtime.
if compgen -G "$BIN_DIR"/*.bundle > /dev/null; then
    cp -R "$BIN_DIR"/*.bundle "$RESOURCES_DIR/"
fi

# Sparkle ships as a binary xcframework that SwiftPM leaves in .build; the
# framework itself has to travel inside the app. `ditto` rather than `cp -R`
# because a versioned framework is a web of symlinks that must survive intact.
echo "==> Embedding Sparkle…"
SPARKLE_FW="$(/usr/bin/find "$ROOT_DIR/.build/artifacts/sparkle" -type d -name 'Sparkle.framework' -maxdepth 4 | head -1)"
if [[ -z "$SPARKLE_FW" ]]; then
    echo "error: Sparkle.framework not found — run 'swift package resolve' first." >&2
    exit 1
fi
ditto "$SPARKLE_FW" "$FRAMEWORKS_DIR/Sparkle.framework"

# The executable links @rpath/Sparkle.framework/... but SwiftPM only gives it
# an @loader_path rpath, which points at Contents/MacOS. Teach it where the
# embedded framework actually lives, one directory over.
install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/$APP_NAME" 2>/dev/null || true

# Signing must run inside-out: every nested bundle first, the app last. Note
# there is no --deep here on purpose. --deep re-signs nested code with the
# *outer* bundle's rules, which strips the XPC services' own identifiers and
# produces a bundle the notary service rejects. Hardened runtime (--options
# runtime) is mandatory for notarization and must be applied to every binary.
echo "==> Signing (identity: $SIGN_IDENTITY)…"
SPARKLE_DEST="$FRAMEWORKS_DIR/Sparkle.framework/Versions/B"
for xpc in "$SPARKLE_DEST"/XPCServices/*.xpc; do
    [[ -e "$xpc" ]] || continue
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$xpc"
done
codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$SPARKLE_DEST/Updater.app"
codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$SPARKLE_DEST/Autoupdate"
codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$SPARKLE_DEST"
codesign --force --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" \
    --identifier "$BUNDLE_ID" \
    "$APP_BUNDLE"

echo "==> Verifying signature…"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "==> Done: $APP_BUNDLE"
