# MacTile

A macOS window tiling application inspired by [gTile](https://github.com/gTile/gTile) for GNOME. MacTile allows you to tile windows using a configurable grid system with keyboard navigation.

## Features

- **Configurable Grid**: Default 8x2 grid with presets for 6x4, 4x4, 3x3, and 2x2
- **Keyboard Navigation**: Use arrow keys or vim bindings (H/J/K/L) to select grid zones
- **Selection Extension**: Hold Shift to extend selection in any direction
- **Mouse Support**: Click and drag to select multiple grid cells
- **Global Hotkey**: Press `Control+Option+G` to toggle the grid overlay
- **Menu Bar App**: Runs in the menu bar with no dock icon

## Usage

1. **Start MacTile**: Run the application, it will appear in your menu bar
2. **Grant Accessibility Permission**: MacTile needs accessibility permissions to move and resize windows. Go to System Settings > Privacy & Security > Accessibility and enable MacTile
3. **Open the Grid**: Press `Control+Option+G` or click the menu bar icon and select "Show Grid"
4. **Navigate**: Use arrow keys or H/J/K/L to move the selection
5. **Extend Selection**: Hold Shift + arrow keys to extend the selection
6. **Apply**: Press Enter to resize the focused window to the selection
7. **Cancel**: Press Escape to close the overlay without changes
8. **Cycle Grid Size**: Press Space to cycle through grid presets

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Control+Option+G` | Toggle grid overlay |
| `Arrow keys` / `H/J/K/L` | Move selection |
| `Shift + Arrow keys` | Extend selection |
| `Enter` | Apply selection |
| `Escape` | Cancel |
| `Space` | Cycle grid size |

## Building from Source

```bash
# Clone and navigate to the project
cd MacTile

# Build
swift build

# Run
.build/debug/MacTile

# Run tests
swift test
```

## Requirements

- macOS 13.0 (Ventura) or later
- Accessibility permissions for window management

## Architecture

MacTile is built with a clean separation of concerns:

- **MacTileCore**: Core library with grid data structures, operations, and window management protocols
  - `Grid.swift`: GridSize, GridOffset, GridSelection, and GridOperations
  - `WindowManagement.swift`: WindowManagerProtocol and WindowTiler

- **MacTile**: Main application
  - `AppDelegate.swift`: Application lifecycle, menu bar, and hotkey setup
  - `OverlayWindowController.swift`: Grid overlay UI and keyboard handling
  - `WindowManager.swift`: Accessibility API integration for window manipulation

## Testing

The project includes comprehensive unit tests:

```bash
swift test
```

Tests cover:
- Grid data structures (GridSize, GridOffset, GridSelection)
- Grid operations (pan, adjust/extend, shrink)
- Coordinate conversion (selection to rectangle)
- Window tiling logic with mock window manager

## License

MIT License - See LICENSE file for details

## Credits

Inspired by [gTile](https://github.com/gTile/gTile) for GNOME Shell.
