#!/usr/bin/env bash
# Installs Thai Baan Palang Bai Khrap to /Applications and clears the quarantine flag so
# the first launch needs no `xattr` command and no password. Run it from the dmg,
# or from a clone of this repo (`./install.sh [dmg-or-version]` uses dist/TBPK-*.dmg,
# the newest one by default), instead of dragging the app when you want the flag gone for
# you. Everything it does is as your own account: nothing here needs sudo.
# Always runs under bash, however it was started: ./x.sh, sh x.sh, bash x.sh, zsh x.sh or any other shell.
if [ -z "${TBPK_REEXEC:-}" ]; then
  case "${SHELLOPTS:-}" in *posix*) _tbpk_posix=1 ;; *) _tbpk_posix= ;; esac
  if [ -z "${BASH_VERSION:-}" ] || [ -n "$_tbpk_posix" ]; then TBPK_REEXEC=1; export TBPK_REEXEC; exec bash "$0" "$@"; fi
fi
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: install.sh [command] [dmg-or-version] [-y] [--dry-run]
  install (default)  install the newest dist/TBPK-*.dmg, or the app next to this script (inside the dmg);
                     already up to date -> nothing to do. A version like 1.0.1 or a .dmg path picks one.
  update             same as install
  plan               show what would happen, change nothing (also: --dry-run)
  uninstall          remove the app and everything it changed (uninstall.sh does the same)
  status             installed version, running or not
  help
-y answers yes. Works as ./install.sh, sh, bash and zsh.
EOF
}


APP_NAME="Thai Baan Palang Bai Khrap.app"
APP_PATH="${TBPK_INSTALL_DIR:-/Applications}/$APP_NAME"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOUNT=""
# The dmg is detached and its mount folder removed, however the script ends: /tmp keeps nothing of an install.
cleanup() {
  [ -n "$MOUNT" ] || return 0
  hdiutil detach -quiet "$MOUNT" >/dev/null 2>&1 || hdiutil detach -force -quiet "$MOUNT" >/dev/null 2>&1 || true
  rmdir "$MOUNT" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 1' INT TERM HUP

plist_version() { [ -f "$1/Contents/Info.plist" ] || return 0; /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$1/Contents/Info.plist" 2>/dev/null || true; }
CMD=install; DRY=0; YES=0; ARG=""
for a in "$@"; do
  case "$a" in
    install|update|plan|uninstall|status|help) CMD="$a" ;;
    --dry-run) DRY=1 ;; -y|--yes) YES=1 ;; -h|--help) CMD=help ;;
    --version) V=$(tr -d '[:space:]' < "$HERE/VERSION" 2>/dev/null || true); [ -n "$V" ] || V=$(plist_version "$HERE/Thai Baan Palang Bai Khrap.app"); echo "thai-baan-palang-bai-khrap ${V:-unknown}"; exit 0 ;;
    -*) echo "unknown option: $a" >&2; usage >&2; exit 2 ;;
    *) ARG="$a" ;;
  esac
done
[ "$CMD" = plan ] && { CMD=install; DRY=1; }

case "$CMD" in
  help) usage; exit 0 ;;
  uninstall)
    args=()
    [ "$DRY" = 1 ] && args+=(--dry-run)
    [ "$YES" = 1 ] && args+=(--yes)
    exec bash "$HERE/uninstall.sh" "${args[@]+"${args[@]}"}" ;;
  status)
    cur=$(plist_version "$APP_PATH")
    if [ -n "$cur" ]; then echo "installed: $cur at $APP_PATH ($(pgrep -x "Thai Baan Palang Bai Khrap" >/dev/null && echo running || echo not running))"; else echo "not installed"; fi
    ls "$HERE"/dist/TBPK-*.dmg >/dev/null 2>&1 && echo "dmgs here: $(ls "$HERE"/dist/TBPK-*.dmg | sed 's#.*/##' | tr '\n' ' ')"
    exit 0 ;;
esac

# Where the app comes from, in order: an argument (a .dmg path or a version like 1.0.0),
# the app next to this script (inside the dmg), the newest dist/TBPK-<version>.dmg of a clone.
DMG=""
if [ -n "$ARG" ]; then
  case "$ARG" in
    *.dmg) DMG="$ARG" ;;
    *) DMG="$HERE/dist/TBPK-$ARG.dmg" ;;
  esac
  [ -f "$DMG" ] || { echo "No such dmg: $DMG (a version number needs the dist/ folder of a clone; from the dmg, run install.sh with no argument)" >&2; exit 1; }
elif [ -d "$HERE/$APP_NAME" ]; then
  SOURCE="$HERE/$APP_NAME"
else
  DMG=$(ls "$HERE"/dist/TBPK-*.dmg 2>/dev/null | sed 's#.*/TBPK-\(.*\)\.dmg#\1 &#' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1 | cut -d' ' -f2- || true)
  [ -n "$DMG" ] || { echo "No $APP_NAME next to this script and no dist/TBPK-*.dmg. Run build.sh first, or open the dmg and run install.sh from there." >&2; exit 1; }
fi
if [ -n "$DMG" ]; then
  echo "Using $(basename "$DMG")"
  MOUNT=$(mktemp -d /tmp/tbpk-dmg.XXXXXX)
  hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT" "$DMG" >/dev/null || { rmdir "$MOUNT"; MOUNT=""; echo "Could not open $DMG" >&2; exit 1; }
  SOURCE="$MOUNT/$APP_NAME"
  [ -d "$SOURCE" ] || { echo "$APP_NAME is not inside $DMG" >&2; exit 1; }
fi

# check what is there: nothing, the same build, another version
new=$(plist_version "$SOURCE"); cur=$(plist_version "$APP_PATH")
if [ -z "$cur" ] && [ ! -d "$APP_PATH" ]; then state="not installed: would install ${new:-?}"
elif [ "$cur" = "$new" ] && diff -rq "$SOURCE/Contents/MacOS" "$APP_PATH/Contents/MacOS" >/dev/null 2>&1; then state="already installed and identical (${cur:-?}): nothing to do"
else state="installed ${cur:-?}: would replace it with ${new:-?}"; fi
echo "== Thai Baan Palang Bai Khrap install =="
echo "  $state"
if [ "$DRY" = 1 ]; then echo "  Dry run: nothing was changed."; exit 0; fi
case "$state" in already*) open "$APP_PATH" 2>/dev/null || true; exit 0 ;; esac
if [ "$YES" != 1 ] && [ -d "$APP_PATH" ] && [ -t 0 ]; then
  printf '  Replace the installed copy? [Y/n] '; read -r ans; case "$ans" in n|N|no|NO) echo "  Cancelled. Nothing was changed."; exit 0 ;; esac
fi


echo "Copying to $(dirname "$APP_PATH")..."
# ditto rather than cp -R: it preserves the bundle layout and does not need sudo
# because /Applications is writable by the admin group this account is in.
# The new copy is made beside the old one and swapped in, so a failed copy never leaves the Mac with no app.
NEW_PATH="$APP_PATH.new"
rm -rf "$NEW_PATH"
ditto "$SOURCE" "$NEW_PATH" || { rm -rf "$NEW_PATH"; echo "Could not copy the app. The installed copy was not touched." >&2; exit 1; }
rm -rf "$APP_PATH"
mv "$NEW_PATH" "$APP_PATH"

echo "Clearing the quarantine flag..."
# No sudo on purpose. The app was copied by this account, so this account owns it,
# and a plain xattr is enough. If this ever reports Permission denied the bundle
# was installed as root earlier; fix the owner first instead of reaching for sudo.
if ! xattr -drs com.apple.quarantine "$APP_PATH"; then
  echo "Could not clear quarantine. The app may be owned by root; try:" >&2
  echo "    sudo chown -R \"\$(id -un)\" \"$APP_PATH\" && xattr -drs com.apple.quarantine \"$APP_PATH\"" >&2
  exit 1
fi

echo "Launching..."
open "$APP_PATH"

echo
echo "Installed at $APP_PATH"
echo "Uninstall later with uninstall.sh, from the dmg or this repo."
