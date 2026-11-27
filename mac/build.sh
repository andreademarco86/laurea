#!/usr/bin/env bash
# Build "Laurea.app" and package it as a DMG.
# Usage: bash build.sh            (outputs to ./build and ../dist)
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Laurea"
EXEC="Laurea"
VERSION="${VERSION:-1.2}"
BUILD="build"
APP="$BUILD/$APP_NAME.app"
DIST="../dist"
ENGINE="../engine/server.py"

rm -rf "$APP"
mkdir -p "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$DIST"

echo "› Compiling (arm64 + x86_64)"
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -parse-as-library \
    -target "$arch-apple-macos14.0" \
    -framework SwiftUI -framework PDFKit -framework Charts -framework AppKit \
    Sources/*.swift -o "$BUILD/$EXEC-$arch"
done
lipo -create "$BUILD/$EXEC-arm64" "$BUILD/$EXEC-x86_64" -output "$APP/Contents/MacOS/$EXEC"

if [ ! -f "$BUILD/AppIcon.icns" ]; then
  echo "› Icon"
  mkdir -p "$BUILD/AppIcon.iconset"
  swift icon/make_icon.swift "$BUILD/icon_1024.png" >/dev/null
  for s in 16 32 128 256 512; do
    sips -z $s $s "$BUILD/icon_1024.png" --out "$BUILD/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) "$BUILD/icon_1024.png" --out "$BUILD/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$BUILD/AppIcon.iconset" -o "$BUILD/AppIcon.icns"
fi

echo "› Resources"
cp "$ENGINE" "$APP/Contents/Resources/server.py"
# The examiner skill: only files tracked in git, so no personal data (name, signature, calibration) is ever bundled.
( cd .. && git ls-files -z skill ) | while IFS= read -r -d '' f; do
  mkdir -p "$APP/Contents/Resources/$(dirname "$f")"
  cp "../$f" "$APP/Contents/Resources/$f"
done
# A new build replaces the installed examining standards and clears teaching history (see install_examiner).
uuidgen > "$APP/Contents/Resources/build-id"
# PDF helpers (PDFKit), prebuilt so sandboxed engines never need to compile them
mkdir -p "$APP/Contents/Resources/bin"
for tool in pdftext pdfrender; do
  for arch in arm64 x86_64; do
    swiftc -O -target "$arch-apple-macos14.0" "../skill/scripts/$tool.swift" -o "$BUILD/$tool-$arch" 2>/dev/null
  done
  lipo -create "$BUILD/$tool-arm64" "$BUILD/$tool-x86_64" -output "$APP/Contents/Resources/bin/$tool"
done
if [ -f "$BUILD/AppIcon.icns" ]; then cp "$BUILD/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"; fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleExecutable</key><string>$EXEC</string>
  <key>CFBundleIdentifier</key><string>local.laurea</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$(date +%Y%m%d%H%M)</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.education</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
  <key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
  <key>NSHumanReadableCopyright</key><string>Laurea dissertation examination.</string>
</dict>
</plist>
PLIST

echo "› Signing (ad hoc)"
codesign --force --deep --sign - "$APP"

echo "› DMG"
STAGE="$BUILD/dmg"
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="$DIST/$APP_NAME $VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO -fs HFS+ "$DMG" >/dev/null
echo "✓ $DMG"
