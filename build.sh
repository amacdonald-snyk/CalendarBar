#!/bin/zsh
# Builds CalendarBar and wraps it in a menubar-only .app bundle at build/CalendarBar.app
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP=build/CalendarBar.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/CalendarBar "$APP/Contents/MacOS/CalendarBar"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.example.CalendarBar</string>
  <key>CFBundleName</key><string>CalendarBar</string>
  <key>CFBundleExecutable</key><string>CalendarBar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $APP"
