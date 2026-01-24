# Building MacTile

This document describes how to build and run MacTile for development and release.

## Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode Command Line Tools (`xcode-select --install`)
- Swift 5.9 or later

### Optional (for icon generation)

- librsvg (`brew install librsvg`) - for regenerating the app icon from SVG

## Development

### Running from Terminal

The fastest way to run MacTile during development:

```bash
# Build and run in debug mode
swift run MacTile
```

This will:
1. Build the project in debug mode
2. Run MacTile directly from the terminal
3. Show all debug output in the terminal

### Running Tests

```bash
# Run all tests
swift test

# Run tests with verbose output
swift test --verbose
```

### Building Debug Version

```bash
# Build debug version only (without running)
swift build
```

The debug executable will be at `.build/debug/MacTile`

## Release Build

### Building the .app Bundle

To build a distributable macOS application:

```bash
# Build the release .app
./scripts/build-app.sh
```

This will:
1. Build MacTile in release mode (optimized)
2. Create `MacTile.app` in the `build/` directory
3. Copy the app icon and resources
4. Sign the app with an ad-hoc signature

The app will be at: `build/MacTile.app`

### Building the DMG (for distribution)

To create a DMG disk image for easy distribution:

```bash
# Build the DMG (includes building the .app if needed)
./scripts/build-dmg.sh
```

This will:
1. Build MacTile.app if not already built
2. Create a DMG containing the app and an Applications shortcut
3. The DMG will be at: `build/MacTile-1.0.3.dmg`

Recipients can open the DMG and drag MacTile to Applications to install.

### Regenerating the App Icon

If you need to regenerate the app icon (e.g., after modifying the source SVG):

```bash
# Generate AppIcon.icns from the gTile SVG
./scripts/generate-icon.sh
```

This requires `librsvg` to be installed (`brew install librsvg`).

## Installation

### For Personal Use

1. Run `./scripts/build-app.sh`
2. Copy `build/MacTile.app` to `/Applications`
3. Open MacTile.app
4. If macOS blocks the app:
   - Go to **System Settings → Privacy & Security**
   - Click "Open Anyway" next to the MacTile message
5. Grant Accessibility permissions when prompted:
   - Go to **System Settings → Privacy & Security → Accessibility**
   - Enable MacTile in the list

### For Distribution

The ad-hoc signed app can be shared directly, but recipients will need to:
1. Right-click → Open (or allow in Security settings)
2. Grant Accessibility permissions

For wider distribution without security warnings, you would need:
- An Apple Developer ID ($99/year)
- Code signing with your Developer ID
- Notarization through Apple

## Project Structure

```
MacTile/
├── Sources/
│   ├── MacTile/           # Main app code
│   │   ├── main.swift
│   │   ├── AppDelegate.swift
│   │   ├── WindowManager.swift
│   │   ├── OverlayWindowController.swift
│   │   ├── SettingsWindowController.swift
│   │   └── SettingsManager.swift
│   └── MacTileCore/       # Core library (grid operations, settings)
├── Tests/
│   └── MacTileTests/      # Unit tests
├── Resources/
│   ├── Info.plist         # App metadata
│   ├── MacTile.entitlements
│   └── AppIcon.icns       # App icon
├── scripts/
│   ├── build-app.sh       # Build release .app
│   ├── build-dmg.sh       # Build distributable DMG
│   └── generate-icon.sh   # Generate app icon
├── build/                 # Release build output (created by build-app.sh)
├── Package.swift          # Swift Package Manager config
└── BUILD.md               # This file
```

## Troubleshooting

### "MacTile cannot be opened because the developer cannot be verified"

This is normal for ad-hoc signed apps. To open:
1. Go to **System Settings → Privacy & Security**
2. Find the message about MacTile being blocked
3. Click "Open Anyway"

### MacTile doesn't respond to the hotkey

1. Check that Accessibility permissions are granted:
   - **System Settings → Privacy & Security → Accessibility**
   - Ensure MacTile is in the list and enabled
2. If you just granted permissions, restart MacTile

### Windows don't resize correctly

Some applications have minimum window sizes or unusual resize behavior. MacTile will attempt multiple retries to achieve the target size. If a window consistently fails to resize:
- The app may have a minimum window size larger than requested
- Try selecting a larger grid area

### Build fails with "no such module"

Run `swift package resolve` to fetch dependencies:

```bash
swift package resolve
swift build
```

## License

MacTile is inspired by [gTile](https://github.com/gTile/gTile) for GNOME.
