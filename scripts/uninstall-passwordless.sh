#!/usr/bin/env bash
# Removes the NOPASSWD rule that install-passwordless.sh added.
# After this, Thai Baan Palang Bai Khrap asks for your password on every toggle again.
# Always runs under bash, however it was started: ./x.sh, sh x.sh, bash x.sh, zsh x.sh or any other shell.
if [ -z "${TBPK_REEXEC:-}" ]; then
  case "${SHELLOPTS:-}" in *posix*) _tbpk_posix=1 ;; *) _tbpk_posix= ;; esac
  if [ -z "${BASH_VERSION:-}" ] || [ -n "$_tbpk_posix" ]; then TBPK_REEXEC=1; export TBPK_REEXEC; exec bash "$0" "$@"; fi
fi
set -euo pipefail

usage() {
  echo "Usage: uninstall-passwordless.sh [--dry-run]"
  echo "Removes the sudoers rule for this account. --dry-run only says what it would remove."
}
DRY=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) echo "unknown option: $a" >&2; usage >&2; exit 2 ;;
  esac
done

LOGIN_NAME=$(id -un)
# The rule file has a dot-free name (see install-passwordless.sh).
RULE_PATH=/etc/sudoers.d/tbpk-${LOGIN_NAME//./_}

if [ ! -e "$RULE_PATH" ]; then
  echo "Nothing to remove: $RULE_PATH does not exist."
  exit 0
fi
if [ "$DRY" = 1 ]; then
  echo "Dry run. Would remove: $RULE_PATH"
  exit 0
fi

echo "Removing the rule (asks for your password once)..."
sudo /bin/rm -f "$RULE_PATH"

echo "Re-validating the sudoers configuration..."
sudo /usr/sbin/visudo -c

echo "Done. Thai Baan Palang Bai Khrap will ask for your password on the next toggle."
