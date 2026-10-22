# Contributing

Issues and pull requests are welcome. For a security problem use [SECURITY.md](SECURITY.md), not a public issue.

## Setup

macOS 13 or newer with Xcode or the Command Line Tools.

```bash
make test       # unit tests
make build      # tests, universal build, dist/TBPK-<version>.dmg and .sha256
make check      # shellcheck, the structure guard and unit tests (needs: brew install shellcheck). CI also runs gitleaks
make structure  # only the structure guard: process, network and admin code stay in their named files
make help       # every target
```

`Tests/TBPKTests/LiveSystemTests.swift` runs against your own Mac (real `pmset`, the speaker, a power assertion) and is skipped unless you ask for it. It needs the no-password sudoers rule, switches sleep on and off for a few seconds, and plays one short sound. Run it with `TBPK_LIVE=1 swift test --filter LiveSystemTests`.

## Git hooks (optional, recommended)

They stop a secret from being committed by mistake.

```bash
brew install pre-commit gitleaks
make hooks
```

- Every commit: gitleaks on the staged changes, plus checks for private keys, merge-conflict markers and files over 1 MB.
- Every push: gitleaks on the outgoing commits and `swift test` (about 20 seconds).
- Skip one hook for one command with `SKIP=swift-test git push`. Never skip gitleaks to get past a finding.
- A false alarm gets a narrow rule or allowlist in `.gitleaks.toml`, or `#gitleaks:allow` on that line.

CI runs gitleaks too, so a skipped hook still gets caught.

## Layout

```
Sources/TBPK/     the app (docs/architecture.md describes the folders)
Tests/TBPKTests/  one file per test class (logic is unit tested; windows and system glue are checked by hand)
scripts/         icon generator, sudoers rule scripts
docs/            usage, updates, permissions, architecture, releasing
VERSION          the release number
build.sh  install.sh  uninstall.sh  get.sh   stay at the root: the dmg, the updater and the README one-liner expect them there
```

## Rules

- Keep tests hermetic. Prefer `scratchDefaults(_:)` for settings and leave nothing in `~/Library/Preferences` or the temp folder.
- Never run `install.sh` or `uninstall.sh` against your real `$HOME` in a test. `TBPK_INSTALL_DIR` redirects the install target.
- Never commit a real home path, personal e-mail or account name.
- One class, struct or enum per file, in `Sources/` and `Tests/`, named after the type. Small helper types nested inside a type may stay with it.
- Commit messages are one line: `type(scope): short description`.
- Changing behaviour means updating `CHANGELOG.md`, `README.md` and `docs/` in the same change.

- A change that adds process, network or admin code outside the allowed files fails `scripts/check-structure.sh`. Moving a file onto an allowlist needs the owner's review and a reason in the commit.
- New workflow actions and hooks are pinned to a full commit hash, with the tag in a comment.

## Signed commits

`main` accepts only signed commits. Sign with an SSH key: create one with `ssh-keygen -t ed25519`, add its `.pub` file on GitHub under Settings > SSH and GPG keys as a **Signing key**, then in the clone run `git config gpg.format ssh && git config user.signingkey ~/.ssh/<key>.pub && git config commit.gpgsign true`. The commit email must be a verified address of your GitHub account.

## Releasing

See [docs/releasing.md](docs/releasing.md).

## License

By contributing you agree that your work is released under the MIT License (see `LICENSE`).
