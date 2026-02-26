# Changelog

All notable changes to MacTile will be documented in this file.

## [1.4.2] - 2026-02-25

### Added

- **Per-Monitor Sketchybar Auto-Adjustment**: When sketchybar integration is enabled, MacTile now automatically queries sketchybar for its bar height and adjusts the overlay grid and window tiling per-monitor. Built-in displays (with notch) get minimal extra padding, while external displays get the full bar height offset — no manual inset configuration needed.

### Fixed

- **Overlay Grid Respects User Insets**: The overlay grid now properly accounts for user-configured insets (e.g. for custom bars), so the grid visually matches the actual tiling area instead of drawing over reserved regions
- **Overlay UI Label Positioning**: Grid size indicator, monitor indicator, selection info, and help text are now positioned within the grid bounds, respecting all safe area insets
- **Negative Inset Protection**: EdgeInsets now clamps all values to non-negative, preventing invalid configurations from causing windows to tile off-screen

### Improved

- **Shared Sketchybar Binary Detection**: Sketchybar executable path detection is now shared between the event notification system and bar info querying, eliminating duplicated code

## [1.4.1] - 2026-02-25

### Fixed

- **Settings Apply Performance**: Settings are now saved in a single atomic update instead of 15+ individual writes, eliminating redundant hotkey re-registration and intermediate state flicker
- **Memory Leak in Preset Rows**: Fixed retain cycle in tiling preset delete handler that prevented row views from being deallocated
- **Event Monitor Cleanup**: Recording keyboard shortcuts in preset/focus rows now properly cancels on row deletion, reset, and window close — prevents leaked NSEvent monitors
- **Overlay Modifier Apply/Cancel Consistency**: Overlay virtual space modifier changes now only persist when clicking Apply (previously saved immediately during recording)
- **Reset Confirmation Dialogs**: All per-tab reset buttons now show a confirmation dialog before reverting to defaults
- **Safe Screen Access**: Replaced unsafe `NSScreen.screens[0]` with safe `.first` access throughout, preventing potential crashes on headless/disconnected displays
- **Settings Corruption Alert**: If stored settings fail to decode, the user now sees an alert instead of silently falling back to defaults
- **Async Window Tiling**: Window frame operations in the overlay are now dispatched off the main thread, preventing brief UI freezes during tiling

### Improved

- **Settings Window Layout**: Removed misaligned card backgrounds from all settings tabs for a cleaner appearance
- **Spaces Tab Scrolling**: Spaces tab content is now in a scroll view, ensuring all settings and usage instructions are accessible
- **Presets Tab Layout**: Help text and buttons no longer overlap; coordinates field is wider to show full cycle position strings
- **Scroll View Resizing**: Settings scroll views now properly resize when the window dimensions change

## [1.4.0] - 2026-02-18

### Added

- **Virtual Spaces Mode Toggle**: Added a new Spaces setting to choose between shared multi-monitor virtual spaces and per-monitor virtual spaces.

### Changed

- **Workspace Management Trigger**: Changed the management panel trigger while overlay is open from `Enter` to pressing the overlay shortcut a second time.
- **Shared-Slot Behavior Consistency**: In shared mode, clear and rename now apply to all monitor entries in that virtual space number.

### Fixed

- **Multi-Monitor Save/Restore Robustness**: Saving and restoring virtual spaces now correctly handles connected monitor sets and preserves layouts for disconnected monitors.
- **Mixed Monitor Topologies**: Restoring with fewer connected monitors now restores only connected layouts without deleting other saved monitor layouts.
- **Active Space Tracking in Shared Mode**: Shared save/restore now marks all restored/saved monitor entries active, fixing stale active state handling.

## [1.3.0] - 2026-02-16

### Added

- **Virtual Workspace Management Overlay**: View and manage saved virtual workspace contents directly from the overlay
  - Press Enter without modifying the grid selection to open the management panel
  - Browse all non-empty workspaces with their saved windows listed per workspace
  - Navigate with arrow keys or vim bindings (J/K) between workspaces and individual windows
  - Remove individual windows from a workspace with Backspace/Delete or `X`
  - Native macOS blur panel with floating HUD appearance
  - Automatically returns focus to the previously active window on dismiss

### Improved

- **Redesigned Settings Window**: Modern dark vibrancy sidebar navigation replaces the previous tab-based layout
  - SF Symbols icons for each settings section (General, Shortcuts, Appearance, Presets, Focus, Spaces, About)
  - Transparent titlebar with full-size content view
  - Animated sidebar highlight transitions between sections
  - Wider window layout (780px) for better content spacing

- **Event Monitor Cleanup**: Fixed potential leaks for clear modifier and overlay save/clear modifier monitors when the settings window is closed

## [1.2.0] - 2026-02-05

### Added

- **Sketchybar Integration**: Display virtual space indicators in your menu bar
  - Automatic setup when enabled: deploys plugin scripts, helpers, and fonts
  - Triggers `mactile_space_change` event with environment variables for each space action
  - Supports custom sketchybar commands for advanced users
  - Bundled resources: `mactile.sh`, `mactile_click.sh`, `mactile_space_name.sh`, `icon_map.sh`
  - Automatically installs `sketchybar-app-font.ttf` for app icon ligatures
  - IPC support via distributed notifications for restore/clear from sketchybar

- **Configurable Overlay Modifiers**: Separate modifier keys for save/clear in overlay
  - Save modifier (default: Shift) - hold while pressing number to save
  - Clear modifier (default: Control) - hold while pressing number to clear
  - Configurable in Settings → Virtual Spaces

### Improved

- **Sketchybar Service Management**: Properly stops sketchybar when integration is disabled
  - Enable: restarts sketchybar to load MacTile configuration
  - Disable: stops sketchybar via `brew services stop`

- **Space Clear Events**: Now passes complete space information to sketchybar when clearing

## [1.1.2] - 2026-02-04

### Fixed

- **Reliable Window Matching for Multi-Window Apps**: Fixed virtual space restore failing for apps like Zen browser with multiple windows
  - Now uses private `_AXUIElementGetWindow` API for direct window ID matching
  - Falls back to frame-based heuristics when private API unavailable
  - Eliminates ambiguity when multiple windows have similar frames

- **Focus Restoration from Overlay**: Fixed focus not returning correctly after save/restore
  - Save: Returns focus to the window that triggered the overlay
  - Restore: Returns focus to a window in the restored virtual space
  - Properly handles overlay dismissal timing to prevent focus race conditions

### Improved

- **Window Matching Strategy**: More robust multi-strategy approach
  1. Direct window ID via private API (most reliable)
  2. AXWindowNumber attributes (when exposed by apps)
  3. Frame-based matching with tolerance (fallback)
  - Only matches when confident; returns nil for safety when ambiguous

## [1.1.1] - 2026-02-04

### Added

- **Virtual Space Overlay Triggers**: Save and restore virtual spaces directly from the overlay
  - Number keys (0-9) restore virtual spaces
  - Shift+number saves current windows to a virtual space
  - Auto-closes overlay after save/restore

- **Auto-Activate Matching Layouts**: Virtual spaces automatically activate when window layout matches
  - Detects when you return to a saved window arrangement
  - Updates menu bar indicator without manual trigger
  - Uses window IDs for reliable matching

### Fixed

- **Focus Presets for Always-Running Apps**: Fixed Finder and other system apps not opening new windows
  - "Open if not running" now correctly opens a new window when app has no windows
  - Works on first keypress instead of requiring two presses

- **Virtual Space Window Restoration**: Fixed full-screen windows requiring two triggers to restore
  - Now uses shared window frame logic with proper retry and delay handling
  - Consistent behavior with overlay tiling

- **Virtual Space Rename**: Fixed rename not persisting in release builds
  - Rename now works by space number rather than requiring active state

- **Layout Detection Timing**: Fixed layout matching requiring extra alt-tab
  - Observer now stays active even when no space is active
  - Added 100ms delay to let window state settle
  - Guaranteed retry if check is throttled

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
