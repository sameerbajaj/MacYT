#!/bin/bash
set -e

echo "🔨 Building MacYT (Release)..."
xcodebuild -project MacYT.xcodeproj -scheme MacYT -configuration Release clean build SYMROOT="$(PWD)/build"

APP_PATH="build/Release/MacYT.app"
DMG_NAME="MacYT.dmg"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Build failed. App not found at $APP_PATH"
    exit 1
fi

echo "📦 Creating DMG..."

# Try using 'create-dmg' if installed
if command -v create-dmg &> /dev/null; then
    rm -f "build/$DMG_NAME"
    create-dmg \
      --volname "MacYT Installer" \
      --window-pos 200 120 \
      --window-size 600 400 \
      --icon-size 100 \
      --icon "MacYT.app" 150 190 \
      --hide-extension "MacYT.app" \
      --app-drop-link 450 190 \
      "build/$DMG_NAME" \
      "$APP_PATH"
      
    echo "✅ DMG created successfully at build/$DMG_NAME"
else
    echo "⚠️ 'create-dmg' not found. Falling back to hdiutil."
    echo "💡 You can install it via 'brew install create-dmg' for formatted DMGs."
    
    rm -f "build/$DMG_NAME"
    hdiutil create build/temp.dmg -ov -volname "MacYT Installer" -fs HFS+ -srcfolder "$APP_PATH"
    hdiutil convert build/temp.dmg -format UDZO -o "build/$DMG_NAME"
    rm build/temp.dmg
    
    echo "✅ DMG created successfully at build/$DMG_NAME"
fi
