# Changelog

All notable changes to MacTile will be documented in this file.

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
