#!/usr/bin/env bash
# Always runs under bash, however it was started: ./x.sh, sh x.sh, bash x.sh, zsh x.sh or any other shell.
if [ -z "${TBPK_REEXEC:-}" ]; then
  case "${SHELLOPTS:-}" in *posix*) _tbpk_posix=1 ;; *) _tbpk_posix= ;; esac
  if [ -z "${BASH_VERSION:-}" ] || [ -n "$_tbpk_posix" ]; then TBPK_REEXEC=1; export TBPK_REEXEC; exec bash "$0" "$@"; fi
fi
set -euo pipefail

APP_NAME="TBPK"
DISPLAY_NAME="Thai Baan Palang Bai Khrap"
BUNDLE_ID="com.thaibaan.tbpk"
MIN_MACOS="13.0"
ARCHS=("arm64" "x86_64")

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD="$ROOT/build"
DIST="$ROOT/dist"
APP="$DIST/$DISPLAY_NAME.app"
STAGING="$BUILD/dmg"
DMG="$DIST/$APP_NAME-$VERSION.dmg"

# The build needs macOS and the Swift toolchain (Xcode or the Command Line Tools). Without them, start the Apple installer and stop.
[ "$(uname -s)" = Darwin ] || { echo "error: TBPK is a macOS app; build it on a Mac" >&2; exit 1; }
if ! xcode-select -p >/dev/null 2>&1 || ! command -v swift >/dev/null 2>&1; then
  echo "Swift is not installed (it comes with the Xcode Command Line Tools)."
  echo "A macOS dialog opens now: finish the install (a few minutes), then run ./build.sh again."
  xcode-select --install 2>/dev/null || true
  exit 1
fi

echo "==> Clean"
rm -rf "$BUILD" "$APP" "$DMG"
mkdir -p "$BUILD" "$DIST" "$APP/Contents/MacOS" "$APP/Contents/Resources" "$STAGING"

echo "==> Test"
swift test --package-path "$ROOT" 2>&1 | tail -3

echo "==> Compile ${ARCHS[*]}"
SLICES=()
for ARCH in "${ARCHS[@]}"; do
  swift build -c release \
    --triple "${ARCH}-apple-macosx${MIN_MACOS}" \
    --scratch-path "$BUILD/spm-$ARCH" \
    --package-path "$ROOT"
  SLICES+=("$BUILD/spm-$ARCH/release/$APP_NAME")
done
lipo -create -output "$BUILD/$APP_NAME" "${SLICES[@]}"
cp "$BUILD/$APP_NAME" "$APP/Contents/MacOS/$DISPLAY_NAME"
if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi
# The list of changes is shown in the app (What's new).
cp "$ROOT/CHANGELOG.md" "$APP/Contents/Resources/CHANGELOG.md"

echo "==> Info.plist"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>$DISPLAY_NAME</string>
	<key>CFBundleExecutable</key>
	<string>$DISPLAY_NAME</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$DISPLAY_NAME</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.utilities</string>
	<key>LSMinimumSystemVersion</key>
	<string>$MIN_MACOS</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
PLIST
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Signing. Without an Apple Developer ID the app is ad-hoc signed: it runs, but Gatekeeper blocks a copy that
# arrived with a quarantine flag (install.sh clears it). With a Developer ID, set
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
#   NOTARY_PROFILE=<name stored once with: xcrun notarytool store-credentials <name>>
# and the app is signed with the hardened runtime, the dmg is notarized and stapled, and nothing needs clearing.
if [ -n "${SIGN_IDENTITY:-}" ]; then
  echo "==> Developer ID sign"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
else
  echo "==> Ad-hoc sign (set SIGN_IDENTITY for a Developer ID signature)"
  codesign --force --sign - "$APP"
fi

echo "==> Package .dmg"
cp -R "$APP" "$STAGING/"
cp "$ROOT/install.sh" "$ROOT/uninstall.sh" "$ROOT/VERSION" "$STAGING/"
ln -sfn /Applications "$STAGING/Applications"
hdiutil create -volname "$DISPLAY_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
if [ -n "${SIGN_IDENTITY:-}" ]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
  if [ -n "${NOTARY_PROFILE:-}" ]; then
    echo "==> Notarize (a few minutes)"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
  fi
fi
# The app checks a downloaded dmg against this file before it installs it.
( cd "$DIST" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256" )

echo
echo "==> Done"
echo "binary archs : $(lipo -archs "$APP/Contents/MacOS/$DISPLAY_NAME")"
echo "signature    : $(codesign -dv "$APP" 2>&1 | grep -E '^(Signature|Identifier)' | tr '\n' ' ')"
echo "app          : $APP"
echo "release      : gh release create v$VERSION \"$DMG\" \"$DMG.sha256\" --title v$VERSION --notes-file <notes>"
echo "dmg          : $DMG ($(du -h "$DMG" | cut -f1))"
