#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MacYT"
SCHEME="MacYT"
PROJECT="MacYT.xcodeproj"
CONFIGURATION="Release"

VERSION_SUFFIX="${1:-}"
MARKETING_VERSION="${2:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR="$BUILD_DIR/dmg-staging"
DERIVED_DATA_DIR="$BUILD_DIR/DerivedData"

if [[ -n "$VERSION_SUFFIX" ]]; then
    OUTPUT_DMG="$DIST_DIR/${APP_NAME}-${VERSION_SUFFIX}.dmg"
else
    OUTPUT_DMG="$DIST_DIR/${APP_NAME}.dmg"
fi

rm -rf "$STAGING_DIR" "$DERIVED_DATA_DIR"
mkdir -p "$STAGING_DIR" "$DIST_DIR"

XCBUILD_EXTRA_ARGS=()
BUILD_TIMESTAMP=$(date +%s)
XCBUILD_EXTRA_ARGS+=("CURRENT_PROJECT_VERSION=$BUILD_TIMESTAMP")

if [[ -n "$MARKETING_VERSION" ]]; then
    XCBUILD_EXTRA_ARGS+=("MARKETING_VERSION=$MARKETING_VERSION")
    echo "Stamping version: $MARKETING_VERSION"
fi

echo "🔨 Building $APP_NAME ($CONFIGURATION)..."
xcodebuild \
    -project "$ROOT_DIR/$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    CODE_SIGNING_ALLOWED=NO \
    "${XCBUILD_EXTRA_ARGS[@]}" \
    clean build

APP_PATH="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "❌ Build failed. App not found at $APP_PATH"
    exit 1
fi

echo "🔏 Ad-hoc signing…"
codesign --force --deep --sign - "$APP_PATH"

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "📦 Creating DMG..."
if command -v create-dmg >/dev/null 2>&1; then
    rm -f "$OUTPUT_DMG"
    create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --volicon "$ROOT_DIR/scripts/AppIcon.icns" \
        --icon "$APP_NAME.app" 150 190 \
        --hide-extension "$APP_NAME.app" \
        --app-drop-link 450 190 \
        "$OUTPUT_DMG" \
        "$STAGING_DIR"
else
    TMP_DMG="$BUILD_DIR/temp-${APP_NAME}.dmg"
    rm -f "$TMP_DMG" "$OUTPUT_DMG"
    hdiutil create "$TMP_DMG" -ov -volname "$APP_NAME" -fs HFS+ -srcfolder "$STAGING_DIR"
    hdiutil convert "$TMP_DMG" -format UDZO -o "$OUTPUT_DMG"
    rm -f "$TMP_DMG"
fi

echo "✅ DMG created successfully at $OUTPUT_DMG"
