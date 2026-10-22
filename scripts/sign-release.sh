#!/usr/bin/env bash
# Signs a published release with the maintainer's release key and attaches the signature. Run it on your own Mac after
# the Release workflow has published a version: the app and get.sh refuse a release without TBPK-<version>.dmg.sig.
#   scripts/sign-release.sh 1.0.2
# The private key stays on this Mac (TBPK_SIGNING_KEY overrides the default ~/.ssh/tbpk_release_ed25519).
set -euo pipefail

REPO="${TBPK_REPO:-ikrencyp/thai-baan-palang-bai-khrap}"
KEY="${TBPK_SIGNING_KEY:-$HOME/.ssh/tbpk_release_ed25519}"
YES=0
VERSION=""
for a in "$@"; do
  case "$a" in
    -y|--yes) YES=1 ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    [0-9]*.[0-9]*.[0-9]*) VERSION="$a" ;;
    *) echo "unknown argument: $a" >&2; exit 2 ;;
  esac
done
[ -n "$VERSION" ] || { echo "Usage: scripts/sign-release.sh <x.y.z> [-y]" >&2; exit 2; }
[ -f "$KEY" ] && [ -f "$KEY.pub" ] || { echo "No signing key at $KEY (and $KEY.pub)." >&2; exit 1; }
command -v gh >/dev/null || { echo "Needs the GitHub CLI: brew install gh" >&2; exit 1; }

TAG="v$VERSION"
NAMESPACE="tbpk-release-$VERSION"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/tbpk-sign.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

gh release download "$TAG" --repo "$REPO" --dir "$WORK" --pattern "TBPK-$VERSION.dmg" --pattern "TBPK-$VERSION.dmg.sha256"
DMG="$WORK/TBPK-$VERSION.dmg"
expected=$(awk '{print tolower($1); exit}' "$DMG.sha256")
actual=$(shasum -a 256 "$DMG" | awk '{print $1}')
[ "$expected" = "$actual" ] || { echo "The release's checksum file does not match its dmg. Not signing." >&2; exit 1; }

echo "TBPK-$VERSION.dmg  sha256 $actual"
echo "Compare it with the hash in the summary of the Release workflow run for $TAG: only sign what the workflow built."
if [ "$YES" != 1 ]; then
  printf 'Sign it? [y/N] '; read -r ans
  case "$ans" in y|Y|yes|YES) ;; *) echo "Cancelled. Nothing was signed."; exit 1 ;; esac
fi

ssh-keygen -Y sign -f "$KEY" -n "$NAMESPACE" "$DMG" >/dev/null
printf 'tbpk-release %s\n' "$(cut -d' ' -f1,2 "$KEY.pub")" > "$WORK/allowed"
ssh-keygen -Y verify -f "$WORK/allowed" -I tbpk-release -n "$NAMESPACE" -s "$DMG.sig" < "$DMG" >/dev/null \
  || { echo "The new signature does not verify. Not uploading." >&2; exit 1; }

gh release upload "$TAG" "$DMG.sig" --repo "$REPO" --clobber
echo "Signed and uploaded TBPK-$VERSION.dmg.sig for $TAG."
