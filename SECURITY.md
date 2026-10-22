# Security

The app runs `pmset` as admin. If you choose "no password after this", it adds one file that lets your account run four exact `pmset` commands without a password, and nothing else. [docs/permissions.md](docs/permissions.md) has the details.

## How the code is kept from growing a backdoor

- `scripts/check-structure.sh` (run by `make check`, the pre-commit hook, CI and the release build) fails when starting a process, using the network, asking for admin rights, loading code at run time or decoding hidden payloads appears outside the few files that need it. The app has no third-party dependencies, and every workflow action and hook is pinned to a full commit hash.
- `.github/CODEOWNERS` names the owner for the updater, the power and sudoers code, the scripts and the workflows.
- Every release dmg is signed on the maintainer's own Mac (`scripts/sign-release.sh`) and the app and `get.sh` refuse one that is not. The private key never touches GitHub, so a taken-over account or a replaced release cannot ship an update.
- The `Release` workflow builds without write access, only builds a tag that sits on `main`, and publishes in a separate job that can wait for a reviewer.

Settings that live on GitHub, not in the code (set them once in the repository settings): protect `main` (pull request, code-owner review, no force push, signed commits), protect `v*` tags so they cannot be moved or deleted, and add a `release` environment with a required reviewer.

**Found a problem?** Please do not open a public issue. Use the Security tab on GitHub and press "Report a vulnerability". Tell me the app version and the steps to repeat it.
