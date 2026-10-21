# Permissions

Turning sleep off on a Mac needs admin rights. This page says exactly what the app asks for and how to remove it. Found a problem? See [SECURITY.md](../SECURITY.md).

## The first time

The first time you turn Keep awake on, the app shows a window that explains itself before any password box appears. You choose:

- **Allow, no password after this.** macOS asks for your password once. The app adds one small file so it never asks again.
- **Ask for my password each time.** No file is added. macOS asks every time you switch. The app remembers this choice.
- **Cancel.** Nothing happens.

The app never saves your password, and it asks for nothing when it starts. If your Mac has Touch ID, the password box takes a fingerprint.

## The one file it adds

Only if you choose "no password after this", or later switch on **Low Power Mode while on battery** (that needs the same file, and its password box says so):

```
/etc/sudoers.d/tbpk-<your account name>

<you> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -b lowpowermode 1, /usr/bin/pmset -b lowpowermode 0
```

That lets your account run four exact commands as admin without a password. Nothing else. `sudo` matches the words of each command exactly, so the file cannot be stretched to run anything different.

The trade-off, plainly: anything running under your account can then switch this one setting without asking. It still cannot read your files or run any other command as admin. If that bothers you, choose "Ask for my password each time" and leave Low Power Mode off.

## Adding or removing it from Terminal

```bash
./scripts/install-passwordless.sh
./scripts/uninstall-passwordless.sh
```

`./uninstall.sh` removes the file too.

## How the file is put in place

It runs as admin, so it is done carefully:

- **Admin writes the file itself.** The app does not make a file and hand it over. Otherwise a program running as you could swap in a bigger permission while the password box is open.
- **It is checked before it counts.** It is written under a temporary name that `sudo` ignores, checked with `visudo`, locked down (owner root, read-only), and only then renamed into place. If the check fails, the temporary file is deleted.
- **It never edits `/etc/sudoers`.** If your Mac does not read the `/etc/sudoers.d` folder, the app stops and tells you. It accepts the line as `@includedir /etc/sudoers.d`, `@includedir /private/etc/sudoers.d` or the older `#includedir` spelling.
- **The account name is checked.** Only letters, digits, `.`, `_` and `-` are allowed, and not a leading `-` or the word `ALL`. `sudo` skips files with a dot in the name, so `first.last` becomes `tbpk-first_last` while the rule inside keeps the real name.
- **It checks the result.** After adding the file, the app asks `sudo` whether the rule really works, and only then says so.
