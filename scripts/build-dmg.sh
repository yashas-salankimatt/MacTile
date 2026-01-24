#!/bin/bash

# Build MacTile DMG for distribution
# Creates a DMG with MacTile.app and an Applications folder shortcut
# Usage: ./scripts/build-dmg.sh

set -e

# Configuration
APP_NAME="MacTile"
VERSION="1.0.2"
DMG_NAME="${APP_NAME}-${VERSION}"

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$DMG_NAME.dmg"
DMG_TEMP_DIR="$BUILD_DIR/dmg-temp"

echo "📦 Building MacTile DMG..."

# Build the app first if it doesn't exist
if [ ! -d "$APP_PATH" ]; then
    echo "   App not found, building first..."
    "$SCRIPT_DIR/build-app.sh"
fi

# Clean up any previous DMG build
rm -rf "$DMG_TEMP_DIR"
rm -f "$DMG_PATH"

# Create temporary directory for DMG contents
mkdir -p "$DMG_TEMP_DIR"

echo "   Copying app to DMG staging area..."
cp -R "$APP_PATH" "$DMG_TEMP_DIR/"

echo "   Creating Applications shortcut..."
ln -s /Applications "$DMG_TEMP_DIR/Applications"

echo "   Creating DMG..."

# Create the DMG
# -volname: Name shown when mounted
# -srcfolder: Source folder with contents
# -ov: Overwrite existing
# -format UDZO: Compressed DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Clean up temp directory
rm -rf "$DMG_TEMP_DIR"

echo ""
echo "✅ DMG created successfully!"
echo ""
echo "   DMG location: $DMG_PATH"
echo ""
echo "📋 To install:"
echo "   1. Open the DMG file"
echo "   2. Drag MacTile.app to the Applications folder"
echo "   3. Eject the DMG"
echo "   4. Open MacTile from Applications"
echo "   5. Grant Accessibility permissions when prompted"
echo ""

# Open the build folder
open "$BUILD_DIR"
