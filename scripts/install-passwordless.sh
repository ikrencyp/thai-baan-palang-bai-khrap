#!/usr/bin/env bash
# One-time setup so Thai Baan Palang Bai Khrap can toggle sleep without a password prompt.
# Grants exactly four commands, for this account only. The app grants the same rule
# itself on first launch; this script is the Terminal equivalent for machines where
# you would rather not click through the app.
# Always runs under bash, however it was started: ./x.sh, sh x.sh, bash x.sh, zsh x.sh or any other shell.
if [ -z "${TBPK_REEXEC:-}" ]; then
  case "${SHELLOPTS:-}" in *posix*) _tbpk_posix=1 ;; *) _tbpk_posix= ;; esac
  if [ -z "${BASH_VERSION:-}" ] || [ -n "$_tbpk_posix" ]; then TBPK_REEXEC=1; export TBPK_REEXEC; exec bash "$0" "$@"; fi
fi
set -euo pipefail

LOGIN_NAME=$(id -un)
# sudo skips files in sudoers.d whose name contains a dot, so a dot in the account name becomes an underscore in the file name.
RULE_PATH=/etc/sudoers.d/tbpk-${LOGIN_NAME//./_}
# The login name goes into a sudoers line and a file name: only plain characters are accepted. A leading dash would
# read as an option and ALL is the sudoers keyword for every user.
case "$LOGIN_NAME" in
  ''|ALL|-*|*[!A-Za-z0-9._-]*) echo "The account name '$LOGIN_NAME' has characters that cannot go into a sudoers rule." >&2; exit 1 ;;
esac
RULE_LINE="$LOGIN_NAME ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -b lowpowermode 1, /usr/bin/pmset -b lowpowermode 0"

echo "This grants '$LOGIN_NAME' permission to run exactly these four commands as root,"
echo "with no password prompt:"
echo "    /usr/bin/pmset -a disablesleep 1"
echo "    /usr/bin/pmset -a disablesleep 0"
echo "    /usr/bin/pmset -b lowpowermode 1"
echo "    /usr/bin/pmset -b lowpowermode 0"
echo "Nothing else is granted. Undo with scripts/uninstall-passwordless.sh."
echo
printf 'Type yes to continue: '
read -r answer
if [ "$answer" != "yes" ]; then
  echo "Cancelled. Nothing was changed."
  exit 1
fi

# Without this line in /etc/sudoers the rule would be installed and silently ignored,
# which on another machine would look like the tool simply not working.
echo "Checking that sudo reads /etc/sudoers.d on this Mac..."
# The line is @includedir /etc/sudoers.d or @includedir /private/etc/sudoers.d (or the older #includedir spelling).
if ! sudo grep -Eq '^[@#]includedir[[:space:]]+(/private)?/etc/sudoers\.d/?[[:space:]]*$' /etc/sudoers; then
  echo "sudo on this Mac does not read /etc/sudoers.d." >&2
  echo 'Add the line  @includedir /etc/sudoers.d  to /etc/sudoers via sudo visudo, then retry.' >&2
  exit 1
fi

# Root writes the rule itself. A file in /tmp that this account owns could be swapped for a broader rule
# between the check and the install, so nothing the account can write is ever copied into /etc. The draft has
# a dot in its name, so sudo ignores it until visudo has accepted it and it is moved into place.
echo "Installing $RULE_PATH (asks for your password once)..."
sudo /bin/sh -c '
  rule="$1"; line="$2"; draft="$1.new"
  { umask 077 && printf "%s\n" "$line" > "$draft" && chmod 0440 "$draft" && chown root:wheel "$draft" \
      && /usr/sbin/visudo -c -f "$draft" && mv -f "$draft" "$rule"; } || { rm -f "$draft"; exit 1; }
' sh "$RULE_PATH" "$RULE_LINE"

echo "Re-validating the whole sudoers configuration..."
sudo /usr/sbin/visudo -c

echo
echo "Proving the toggle is now silent (flips on, shows it, flips off)..."
restore() { sudo -n /usr/bin/pmset -a disablesleep 0 2>/dev/null || true; }
if sudo -n /usr/bin/pmset -a disablesleep 1; then
  trap restore EXIT
  /usr/bin/pmset -g | grep -i sleepdisabled || echo "  (no SleepDisabled line?)"
  sudo -n /usr/bin/pmset -a disablesleep 0
  trap - EXIT
  echo "  enabled and restored without a password prompt."
else
  echo "  Still asking for a password. The rule did not take effect." >&2
  exit 1
fi

echo
echo "Done. Thai Baan Palang Bai Khrap picks this up on its next toggle."
