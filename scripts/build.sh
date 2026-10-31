#!/bin/bash
# Builds dist/Sova.app (release build, ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product Sova
BIN="$(swift build -c release --show-bin-path)/Sova"

APP=dist/Sova.app
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Sova"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - --identifier com.ungurenko.sova "$APP"
codesign --verify --strict "$APP"
echo "built $APP"
