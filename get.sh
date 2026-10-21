#!/usr/bin/env bash
# One-line installer: downloads the newest GitHub Release with curl, checks its SHA-256, installs it.
#   curl -fsSL https://raw.githubusercontent.com/ikrencyp/thai-baan-palang-bai-khrap/main/get.sh | bash
# A file fetched by curl carries no quarantine flag, so macOS Gatekeeper has nothing to block and the
# app opens without a warning even though it is not notarized. Extra arguments go to install.sh
# (for example `| bash -s -- plan` to see what would happen).
set -euo pipefail

REPO="${TBPK_REPO:-ikrencyp/thai-baan-palang-bai-khrap}"
API="${TBPK_RELEASE_API:-https://api.github.com/repos/$REPO/releases/latest}"

# HTTPS only, unless a test points the script at local files.
if [ -n "${TBPK_RELEASE_API:-}${TBPK_DOWNLOAD_BASE:-}" ]; then CURL_FLAGS=(-fsSL); else CURL_FLAGS=(-fsSL --proto '=https' --tlsv1.2); fi

[ "$(uname -s)" = Darwin ] || { echo "TBPK is a macOS app." >&2; exit 1; }
WORK=$(mktemp -d /tmp/tbpk-get.XXXXXX)
MOUNT=""
cleanup() {
  [ -z "$MOUNT" ] || hdiutil detach -quiet -force "$MOUNT" >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "Looking for the newest release..."
curl "${CURL_FLAGS[@]}" "$API" -o "$WORK/release.json" || { echo "Could not reach GitHub ($API)." >&2; exit 1; }
TAG=$(plutil -extract tag_name raw -o - "$WORK/release.json" 2>/dev/null) || { echo "No release found." >&2; exit 1; }
[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Unexpected release tag: $TAG" >&2; exit 1; }
VERSION="${TAG#v}"
BASE="${TBPK_DOWNLOAD_BASE:-https://github.com/$REPO/releases/download/$TAG}"

echo "Downloading TBPK $VERSION..."
curl "${CURL_FLAGS[@]}" "$BASE/TBPK-$VERSION.dmg" -o "$WORK/TBPK-$VERSION.dmg" || { echo "Could not download TBPK-$VERSION.dmg from the release." >&2; exit 1; }
curl "${CURL_FLAGS[@]}" "$BASE/TBPK-$VERSION.dmg.sha256" -o "$WORK/TBPK-$VERSION.dmg.sha256" || { echo "Could not download TBPK-$VERSION.dmg.sha256 from the release." >&2; exit 1; }
expected=$(awk '{print tolower($1); exit}' "$WORK/TBPK-$VERSION.dmg.sha256")
actual=$(shasum -a 256 "$WORK/TBPK-$VERSION.dmg" | awk '{print $1}')
[ -n "$expected" ] && [ "$expected" = "$actual" ] || { echo "Checksum does not match: the download is not installed." >&2; exit 1; }
echo "Checksum ok."

MOUNT="$WORK/mount"
mkdir "$MOUNT"
hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT" "$WORK/TBPK-$VERSION.dmg" >/dev/null
cp "$MOUNT/install.sh" "$MOUNT/uninstall.sh" "$WORK/"
hdiutil detach -quiet "$MOUNT" >/dev/null 2>&1 && MOUNT=""

bash "$WORK/install.sh" "$@" "$WORK/TBPK-$VERSION.dmg"
