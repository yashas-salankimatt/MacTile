#!/bin/bash

# Generate macOS app icon (.icns) from SVG
# Requires: rsvg-convert (brew install librsvg)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESOURCES_DIR="$PROJECT_DIR/Resources"
ICONSET_DIR="$RESOURCES_DIR/AppIcon.iconset"

# Source SVG from gTile (dark launcher active icon)
SVG_SOURCE="/Users/yashas/Documents/scratch/mac_gtile/gTile/dist/images/launcher/dark/source/active.svg"

echo "🎨 Generating app icon from gTile..."

# Create iconset directory
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Generate PNG files at required sizes for macOS
# Standard sizes: 16, 32, 128, 256, 512
# Plus @2x versions for Retina displays

echo "   Converting SVG to PNG at multiple sizes..."

rsvg-convert -w 16 -h 16 "$SVG_SOURCE" -o "$ICONSET_DIR/icon_16x16.png"
rsvg-convert -w 32 -h 32 "$SVG_SOURCE" -o "$ICONSET_DIR/icon_16x16@2x.png"
rsvg-convert -w 32 -h 32 "$SVG_SOURCE" -o "$ICONSET_DIR/icon_32x32.png"
rsvg-convert -w 64 -h 64 "$SVG_SOURCE" -o "$ICONSET_DIR/icon_32x32@2x.png"
rsvg-convert -w 128 -h 128 "$SVG_SOURCE" -o "$ICONSET_DIR/icon_128x128.png"
rsvg-convert -w 256 -h 256 "$SVG_SOURCE" -o "$ICONSET_DIR/icon_128x128@2x.png"
rsvg-convert -w 256 -h 256 "$SVG_SOURCE" -o "$ICONSET_DIR/icon_256x256.png"
rsvg-convert -w 512 -h 512 "$SVG_SOURCE" -o "$ICONSET_DIR/icon_256x256@2x.png"
rsvg-convert -w 512 -h 512 "$SVG_SOURCE" -o "$ICONSET_DIR/icon_512x512.png"
rsvg-convert -w 1024 -h 1024 "$SVG_SOURCE" -o "$ICONSET_DIR/icon_512x512@2x.png"

echo "   Creating .icns file..."

# Convert iconset to icns
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"

# Clean up iconset directory
rm -rf "$ICONSET_DIR"

echo "✅ Icon generated: $RESOURCES_DIR/AppIcon.icns"
