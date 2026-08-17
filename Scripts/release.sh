#!/bin/bash
# Cuts a CmdV release: builds, notarizes, signs the update, publishes it to
# GitHub Releases, and adds it to the Sparkle appcast that shipped copies poll.
#
# Usage:
#   Scripts/release.sh 0.2.0                 # full release
#   Scripts/release.sh 0.2.0 --dry-run       # build + sign + appcast, no upload
#   Scripts/release.sh 0.2.0 --notes-file CHANGES.md
#
# Requirements:
#   - DEVELOPER_ID env var (Developer ID Application cert) for a notarized build.
#     Without it the release is signed with the local dev cert and every
#     downloader has to clear the quarantine flag by hand — fine for testing,
#     not for real distribution.
#   - A notarytool keychain profile named by NOTARY_PROFILE (default "cmdv-notary"),
#     created once with:
#       xcrun notarytool store-credentials cmdv-notary \
#         --apple-id you@example.com --team-id TEAMID --password APP_SPECIFIC_PASSWORD
#   - `gh` authenticated, for creating the release.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -lt 1 ]]; then
    echo "usage: Scripts/release.sh VERSION [--dry-run] [--notes-file FILE]" >&2
    exit 1
fi

VERSION="$1"; shift
DRY_RUN=0
NOTES_FILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --notes-file) NOTES_FILE="$2"; shift ;;
        *) echo "unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

APP_NAME="CmdV"
REPO="russ-babcock/cmdv"
TAG="v$VERSION"
BUILD_NUMBER="$(date +%Y%m%d%H%M%S)"
NOTARY_PROFILE="${NOTARY_PROFILE:-cmdv-notary}"
APP_BUNDLE="$ROOT_DIR/build/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/build/dist"
ZIP_PATH="$DIST_DIR/$APP_NAME-$VERSION.zip"
FEED="$ROOT_DIR/docs/appcast.xml"
SIGN_UPDATE="$(/usr/bin/find "$ROOT_DIR/.build/artifacts/sparkle" -type f -name sign_update | head -1)"

if [[ -z "$SIGN_UPDATE" ]]; then
    echo "error: sign_update not found — run 'swift package resolve' first." >&2
    exit 1
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "error: tag $TAG already exists. Releases are immutable — bump the version." >&2
    exit 1
fi

echo "==> Releasing $APP_NAME $VERSION (build $BUILD_NUMBER)"

CMDV_VERSION="$VERSION" CMDV_BUILD="$BUILD_NUMBER" Scripts/build.sh --release

# ---------------------------------------------------------------- notarize --
# Notarization needs a real Apple-issued Developer ID; the local self-signed
# cert can't be submitted. Skipping it produces a working build that macOS
# still quarantines on other people's machines, so it's a loud warning.
mkdir -p "$DIST_DIR"
rm -f "$ZIP_PATH"

if [[ -n "${DEVELOPER_ID:-}" ]]; then
    if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
        echo "error: no notarytool profile '$NOTARY_PROFILE'. Create it with:" >&2
        echo "  xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id ... --team-id ... --password ..." >&2
        exit 1
    fi

    echo "==> Submitting for notarization (this takes a few minutes)…"
    NOTARIZE_ZIP="$DIST_DIR/$APP_NAME-notarize.zip"
    rm -f "$NOTARIZE_ZIP"
    ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$NOTARIZE_ZIP"
    xcrun notarytool submit "$NOTARIZE_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    rm -f "$NOTARIZE_ZIP"

    # Stapling writes the notarization ticket into the bundle so Gatekeeper
    # can approve it offline. It must happen before the distributed zip is
    # made, or downloaders get an unstapled app.
    echo "==> Stapling ticket…"
    xcrun stapler staple "$APP_BUNDLE"
    xcrun stapler validate "$APP_BUNDLE"
else
    echo "WARNING: DEVELOPER_ID unset — build is NOT notarized." >&2
    echo "         Anyone who downloads it must run:" >&2
    echo "           xattr -dr com.apple.quarantine /Applications/$APP_NAME.app" >&2
fi

# ------------------------------------------------------------------ package --
# ditto, not `zip`: it preserves the symlinks inside Sparkle.framework and the
# extended attributes the code signature depends on.
echo "==> Packaging…"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "==> Signing update with EdDSA key…"
SIGN_OUTPUT="$("$SIGN_UPDATE" "$ZIP_PATH")"
ED_SIGNATURE="$(echo "$SIGN_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')"
LENGTH="$(echo "$SIGN_OUTPUT" | sed -n 's/.*length="\([^"]*\)".*/\1/p')"
if [[ -z "$ED_SIGNATURE" || -z "$LENGTH" ]]; then
    echo "error: could not parse sign_update output: $SIGN_OUTPUT" >&2
    exit 1
fi

NOTES=""
if [[ -n "$NOTES_FILE" ]]; then
    NOTES="$(cat "$NOTES_FILE")"
fi

DOWNLOAD_URL="https://github.com/$REPO/releases/download/$TAG/$APP_NAME-$VERSION.zip"

python3 Scripts/update_appcast.py "$FEED" \
    --version "$BUILD_NUMBER" \
    --short-version "$VERSION" \
    --url "$DOWNLOAD_URL" \
    --length "$LENGTH" \
    --signature "$ED_SIGNATURE" \
    --link "https://github.com/$REPO/releases/tag/$TAG" \
    --notes "$NOTES"

if [[ "$DRY_RUN" == "1" ]]; then
    echo "==> Dry run: built $ZIP_PATH and updated $FEED. Nothing uploaded."
    echo "    Revert the appcast with: git checkout docs/appcast.xml"
    exit 0
fi

# ------------------------------------------------------------------ publish --
# The appcast is committed and pushed BEFORE the GitHub release exists only in
# ordering of commands, not effect: Pages takes a minute to redeploy, by which
# time the release asset is live. The reverse order would briefly advertise a
# download URL that 404s.
echo "==> Publishing…"
git add "$FEED"
git commit -m "Release $VERSION"
git tag -a "$TAG" -m "$APP_NAME $VERSION"
git push origin HEAD --tags

gh release create "$TAG" "$ZIP_PATH" \
    --repo "$REPO" \
    --title "$APP_NAME $VERSION" \
    --notes "${NOTES:-Release $VERSION}"

echo "==> Done. Shipped copies will see $VERSION within a day, or immediately"
echo "    via Settings → General → Check Now."
