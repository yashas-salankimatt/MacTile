# MacTile

A macOS window tiling application inspired by [gTile](https://github.com/gTile/gTile) for GNOME. MacTile allows you to tile windows using a configurable grid system with keyboard navigation.

## Features

- **Configurable Grid**: Default 8x2 grid with customizable presets
- **gTile-Style Selection**: Use arrow keys for first corner, Shift+arrows for second corner
- **Keyboard Navigation**: Use arrow keys or vim bindings (H/J/K/L)
- **Mouse Support**: Click and drag to select multiple grid cells
- **Global Hotkey**: Customizable hotkey (default: `Control+Option+G`)
- **Settings Window**: Configure grid sizes, window spacing, screen insets, and shortcuts
- **Menu Bar App**: Runs in the menu bar with no dock icon

## Usage

1. **Start MacTile**: Run the application, it will appear in your menu bar
2. **Grant Accessibility Permission**: MacTile needs accessibility permissions to move and resize windows. Go to System Settings > Privacy & Security > Accessibility and enable MacTile
3. **Open the Grid**: Press `Control+Option+G` or click the menu bar icon and select "Show Grid"
4. **Select First Corner**: Use arrow keys or H/J/K/L to position the first corner (green marker)
5. **Select Second Corner**: Hold Shift + arrow keys to position the second corner (orange marker)
6. **Apply**: Press Enter to resize the focused window to the selection
7. **Cancel**: Press Escape to close the overlay without changes
8. **Cycle Grid Size**: Press Space to cycle through grid presets

## Keyboard Shortcuts

### Global
| Key | Action |
|-----|--------|
| `Control+Option+G` | Toggle grid overlay (customizable in Settings) |

### In Overlay
| Key | Action |
|-----|--------|
| `Arrow keys` / `H/J/K/L` | Move first corner (green marker) |
| `Shift + Arrow keys` / `Shift + H/J/K/L` | Move second corner (orange marker) |
| `Enter` | Apply selection and resize window |
| `Escape` | Cancel and close overlay |
| `Space` | Cycle through grid sizes |

## Settings

Access Settings from the menu bar icon. You can configure:

- **Grid Sizes**: Comma-separated list of grid presets (e.g., "8x2, 6x4, 4x4")
- **Window Spacing**: Gap between tiled windows (0-50 pixels)
- **Screen Insets**: Margins from screen edges (top, left, bottom, right)
- **Auto-Close**: Whether to close overlay after applying resize
- **Show Menu Bar Icon**: Toggle menu bar visibility
- **Toggle Overlay Shortcut**: Custom keyboard shortcut for showing the grid

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

## Technical Documentation

For a detailed explanation of how MacTile's window management system works, including the challenges with macOS's asynchronous Accessibility API and the algorithms used to achieve reliable window tiling, see [WINDOW_MANAGEMENT.md](WINDOW_MANAGEMENT.md).

## Architecture

MacTile is built with a clean separation of concerns:

- **MacTileCore**: Core library with grid data structures, operations, and settings
  - `Grid.swift`: GridSize, GridOffset, GridSelection, and GridOperations
  - `Settings.swift`: MacTileSettings, KeyboardShortcut configuration
  - `WindowManagement.swift`: WindowManagerProtocol and WindowTiler

- **MacTile**: Main application
  - `AppDelegate.swift`: Application lifecycle, menu bar, and hotkey setup
  - `OverlayWindowController.swift`: Grid overlay UI and keyboard handling
  - `SettingsWindowController.swift`: Settings window UI
  - `SettingsManager.swift`: UserDefaults persistence
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
