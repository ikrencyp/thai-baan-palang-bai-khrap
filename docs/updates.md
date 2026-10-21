# Updates

## How it works

The app looks for a new version 15 seconds after it starts (if the last look was 6 hours ago or more), then about every 6 hours. Each look is one question to GitHub: "what is the newest release?" Nothing else is sent.

**Settings > Updates** has three switches. Each one only counts if the one above it is on:

1. **Check for updates automatically** (on)
2. **Download new updates when available** (on)
3. **Install updates automatically** (off)

When a newer version exists, a blue dot appears on the leaf. Once it is downloaded, the menu says **Restart to update to x.y.z...**. Click it and the app installs the new version and opens again. The dialog shows the first lines of the release notes.

## What counts as a release

A release the app will offer must be public (not a draft or a pre-release), be tagged `v<x.y.z>`, and have two files attached: `TBPK-<x.y.z>.dmg` and `TBPK-<x.y.z>.dmg.sha256`.

## Is it safe?

- The download comes from GitHub over HTTPS only.
- The app checks the file against the `.sha256` file and throws it away if they do not match. That catches a damaged or half-finished download. It does not protect you if someone could publish a bad release to the repository. A notarized app would add Apple's check on top, which this project does not have yet.
- It never installs by itself unless you turn on the third switch. Even then it waits until Keep awake is off, so it never cuts a running job short.

## What the install does

1. Turns Keep awake off (the same as Quit). If that fails, the update stops.
2. Quits the app.
3. Runs `install.sh -y` from the downloaded file, which replaces the app in Applications.
4. Opens the app again, trying up to five times.

What happened is written to `~/Library/Application Support/Thai Baan Palang Bai Khrap/update.log`. If your Mac cannot reach GitHub, the update items hide until it can.

## Trying it without touching your real install

Make a copy of the app with a different `CFBundleIdentifier`, then start that copy with `TBPK_UPDATE_API=file:///path/to/release.json` (a saved copy of the GitHub answer, with `file://` paths for the files) and `TBPK_INSTALL_DIR=/path/to/a/scratch/folder`.
