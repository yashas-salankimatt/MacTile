# MacTile

A macOS window tiling application inspired by [gTile](https://github.com/gTile/gTile) for GNOME. MacTile allows you to tile windows using a configurable grid system with keyboard and mouse navigation.

## Features

- **Configurable Grid**: Multiple grid presets (8x2, 6x4, 4x4, 3x3, 2x2) with customizable sizes
- **Three Selection Modes**: Pan entire selection, adjust first corner, or adjust second corner
- **Keyboard Navigation**: Use arrow keys or vim bindings (H/J/K/L)
- **Mouse Support**: Click and drag to select grid regions, click inside selection to confirm
- **Multi-Monitor Support**: Switch overlay between monitors with Tab or mouse movement
- **Dual Global Hotkeys**: Primary (`Control+Option+G`) and secondary (`Command+Return`) shortcuts
- **Tiling Presets**: Quick keyboard shortcuts to tile windows to predefined positions with cycling support
- **Focus Presets**: Keyboard shortcuts to quickly focus applications and cycle through their windows
- **Virtual Spaces**: Save and restore window arrangements with 10 slots, configurable as shared across monitors or per-monitor
- **Workspace Management**: View and remove saved windows from virtual workspaces via an in-overlay panel
- **Customizable Appearance**: Configure colors, opacity, and visual elements
- **Settings Window**: Modern dark vibrancy sidebar navigation for configuring all options
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
| Overlay shortcut (press while overlay is open) | Open workspace management panel |
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

## Tiling Presets

Tiling presets allow you to quickly tile windows to predefined screen positions using keyboard shortcuts. Configure them in Settings > Presets.

### Default Presets

MacTile includes the following default presets (press while the overlay is open):

| Key | Action | Cycle Positions |
|-----|--------|-----------------|
| `R` | Right side | Right half → Right third → Right quarter |
| `E` | Left side | Left half → Left third → Left quarter |
| `F` | Full screen | Full screen |
| `C` | Center | Center third → Center half |

### Features

- **Proportional Positioning**: Define positions as screen proportions (0.0-1.0), so presets work on any screen size
- **Position Cycling**: Define multiple positions for a single key and cycle through them by pressing repeatedly
- **Per-Window Cycling**: Cycle state resets when switching to a different window
- **Configurable Timeout**: Set how long to wait before resetting the cycle (default: 2 seconds)
- **Modifier Support**: Combine with Control, Option, Shift, or Command modifiers
- **Auto-Confirm**: Optionally apply the preset immediately without pressing Enter

### Custom Preset Examples

| Preset | Positions | Description |
|--------|-----------|-------------|
| `T` | (0,0)→(1,0.5) | Top half of screen |
| `B` | (0,0.5)→(1,1) | Bottom half of screen |
| `⌃1` | (0,0)→(0.5,0.5) | Top-left quarter |
| `⌃2` | (0.5,0)→(1,0.5) | Top-right quarter |
| `⌃3` | (0,0.5)→(0.5,1) | Bottom-left quarter |
| `⌃4` | (0.5,0.5)→(1,1) | Bottom-right quarter |

### How Cycling Works

When you define multiple positions for a preset:
1. First press: Tiles to position 1
2. Second press (within timeout): Tiles to position 2
3. Third press: Tiles to position 3, then wraps to position 1
4. If you switch windows or wait longer than the timeout, the cycle resets

## Focus Presets

Focus presets allow you to quickly switch to specific applications and cycle through their windows. Configure them in Settings > Focus.

### Features

- **Quick App Switching**: Jump to any application with a single keyboard shortcut
- **Window Cycling**: If the app is already focused, cycle through all its windows
- **Open If Not Running**: Optionally launch the target app if it's not already running
- **Multi-Window Support**: Properly cycles through 3 or more windows (not just alternating between 2)
- **Multi-Monitor Support**: Works with windows spread across multiple monitors
- **Flexible Activation**: Configure whether presets work globally, in the overlay, or both

### How It Works

1. **App Not Running**: If "Open" is enabled, the app is launched
2. **App Not Focused**: Pressing the shortcut activates the target application
3. **App Already Focused**: Pressing again cycles to the next window of that application
4. **In Overlay**: If configured, the shortcut works while the tiling overlay is open

### Configuration Options

| Option | Description |
|--------|-------------|
| **Shortcut** | The keyboard shortcut (with optional modifiers) |
| **Application** | The target application to focus |
| **Global** | Enable to use as a global hotkey (works without overlay) |
| **Overlay** | Enable to use while the tiling overlay is open |
| **Open** | Launch the app if it's not already running |

### Example Setup

| Shortcut | Application | Use Case |
|----------|-------------|----------|
| `⌃⌥T` | Terminal | Quick access to terminal windows |
| `⌃⌥B` | Browser | Jump to browser and cycle tabs/windows |
| `⌃⌥S` | Slack | Quick access to Slack |
| `⌃⌥C` | VS Code | Jump to your editor |

## Virtual Spaces

Virtual Spaces allow you to save and restore window arrangements as multi-monitor workspace snapshots. Each space number (0-9) can store layouts for any monitors that were connected when the space was saved.

### Features

- **10 Space Slots (0-9)**: Use them as shared multi-monitor workspaces or independent per-monitor spaces
- **Save Window Arrangements**: Capture the positions, sizes, and stacking order of visible windows
- **Restore with Z-Order**: Windows are restored to their exact positions with correct stacking order
- **Focus History**: After restore, Alt+Tab order matches the saved z-order (topmost window focused first)
- **Visibility Filtering**: Only saves windows that are at least 40% visible (hidden windows are excluded)
- **Menu Bar Indicator**: Shows the active space number and name in the menu bar
- **Persistent Storage**: Virtual spaces are saved and persist across app restarts

### Keyboard Shortcuts

Default keyboard shortcuts (modifier keys can be customized in Settings > Spaces):

| Key | Action |
|-----|--------|
| `Control+Option+Shift+0-9` | Save current windows to virtual space 0-9 |
| `Control+Option+0-9` | Restore windows from virtual space 0-9 |
| `Control+Option+Comma` | Rename the currently active virtual space |

### How It Works

1. **Choose Mode**: In Settings → Spaces, enable or disable **Share Across Monitors**.
   - On: each space number is a shared multi-monitor snapshot
   - Off: each monitor has independent spaces for each number

2. **Saving a Space**: Press `Control+Option+Shift+0` (or 1-9).
   - Shared mode: saves all currently connected monitors into that slot, preserving saved layouts for disconnected monitors
   - Per-monitor mode: saves only the current monitor’s slot

3. **Restoring a Space**: Press `Control+Option+0` (or 1-9).
   - Shared mode: restores saved layouts only for currently connected monitors
   - Per-monitor mode: restores only the current monitor’s slot

4. **Active State**: A virtual space is "active" after being saved or restored. It becomes "inactive" when:
   - A window not in that space gains focus
   - A window in that space gets resized or moved

5. **Naming Spaces**: Press `Control+Option+Comma` when a space is active to give it a custom name (e.g., "Development", "Communication").
   - Shared mode renames the slot across all monitor entries
   - Per-monitor mode renames only the current monitor’s slot

### Multi-Monitor Support

Virtual spaces support mixed monitor configurations:
- Saving with one monitor stores that monitor’s layout for the space slot
- In shared mode, saving with multiple monitors updates connected monitor layouts in the same slot
- Restoring always applies only to monitors that are currently connected
- Layouts for disconnected monitors remain stored and are not deleted

### Visibility Filtering

When saving a virtual space, MacTile only captures windows that are meaningfully visible:
- Windows must be at least 40% visible (not mostly covered by other windows)
- This prevents saving windows that are completely hidden behind others
- Uses grid-based occlusion detection for accurate visibility calculation

### Example Workflow

1. Arrange your windows for a coding session (editor, terminal, browser)
2. Press `Control+Option+Shift+1` to save as Space 1
3. Press `Control+Option+Comma` and name it "Development"
4. Rearrange windows for communication (Slack, email, calendar)
5. Press `Control+Option+Shift+2` to save as Space 2
6. Name it "Communication"
7. Now switch between setups instantly with `Control+Option+1` and `Control+Option+2`

## Workspace Management

When the overlay is open, press your overlay shortcut again (for example `Control+Option+G` twice) to open the workspace management panel. This lets you browse and edit your saved virtual workspaces.

### Features

- **Browse Workspaces**: See all non-empty virtual workspaces with their saved windows
- **Keyboard Navigation**: Use arrow keys or J/K to move between workspaces and windows
- **Remove Windows**: Press Backspace, Delete, or X to remove a window from a workspace
- **Native Appearance**: Floating HUD panel with macOS blur effect

### Keyboard Shortcuts (in management panel)

| Key | Action |
|-----|--------|
| `↑` / `K` | Move to previous item |
| `↓` / `J` | Move to next item |
| `Backspace` / `Delete` / `X` | Remove selected window from workspace |
| `Escape` | Close panel and return to previous window |

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

### Presets (Tiling)
- **Add Preset**: Create keyboard shortcuts for quick window tiling
- **Shortcut**: Record a key combination (with optional modifiers)
- **Positions**: Define one or more screen positions as proportional coordinates
- **Add Position**: Add additional positions for cycling behavior
- **Cycle Timeout**: Time in milliseconds before cycle resets (500-10000ms)
- **Auto-Confirm**: Apply preset immediately without pressing Enter

### Focus
- **Add Preset**: Create keyboard shortcuts for app focus switching
- **Shortcut**: Record a key combination (with optional modifiers)
- **Application**: Select from running applications (list refreshes on click)
- **Global**: Enable global hotkey functionality (works without overlay)
- **Overlay**: Enable use during tiling overlay
- **Open**: Launch the application if it's not already running

### Spaces (Virtual Spaces)
- **Enable Virtual Spaces**: Toggle the entire virtual spaces feature on/off
- **Share Across Monitors**: Choose shared multi-monitor spaces or per-monitor spaces
- **Save Modifiers**: Customize the modifier keys for saving (default: Control+Option+Shift)
- **Restore Modifiers**: Customize the modifier keys for restoring (default: Control+Option)
- Press modifier keys + Space to record new modifiers

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
  - `Grid.swift`: GridSize, GridOffset, GridSelection, GridOperations, and VisibilityCalculator
  - `Settings.swift`: MacTileSettings, KeyboardShortcut, TilingPreset, FocusPreset, AppearanceSettings, VirtualSpace, VirtualSpacesStorage
  - `WindowManagement.swift`: WindowManagerProtocol and WindowTiler

- **MacTile**: Main application
  - `AppDelegate.swift`: Application lifecycle, menu bar, global hotkey setup (including focus presets and virtual spaces)
  - `OverlayWindowController.swift`: Grid overlay UI, keyboard/mouse handling, multi-monitor support, tiling presets
  - `SettingsWindowController.swift`: Settings window UI with tabs for all configuration options
  - `SettingsManager.swift`: UserDefaults persistence for all settings
  - `WindowManager.swift`: Accessibility API integration for window manipulation
  - `FocusManager.swift`: Application focus switching and window cycling via Accessibility API
  - `VirtualSpaceManager.swift`: Virtual spaces for saving/restoring multi-monitor window arrangements
  - `VirtualSpaceManageOverlay.swift`: Floating panel for browsing and editing saved workspace contents

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
- Virtual spaces (storage, encoding/decoding, z-order preservation)
- Visibility calculator (occlusion detection, threshold filtering)

## License

MIT License - See LICENSE file for details

## Credits

Inspired by [gTile](https://github.com/gTile/gTile) for GNOME Shell.
