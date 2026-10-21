#!/usr/bin/env bash
# Removes Thai Baan Palang Bai Khrap and everything it ever changed: the sleep override, the sudoers rule,
# its stored preferences, and the app bundle. Dragging the app to the Trash cannot
# run this on its own, so run it from the dmg (or this repo) when uninstalling.
# Always runs under bash, however it was started: ./x.sh, sh x.sh, bash x.sh, zsh x.sh or any other shell.
if [ -z "${TBPK_REEXEC:-}" ]; then
  case "${SHELLOPTS:-}" in *posix*) _tbpk_posix=1 ;; *) _tbpk_posix= ;; esac
  if [ -z "${BASH_VERSION:-}" ] || [ -n "$_tbpk_posix" ]; then TBPK_REEXEC=1; export TBPK_REEXEC; exec bash "$0" "$@"; fi
fi
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: uninstall.sh [--dry-run] [-y|--yes]
Removes Thai Baan Palang Bai Khrap and everything it changed: the sleep override, the sudoers rule,
its stored preferences, your alert sound files, the login item and the app. --dry-run lists what would happen; -y skips the question.
(install.sh uninstall does the same.)
EOF
}
DRY=0; YES=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;; -y|--yes) YES=1 ;; -h|--help|help) usage; exit 0 ;;
    *) echo "unknown option: $a" >&2; usage >&2; exit 2 ;;
  esac
done


BUNDLE_ID=com.thaibaan.tbpk
APP_PATH="/Applications/Thai Baan Palang Bai Khrap.app"
DATA_DIR="$HOME/Library/Application Support/Thai Baan Palang Bai Khrap"
RULE_PATH=/etc/sudoers.d/tbpk-$(id -un | tr . _)

BUNDLE_ID_PLAN=$BUNDLE_ID
echo "== Thai Baan Palang Bai Khrap uninstall =="
if [ "$DRY" = 1 ] || [ "$YES" != 1 ]; then
  echo "This would:"
  pgrep -x "Thai Baan Palang Bai Khrap" >/dev/null && echo "  - quit the running app and unregister its login item" || echo "  - unregister the login item (app is not running)"
  [ "$(/usr/bin/pmset -g | awk 'tolower($1) == "sleepdisabled" { print $2 }')" = 1 ] && echo "  - restore normal sleep (pmset -a disablesleep 0, needs sudo)" || echo "  - leave sleep as it is (already normal)"
  [ -e "$RULE_PATH" ] && echo "  - remove the sudoers rule $RULE_PATH (needs sudo)" || echo "  - (no sudoers rule to remove)"
  defaults read "$BUNDLE_ID_PLAN" >/dev/null 2>&1 && echo "  - delete stored preferences for $BUNDLE_ID_PLAN" || echo "  - (no stored preferences)"
  [ -d "$DATA_DIR" ] && echo "  - delete your alert sound files in $DATA_DIR" || echo "  - (no custom alert sounds)"
  [ -e "$APP_PATH" ] && echo "  - remove $APP_PATH" || echo "  - (no app in /Applications)"
  [ "$DRY" = 1 ] && { echo; echo "Dry run: nothing was changed."; exit 0; }
  if [ -t 0 ]; then printf 'Go ahead? [y/N] '; read -r ans; case "$ans" in y|Y|yes|YES) ;; *) echo "Cancelled. Nothing was changed."; exit 0 ;; esac
  else echo "No terminal to confirm in. Rerun with --yes." >&2; exit 3; fi
fi

# The login item must be unregistered by the app bundle itself, before the bundle
# is deleted, or System Settings keeps a dead entry that fires at every login.
LOGIN_BIN=$(ps -axo comm= | awk '/Thai Baan Palang Bai Khrap\.app\/Contents\/MacOS\// {print; exit}' || true)
[ -x "$LOGIN_BIN" ] || LOGIN_BIN="$APP_PATH/Contents/MacOS/Thai Baan Palang Bai Khrap"
if [ -x "$LOGIN_BIN" ]; then
  echo "Unregistering the login item..."
  "$LOGIN_BIN" --set-login off >/dev/null 2>&1 \
    || echo "Could not unregister the login item; remove it in System Settings -> General -> Login Items."
else
  echo "No app binary found; skipping login item unregister."
fi

if pgrep -x "Thai Baan Palang Bai Khrap" >/dev/null; then
  echo "Quitting Thai Baan Palang Bai Khrap..."
  # SIGTERM: the app treats it as a quit, so it restores sleep and exits without a dialog.
  # Sleep is checked again a few lines below in case the app was set to keep awake.
  pkill -x "Thai Baan Palang Bai Khrap" || true
  for _ in 1 2 3 4 5; do
    pgrep -x "Thai Baan Palang Bai Khrap" >/dev/null || break
    sleep 1
  done
fi

SLEEP_DISABLED=$(/usr/bin/pmset -g | awk 'tolower($1) == "sleepdisabled" { print $2 }')
if [ "$SLEEP_DISABLED" = "1" ]; then
  echo "Restoring normal sleep (pmset -a disablesleep 0)..."
  sudo /usr/bin/pmset -a disablesleep 0
else
  echo "Sleep was already normal."
fi

if [ -e "$RULE_PATH" ]; then
  echo "Removing $RULE_PATH..."
  sudo /bin/rm -f "$RULE_PATH"
  sudo /usr/sbin/visudo -c
else
  echo "No sudoers rule to remove."
fi

if defaults read "$BUNDLE_ID" >/dev/null 2>&1; then
  echo "Removing stored preferences for $BUNDLE_ID..."
  defaults delete "$BUNDLE_ID"
else
  echo "No stored preferences."
fi

if [ -d "$DATA_DIR" ]; then
  echo "Removing your alert sound files in $DATA_DIR..."
  rm -rf "$DATA_DIR"
else
  echo "No custom alert sounds."
fi

if [ -e "$APP_PATH" ]; then
  echo "Removing $APP_PATH..."
  rm -rf "$APP_PATH" 2>/dev/null || sudo rm -rf "$APP_PATH"
else
  echo "App bundle not in /Applications (already trashed, or installed elsewhere)."
fi

echo
echo "Done. If Thai Baan Palang Bai Khrap ever added '@includedir /etc/sudoers.d' to /etc/sudoers, that line is"
echo "left in place on purpose: it is standard macOS configuration other tools may use."
