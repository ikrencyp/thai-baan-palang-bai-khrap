# Releasing

A release is a GitHub Release tagged `v<x.y.z>`. The app's updater looks for the newest one (see [Updates](updates.md)), so the tag and the two attached files must be exact.

## The version number

It lives in three places. A unit test fails if they disagree:

| File | What it holds |
|---|---|
| `VERSION` | the number on one line, like `1.0.0` |
| `Sources/TBPK/Dialogs/AppInfo.swift` | `fallbackVersion`, used when the app runs outside a bundle |
| `CHANGELOG.md` | a `## x.y.z` heading at the top with `- ` lines under it. The first four show in the update window and become the release notes |

## Make a release

1. Change the number in those three places.
2. Run `make check`, commit, push to `main`.
3. Run `git tag v<x.y.z> && git push origin v<x.y.z>`.

The `Release` workflow then checks the tag matches `VERSION` and sits on `main`, runs the structure guard, builds, and publishes `TBPK-<x.y.z>.dmg` and `TBPK-<x.y.z>.dmg.sha256` with the changelog as notes. The updater and `get.sh` need both files, with exactly those names.

By hand instead: `./build.sh`, then
`gh release create v<x.y.z> dist/TBPK-<x.y.z>.dmg dist/TBPK-<x.y.z>.dmg.sha256 --notes-file notes.md`.

Then sign it on your own Mac: `scripts/sign-release.sh <x.y.z>`. It downloads the published dmg, shows its SHA-256 (compare it with the hash in the summary of the Release workflow run), signs it with `~/.ssh/tbpk_release_ed25519` and uploads `TBPK-<x.y.z>.dmg.sig`. Until that file is attached the app and `get.sh` do not offer the release.

The publish step runs in the `release` environment. Create it under Settings > Environments and add yourself as a required reviewer, and every release waits for your approval. Protect the `v*` tags too (Settings > Rules), so a published tag cannot be moved.

## The release signing key

`~/.ssh/tbpk_release_ed25519` signs every release. Its public half is in `Sources/TBPK/Update/ReleaseSignature.swift` (raw bytes) and `get.sh` (OpenSSH form); a unit test checks they are the same key. Keep a copy of the private key somewhere offline, and give it a passphrase (`ssh-keygen -p -f ~/.ssh/tbpk_release_ed25519`). If the key is lost or leaks, make a new one, put its public half in both places, and ship a release signed with the old key that carries the new one. Releases made before the change keep working for the apps that already trust the old key.

## Signing the app for macOS

Without a paid Apple Developer account the app is signed only "ad-hoc". macOS then blocks a dmg downloaded in a browser until `install.sh` or `xattr -dr com.apple.quarantine` clears the quarantine label. The `get.sh` one-liner avoids that, because `curl` does not add the label.

With an Apple Developer account, `build.sh` signs, notarizes and staples the dmg when you set:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" NOTARY_PROFILE=<profile> ./build.sh
# once: xcrun notarytool store-credentials <profile> --apple-id ... --team-id ... --password <app-specific>
```

For the `Release` workflow, add these repository secrets: `DEVELOPER_ID_P12` (the exported certificate, base64), `DEVELOPER_ID_P12_PASSWORD`, `NOTARY_APPLE_ID`, `NOTARY_TEAM_ID`, `NOTARY_PASSWORD` (an app-specific password). Without them it still publishes an ad-hoc signed dmg. Signing with a real certificate has not been tested yet.
