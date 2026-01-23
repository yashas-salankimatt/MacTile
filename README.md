# MacTile

A macOS window tiling application inspired by [gTile](https://github.com/gTile/gTile) for GNOME. MacTile allows you to tile windows using a configurable grid system with keyboard and mouse navigation.

## Features

- **Configurable Grid**: Multiple grid presets (8x2, 6x4, 4x4, 3x3, 2x2) with customizable sizes
- **Three Selection Modes**: Pan entire selection, adjust first corner, or adjust second corner
- **Keyboard Navigation**: Use arrow keys or vim bindings (H/J/K/L)
- **Mouse Support**: Click and drag to select grid regions, click inside selection to confirm
- **Multi-Monitor Support**: Switch overlay between monitors with Tab or mouse movement
- **Dual Global Hotkeys**: Primary (`Control+Option+G`) and secondary (`Command+Return`) shortcuts
- **Customizable Appearance**: Configure colors, opacity, and visual elements
- **Settings Window**: Configure grid sizes, spacing, insets, shortcuts, and behavior
- **Menu Bar App**: Runs in the menu bar with no dock icon

## Usage

1. **Start MacTile**: Run the application, it will appear in your menu bar
2. **Grant Accessibility Permission**: MacTile needs accessibility permissions to move and resize windows. Go to System Settings > Privacy & Security > Accessibility and enable MacTile
3. **Open the Grid**: Press `Control+Option+G` (or `Command+Return`) or click the menu bar icon
4. **Select Region**:
   - Use arrow keys to pan the selection
   - Hold Shift + arrows to adjust the first corner (green marker)
   - Hold Option + arrows to adjust the second corner (orange marker)
5. **Apply**: Press Enter to resize the focused window to the selection
6. **Cancel**: Press Escape to close the overlay without changes
7. **Cycle Grid Size**: Press Space to cycle through grid presets

## Keyboard Shortcuts

### Global
| Key | Action |
|-----|--------|
| `Control+Option+G` | Toggle grid overlay (primary, customizable) |
| `Command+Return` | Toggle grid overlay (secondary, customizable) |

### In Overlay
| Key | Action |
|-----|--------|
| `Arrow keys` / `H/J/K/L` | Pan selection (move entire selection) |
| `Shift + Arrow keys` / `Shift + H/J/K/L` | Move first corner (green marker) |
| `Option + Arrow keys` / `Option + H/J/K/L` | Move second corner (orange marker) |
| `Enter` | Apply selection and resize window |
| `Escape` | Cancel and close overlay |
| `Space` | Cycle through grid sizes |
| `Tab` | Switch to next monitor |
| `Shift + Tab` | Switch to previous monitor |

### Mouse Controls
| Action | Result |
|--------|--------|
| Click and drag | Select a region from start to end cell |
| Click inside selection | Confirm and apply the current selection |
| Click outside selection | Select the single cell at click position |

## Multi-Monitor Support

MacTile fully supports multi-monitor setups:

- **Automatic Detection**: When you open the overlay, it appears on the monitor containing the focused window
- **Keyboard Switching**: Press `Tab` to move the overlay to the next monitor, `Shift+Tab` for previous
- **Mouse Switching**: When the overlay is open, moving your mouse significantly (50+ pixels) on another monitor will automatically switch the overlay to that monitor
- **Monitor Indicator**: Shows "Monitor X/Y" in the overlay when multiple monitors are connected (can be disabled in settings)

## Settings

Access Settings from the menu bar icon. You can configure:

### General
- **Grid Sizes**: Comma-separated list of grid presets (e.g., "8x2, 6x4, 4x4, 3x3, 2x2")
- **Window Spacing**: Gap between tiled windows (0-50 pixels)
- **Screen Insets**: Margins from screen edges (top, left, bottom, right)

### Behavior
- **Auto-Close Overlay**: Whether to close overlay after applying resize
- **Show Menu Bar Icon**: Toggle menu bar visibility
- **Launch at Login**: Start MacTile when you log in
- **Click Without Drag Confirms**: When enabled, clicking inside the selection confirms it

### Overlay Display
- **Show Help Text**: Display keyboard shortcut hints at the top of the overlay
- **Show Monitor Indicator**: Display current monitor number when multiple monitors are connected

### Shortcuts
- **Primary Shortcut**: Main hotkey to toggle the overlay (default: Control+Option+G)
- **Secondary Shortcut**: Alternative hotkey (default: Command+Return)

### Appearance
- **Overlay Background**: Background color and opacity
- **Grid Lines**: Color, opacity, and width
- **Selection**: Fill color, opacity, border color, and border width
- **Corner Markers**: Colors for anchor (first corner) and target (second corner) markers

## Building from Source

See [BUILD.md](BUILD.md) for detailed build instructions.

```bash
# Quick start
cd MacTile
swift build
swift run MacTile

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
  - `Settings.swift`: MacTileSettings, KeyboardShortcut, AppearanceSettings configuration
  - `WindowManagement.swift`: WindowManagerProtocol and WindowTiler

- **MacTile**: Main application
  - `AppDelegate.swift`: Application lifecycle, menu bar, and hotkey setup
  - `OverlayWindowController.swift`: Grid overlay UI, keyboard/mouse handling, multi-monitor support
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
