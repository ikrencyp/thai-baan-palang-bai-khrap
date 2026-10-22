#!/usr/bin/env bash
# Structure guard: keeps every dangerous capability inside a few named files, so a change that smuggles one in
# anywhere else fails the build and a reviewer sees it. Run by `make check`, the pre-commit hook and CI.
#
# Adding a file to an allowlist below is a security decision: say why in the commit. CODEOWNERS requires the
# owner to review this script, the workflows and the hooks.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

failed=0
fail() { echo "FAIL: $*" >&2; failed=1; }

# Lines of Swift code only: whole-line comments are not scanned.
swift_hits() { grep -rnE --include='*.swift' "$1" Sources | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' || true; }

# confine <what> <regex> [file...]: the pattern may appear only in the listed files (none listed: nowhere).
confine() {
  local what=$1 pattern=$2; shift 2
  local file allowed
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    allowed=0
    for a in "$@"; do [ "$file" = "Sources/TBPK/$a" ] && allowed=1; done
    [ "$allowed" = 1 ] || fail "$what in $file (allowed in: ${*:-nowhere})"
  done < <(swift_hits "$pattern" | cut -d: -f1 | sort -u)
}

# Starting another program.
confine "starts a process" 'Process\(\)' \
  Update/UpdateSource.swift Update/UpdateInstaller.swift Power/PrivilegedShell.swift Watch/DisplayControl.swift
confine "low-level process or shell call" 'posix_spawn|execv|popen\(|[^.[:alnum:]_]system\(|NSTask|NSUserUnixTask'

# Talking to the network. The updater is the only part that may.
confine "uses the network" 'URLSession|URLConnection|NWConnection|NWListener|CFSocket|CFStream|CFHTTP|import Network|MultipeerConnectivity' \
  Update/UpdateSource.swift
confine "hard-coded web address" 'https?://' Update/UpdateSource.swift

# Admin rights and sudoers.
confine "asks for admin rights or touches sudoers" 'administrator privileges|osascript|NOPASSWD|AuthorizationExecute|SMJobBless' \
  Power/PrivilegedShell.swift Power/ElevatedInstallCommand.swift

# Loading or hiding code at run time. The app has no use for any of it.
confine "dynamic code or obfuscation" 'dlopen|dlsym|NSClassFromString|@_silgen_name|@_cdecl|unsafeBitCast|NSAppleScript|JavaScriptCore|import WebKit|WKWebView|Bundle\(path:|\.load\(\)|base64Encoded|Data\(base64|NSExpression'

# The one key-value-coding call for the menu subtitle, which older SDKs cannot compile directly.
confine "selector chosen by name" 'NSSelectorFromString' Menu/MenuParts.swift

# Package.swift: no third-party code, no binaries, no build plugins, no unsafe flags.
if grep -nE '\.package\(|\.binaryTarget|\.plugin\(|\.systemLibrary|unsafeFlags|\.target\(|dependencies: \[[^]]' Package.swift | grep -v 'dependencies: \["TBPK"\]'; then
  fail "Package.swift pulls in code from outside Sources/TBPK"
fi
[ -z "$(git ls-files 'Package.resolved' '*/Package.resolved' '.swiftpm/*' 2>/dev/null)" ] || fail "Package.resolved or .swiftpm is tracked: the app has no dependencies"

# Shell scripts, comment lines skipped. curl and sudo stay in the scripts that need them.
shell_files=$(git ls-files '*.sh')
shell_hits() { for f in $shell_files; do grep -nE "$1" "$f" | grep -vE '^[0-9]+:[[:space:]]*#' | sed "s#^#$f:#" || true; done; }
[ -z "$(shell_hits '(^|[^[:alnum:]_])eval[[:space:]]|base64[[:space:]]+(-d|--decode|-D)|\|[[:space:]]*(ba|z)?sh([[:space:]]|$)')" ] \
  || fail "eval, base64 decoding or a pipe into a shell in a script: $(shell_hits '(^|[^[:alnum:]_])eval[[:space:]]|base64[[:space:]]+(-d|--decode|-D)|\|[[:space:]]*(ba|z)?sh([[:space:]]|$)' | head -1)"
for f in $shell_files; do
  case "$f" in get.sh|scripts/check-structure.sh) continue ;; esac
  ! grep -vE '^[[:space:]]*#' "$f" | grep -qE '(^|[^[:alnum:]_.-])(curl|wget|nc|ncat|scp|ssh)[[:space:]]' || fail "network tool in $f (allowed in get.sh only)"
done
for f in $shell_files; do
  case "$f" in scripts/check-structure.sh|uninstall.sh|install.sh|scripts/install-passwordless.sh|scripts/uninstall-passwordless.sh) continue ;; esac
  ! grep -vE '^[[:space:]]*#' "$f" | grep -qE '(^|[^[:alnum:]_.-])sudo[[:space:]]' || fail "sudo in $f (allowed in the sudoers scripts, uninstall.sh and install.sh's advice text only)"
done

# Workflows and hooks: every outside action is pinned to a full commit hash, never to a tag a maintainer can move.
for f in .github/workflows/*.yml; do
  unpinned=$(grep -nE '^[[:space:]-]*uses:[[:space:]]' "$f" | grep -vE 'uses:[[:space:]]+[^@[:space:]]+@[0-9a-f]{40}([[:space:]]|$)' || true)
  [ -z "$unpinned" ] || fail "action not pinned to a commit hash in $f: $(echo "$unpinned" | head -1)"
  ! grep -nE 'pull_request_target|workflow_run' "$f" || fail "$f uses a trigger that runs with secrets on outside code"
done
unpinned=$(grep -nE '^[[:space:]]*rev:' .pre-commit-config.yaml | grep -vE 'rev:[[:space:]]+[0-9a-f]{40}([[:space:]]|$)' || true)
[ -z "$unpinned" ] || fail "pre-commit hook not pinned to a commit hash: $(echo "$unpinned" | head -1)"

# Files in the repository: one binary (the icon), and only the known scripts are executable.
binary=$(git ls-files --eol | awk '$1 == "i/-text" || $2 == "w/-text" {print $NF}' | grep -vx 'Resources/AppIcon.icns' || true)
[ -z "$binary" ] || fail "binary file tracked: $(echo "$binary" | head -3 | tr '\n' ' ')"
executable=$(git ls-files -s | awk '$1 == "100755" {print $4}' | grep -vE '^(build|get|install|uninstall)\.sh$|^scripts/[a-z-]+\.sh$' || true)
[ -z "$executable" ] || fail "unexpected executable file: $(echo "$executable" | head -3 | tr '\n' ' ')"

if [ "$failed" = 0 ]; then echo "structure ok"; else echo "Structure guard failed. If a change is intended, edit the allowlist in scripts/check-structure.sh and explain why." >&2; exit 1; fi
