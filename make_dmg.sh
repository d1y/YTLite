#!/bin/bash
# make_dmg.sh — builds an unsigned macOS app (Mac Catalyst) and packages a DMG
# Usage: ./make_dmg.sh
# Output: YTLite_<version>_macOS.dmg in the project root
#
# Env overrides (optional):
#   DMG_VERSION              version for the filename (default: MARKETING_VERSION)
#   BUILD_NUMBER             sets CFBundleVersion when provided
#   XCODEBUILD_EXTRA_ARGS    extra xcodebuild args, e.g. CODE_SIGNING_ALLOWED=NO
#   DERIVED_DATA_PATH        custom DerivedData path

set -euo pipefail

APP_NAME="YTLite"
PROJECT="YTLite.xcodeproj"
SCHEME="YTVLite"
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT/build/DerivedData-mac}"
BUILD_LOG="${TMPDIR:-/tmp}/ytlite_make_dmg_$$.log"
mkdir -p "$DERIVED_DATA_PATH"

# Prefer Mac Catalyst destination (shared UIKit codebase). Fall back notes
# are written if the platform is unavailable.
DESTINATION="generic/platform=macOS,variant=Mac Catalyst"

echo "▶ Building Release for macOS (Mac Catalyst)..."
set +e
# Allow packaging without a local SwiftLint install (CI/unsigned path).
export SKIP_SWIFTLINT="${SKIP_SWIFTLINT:-1}"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="-" \
  SUPPORTS_MACCATALYST=YES \
  ${XCODEBUILD_EXTRA_ARGS:-} \
  build \
  > "$BUILD_LOG" 2>&1
BUILD_STATUS=$?
set -e

grep -E "error:|warning:.*error" "$BUILD_LOG" | tail -20 || true
if ! grep -q "BUILD SUCCEEDED" "$BUILD_LOG"; then
  echo "❌ Build failed (exit $BUILD_STATUS) — full log: $BUILD_LOG"
  tail -40 "$BUILD_LOG"
  exit 1
fi

# Locate the built .app (Catalyst products live under a maccatalyst arch folder)
APP_PATH=$(find "$DERIVED_DATA_PATH/Build/Products" -type d -name "${APP_NAME}.app" 2>/dev/null | head -1)
if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
  echo "❌ Built app not found under $DERIVED_DATA_PATH/Build/Products"
  find "$DERIVED_DATA_PATH/Build/Products" -maxdepth 4 -type d 2>/dev/null | head -40 || true
  exit 1
fi

BUILD_SETTINGS=$(xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "$DESTINATION" \
  -showBuildSettings 2>/dev/null || true)
VERSION="${DMG_VERSION:-$(echo "$BUILD_SETTINGS" | grep "^ *MARKETING_VERSION" | head -1 | awk -F' = ' '{print $2}')}"
VERSION="${VERSION:-1.0.0}"
OUTPUT="${APP_NAME}_${VERSION}_macOS.dmg"

if [ -n "${BUILD_NUMBER:-}" ] && [ -f "$APP_PATH/Contents/Info.plist" ]; then
  plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true
fi
if [ -f "$APP_PATH/Contents/Info.plist" ]; then
  plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true
fi

# Ad-hoc / unsigned deep sign (optional; CODE_SIGNING_ALLOWED=NO often leaves unsigned)
echo "▶ Ad-hoc codesign (unsigned identity)..."
ENTITLEMENTS="$ROOT/YTLite/YTLite.entitlements"
if [ -f "$ENTITLEMENTS" ]; then
  codesign -f -s - --deep --entitlements "$ENTITLEMENTS" "$APP_PATH" 2>/dev/null \
    && echo "  codesign: ok (with network.client entitlement)" \
    || echo "  codesign: skipped (unsigned package is still usable for local runs)"
else
  codesign -f -s - --deep "$APP_PATH" 2>/dev/null \
    && echo "  codesign: ok" \
    || echo "  codesign: skipped (unsigned package is still usable for local runs)"
fi

echo "▶ Packaging DMG..."
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP_PATH" "$STAGE/"
# Optional Applications symlink for drag-install UX
ln -sf /Applications "$STAGE/Applications" 2>/dev/null || true

rm -f "$ROOT/$OUTPUT"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$ROOT/$OUTPUT" \
  >/dev/null

SIZE=$(du -sh "$ROOT/$OUTPUT" | cut -f1)
echo "✅ $OUTPUT ($SIZE) — unsigned macOS package ready"
echo "   App source: $APP_PATH"
echo "   Install: open the DMG and drag $APP_NAME to Applications (Gatekeeper may require right-click → Open)"

rm -f "$BUILD_LOG"
