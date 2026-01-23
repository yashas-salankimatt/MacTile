import AppKit
import MacTileCore
import HotKey

// MacTile - A macOS window tiling application inspired by gTile
// Main entry point

print("MacTile starting...")

// Create and run the application
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
