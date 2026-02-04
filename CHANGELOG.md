# Changelog

All notable changes to MacTile will be documented in this file.

## [1.1.0] - 2026-02-03

### Added

- **Virtual Spaces**: Save and restore window arrangements per monitor
  - 10 virtual spaces (0-9) per monitor for organizing different workflows
  - Save current window positions with customizable modifier keys + number
  - Restore windows to saved positions with correct z-order (stacking)
  - Rename spaces for easy identification (shown in menu bar)
  - Only saves windows that are at least 40% visible (filters hidden windows)
  - Persistent storage - spaces survive app restarts

- **Virtual Spaces Settings Tab**: Full configuration in Settings > Spaces
  - Enable/disable virtual spaces feature
  - Customizable save modifiers (default: Control+Option+Shift)
  - Customizable restore modifiers (default: Control+Option)
  - Record new modifiers by pressing modifier keys + Space

- **Default Tiling Presets**: Quick window tiling without configuration
  - `R` - Right side (cycles: half → third → quarter)
  - `E` - Left side (cycles: half → third → quarter)
  - `F` - Full screen
  - `C` - Center (cycles: third → half)
  - All presets auto-confirm and have no modifiers (work in overlay)

- **Per-Tab Reset Buttons**: Reset individual settings tabs to defaults
  - Each tab (General, Shortcuts, Appearance, Presets, Focus, Spaces) has its own reset button
  - Replaces the global reset button for more granular control

### Fixed

- **Cancel Button Now Discards Changes**: Settings window properly reloads saved values when reopened after canceling
- **Event Monitor Cleanup**: Recording keyboard shortcuts no longer leaks event monitors when the settings window is closed
- **Virtual Spaces Disable**: Disabling virtual spaces now fully stops all background monitoring

### Improved

- **Test Suite**: Comprehensive tests now validate actual production code paths
  - ResizeStateChecker extracted to MacTileCore and used by WindowManager
  - Z-order sorting uses shared comparators between tests and production
  - 135 tests covering grid operations, window management, virtual spaces, and settings

## [1.0.5] - 2026-01-25

### Fixed

- **Finder Window Cycling**: Fixed focus preset not cycling through Finder windows
  - Finder's Desktop was being included in the window list, preventing proper cycling
  - Now filters to only include windows with a close button, excluding the Desktop

## [1.0.4] - 2026-01-24

### Added

- **Open If Not Running**: Focus presets can now optionally launch the target app if it's not already running
  - New "Open" checkbox in Focus Presets settings for each preset
  - When enabled, using the focus shortcut will launch the app if no instance is running

### Fixed

- **Cross-Monitor Window Movement**: Fixed windows getting stuck between monitors when tiling
  - Windows now properly move across monitor boundaries using a shrink-move-resize strategy
  - Resolves issue where large windows would get trapped at monitor edges

- **Focus Presets App Dropdown**: Application list now refreshes when clicking the dropdown
  - Previously, apps opened after MacTile wouldn't appear in the list
  - The dropdown now shows all currently running applications in real-time

## [1.0.3] - 2026-01-24

### Fixed

- Tiling presets now correctly calculate grid positions using rounding instead of truncation
  - Previously, a center third preset (0.34,0)→(0.65,1) on a 12x4 grid would select 3 columns instead of 4
  - The fix ensures proportional coordinates map accurately to grid cells

## [1.0.2] - 2026-01-24

### Added

- **Focus Presets**: New feature to quickly switch to specific applications and cycle through their windows
  - Configure keyboard shortcuts for any application in Settings > Focus
  - Cycle through all windows of the same app (supports 3+ windows)
  - Works across multiple monitors
  - Presets can work globally, in the overlay, or both

- **Tiling Presets**: Quick keyboard shortcuts to tile windows to predefined positions
  - Define positions as proportional screen coordinates (0.0-1.0)
  - Support for cycling through multiple positions with the same key
  - Per-window cycle tracking (resets when switching windows)
  - Configurable cycle timeout (500-10000ms)
  - Optional auto-confirm to apply immediately

- **Settings UI Improvements**
  - New Focus tab for configuring focus presets
  - New Presets tab for configuring tiling presets
  - Application picker for focus presets with running apps dropdown

### Fixed

- Window cycling now properly cycles through all windows (3+), not just alternating between 2
- Focus presets now work correctly when activated from the overlay
- Proper focus return after window cycling from overlay

## [1.0.1] - 2026-01-22

### Added

- Multi-monitor support with automatic detection
- Keyboard switching between monitors (Tab/Shift+Tab)
- Mouse-based monitor switching with movement threshold
- Monitor indicator display (configurable)
- Option to hide help text in overlay

### Fixed

- Overlay toggle now returns focus to original window when cancelled
- Multi-monitor coordinate conversion improvements
- Various overlay behavior improvements

## [1.0.0] - 2026-01-20

### Added

- Initial release
- Configurable grid system (8x2, 6x4, 4x4, 3x3, 2x2)
- Three selection modes: pan, anchor, target
- Keyboard navigation with arrow keys and vim bindings (H/J/K/L)
- Mouse support for click and drag selection
- Dual global hotkeys (Control+Option+G and Command+Return)
- Customizable appearance (colors, opacity, line width)
- Settings window with full configuration options
- Menu bar app with no dock icon
- Launch at login support
- Window spacing and screen insets
