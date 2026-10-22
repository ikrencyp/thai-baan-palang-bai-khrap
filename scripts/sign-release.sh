#!/usr/bin/env bash
# Signs a published release with the maintainer's release key and attaches the signature. Run it on your own Mac after
# the Release workflow has published a version: the app and get.sh refuse a release without TBPK-<version>.dmg.sig.
#   scripts/sign-release.sh 1.0.2
# It compares the published dmg with the one the Release workflow built, and signs only when they are identical.
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
# Only sign what the Release workflow built: fetch the dmg the workflow kept as its artifact and compare.
BUILT=""
run_id=$(gh run list --repo "$REPO" --workflow Release --branch "$TAG" --status success --limit 1 --json databaseId --jq '.[0].databaseId // empty' 2>/dev/null || true)
if [ -n "$run_id" ] && gh run download "$run_id" --repo "$REPO" --name release --dir "$WORK/built" >/dev/null 2>&1; then
  BUILT=$(shasum -a 256 "$WORK/built/TBPK-$VERSION.dmg" | awk '{print $1}')
  [ "$BUILT" = "$actual" ] || { echo "The published dmg is not the one the Release workflow built ($BUILT). Not signing." >&2; exit 1; }
  echo "Matches the dmg built by the Release workflow (run $run_id)."
else
  echo "Could not fetch the workflow's build to compare. Compare the hash with the summary of the Release run for $TAG by hand."
  if [ "$YES" != 1 ]; then
    printf 'Sign it? [y/N] '; read -r ans
    case "$ans" in y|Y|yes|YES) ;; *) echo "Cancelled. Nothing was signed."; exit 1 ;; esac
  else
    echo "Refusing to sign without a comparison, even with -y." >&2; exit 1
  fi
fi

# A key loaded in ssh-agent (ssh-add --apple-use-keychain) signs without asking for the passphrase; otherwise ssh-keygen asks.
SIGN_WITH="$KEY"
ssh-add -L 2>/dev/null | grep -qF "$(cut -d' ' -f2 "$KEY.pub")" && SIGN_WITH="$KEY.pub"
ssh-keygen -Y sign -f "$SIGN_WITH" -n "$NAMESPACE" "$DMG" >/dev/null
printf 'tbpk-release %s\n' "$(cut -d' ' -f1,2 "$KEY.pub")" > "$WORK/allowed"
ssh-keygen -Y verify -f "$WORK/allowed" -I tbpk-release -n "$NAMESPACE" -s "$DMG.sig" < "$DMG" >/dev/null \
  || { echo "The new signature does not verify. Not uploading." >&2; exit 1; }

gh release upload "$TAG" "$DMG.sig" --repo "$REPO" --clobber
echo "Signed and uploaded TBPK-$VERSION.dmg.sig for $TAG."
