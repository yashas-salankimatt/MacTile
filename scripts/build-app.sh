#!/bin/bash

# Build MacTile as a distributable .app
# Usage: ./scripts/build-app.sh

set -e

# Configuration
APP_NAME="MacTile"
BUNDLE_ID="com.mactile.MacTile"
VERSION="1.4.1"

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_DIR="$PROJECT_DIR/build/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 Building MacTile..."
echo "   Project: $PROJECT_DIR"

# Clean previous build
rm -rf "$PROJECT_DIR/build"
mkdir -p "$PROJECT_DIR/build"

# Build in release mode
cd "$PROJECT_DIR"
swift build -c release

echo "📦 Creating app bundle..."

# Create app bundle structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/"

# Copy Info.plist
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/"

# Copy app icon
if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/"
    echo "   Icon copied"
else
    echo "   ⚠️  No icon found - run scripts/generate-icon.sh first"
fi

# Copy entitlements (for reference, not embedded in unsigned app)
cp "$PROJECT_DIR/Resources/MacTile.entitlements" "$RESOURCES_DIR/"

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

echo "🔏 Signing app (ad-hoc)..."

# Sign the app with ad-hoc signature (allows running without developer ID)
codesign --force --deep --sign - "$APP_DIR"

echo ""
echo "✅ Build complete!"
echo ""
echo "   App location: $APP_DIR"
echo ""
echo "📋 To install:"
echo "   1. Copy MacTile.app to /Applications"
echo "   2. Open MacTile.app"
echo "   3. Grant Accessibility permissions when prompted"
echo "      (System Settings → Privacy & Security → Accessibility)"
echo ""
echo "📋 To distribute:"
echo "   - For personal use: Share the .app directly"
echo "   - For wider distribution: Sign with a Developer ID"
echo ""

# Open the build folder
open "$PROJECT_DIR/build"
