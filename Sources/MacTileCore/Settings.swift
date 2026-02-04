import Foundation
import CoreGraphics

// MARK: - Keyboard Shortcut

/// Represents a keyboard shortcut with modifiers
public struct KeyboardShortcut: Equatable, Codable {
    public let keyCode: UInt16
    public let modifiers: UInt
    public let keyString: String  // Human-readable key (e.g., "G", "Return")

    public init(keyCode: UInt16, modifiers: UInt, keyString: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyString = keyString
    }

    /// Common modifier flags
    public struct Modifiers {
        public static let none: UInt = 0
        public static let control: UInt = 1 << 0
        public static let option: UInt = 1 << 1
        public static let shift: UInt = 1 << 2
        public static let command: UInt = 1 << 3
    }

    /// Returns a human-readable description of the shortcut
    public var displayString: String {
        var parts: [String] = []
        if modifiers & Modifiers.control != 0 { parts.append("⌃") }
        if modifiers & Modifiers.option != 0 { parts.append("⌥") }
        if modifiers & Modifiers.shift != 0 { parts.append("⇧") }
        if modifiers & Modifiers.command != 0 { parts.append("⌘") }
        parts.append(keyString)
        return parts.joined()
    }

    // Default shortcuts
    public static let defaultToggleOverlay = KeyboardShortcut(
        keyCode: 5, // G key
        modifiers: Modifiers.control | Modifiers.option,
        keyString: "G"
    )

    // Secondary default: Command + Enter
    public static let defaultSecondaryToggleOverlay = KeyboardShortcut(
        keyCode: 36, // Return key
        modifiers: Modifiers.command,
        keyString: "Return"
    )
}

// MARK: - Color Settings

/// RGB color representation for settings
public struct SettingsColor: Equatable, Codable {
    public var red: CGFloat
    public var green: CGFloat
    public var blue: CGFloat
    public var alpha: CGFloat

    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.red = max(0, min(1, red))
        self.green = max(0, min(1, green))
        self.blue = max(0, min(1, blue))
        self.alpha = max(0, min(1, alpha))
    }

    // Preset colors
    public static let black = SettingsColor(red: 0, green: 0, blue: 0, alpha: 1)
    public static let white = SettingsColor(red: 1, green: 1, blue: 1, alpha: 1)
    public static let blue = SettingsColor(red: 0, green: 0.478, blue: 1, alpha: 1) // System blue
    public static let green = SettingsColor(red: 0.204, green: 0.780, blue: 0.349, alpha: 1) // System green
    public static let orange = SettingsColor(red: 1, green: 0.584, blue: 0, alpha: 1) // System orange
}

// MARK: - Appearance Settings

/// Visual appearance settings for the overlay
public struct AppearanceSettings: Equatable, Codable {
    // Overlay background
    public var overlayBackgroundColor: SettingsColor
    public var overlayOpacity: CGFloat

    // Grid lines
    public var gridLineColor: SettingsColor
    public var gridLineOpacity: CGFloat
    public var gridLineWidth: CGFloat

    // Selection
    public var selectionFillColor: SettingsColor
    public var selectionFillOpacity: CGFloat
    public var selectionBorderColor: SettingsColor
    public var selectionBorderWidth: CGFloat

    // Corner markers
    public var anchorMarkerColor: SettingsColor  // First corner
    public var targetMarkerColor: SettingsColor  // Second corner

    public static let `default` = AppearanceSettings(
        overlayBackgroundColor: .black,
        overlayOpacity: 0.4,
        gridLineColor: .white,
        gridLineOpacity: 0.3,
        gridLineWidth: 1.0,
        selectionFillColor: .blue,
        selectionFillOpacity: 0.4,
        selectionBorderColor: .blue,
        selectionBorderWidth: 3.0,
        anchorMarkerColor: .green,
        targetMarkerColor: .orange
    )

    public init(
        overlayBackgroundColor: SettingsColor,
        overlayOpacity: CGFloat,
        gridLineColor: SettingsColor,
        gridLineOpacity: CGFloat,
        gridLineWidth: CGFloat,
        selectionFillColor: SettingsColor,
        selectionFillOpacity: CGFloat,
        selectionBorderColor: SettingsColor,
        selectionBorderWidth: CGFloat,
        anchorMarkerColor: SettingsColor,
        targetMarkerColor: SettingsColor
    ) {
        self.overlayBackgroundColor = overlayBackgroundColor
        self.overlayOpacity = max(0, min(1, overlayOpacity))
        self.gridLineColor = gridLineColor
        self.gridLineOpacity = max(0, min(1, gridLineOpacity))
        self.gridLineWidth = max(0.5, min(5, gridLineWidth))
        self.selectionFillColor = selectionFillColor
        self.selectionFillOpacity = max(0, min(1, selectionFillOpacity))
        self.selectionBorderColor = selectionBorderColor
        self.selectionBorderWidth = max(1, min(10, selectionBorderWidth))
        self.anchorMarkerColor = anchorMarkerColor
        self.targetMarkerColor = targetMarkerColor
    }
}

// MARK: - Overlay Keyboard Settings

/// Keyboard configuration for the overlay
public struct OverlayKeyboardSettings: Equatable, Codable {
    // Modifier for pan mode (move entire selection)
    public var panModifier: UInt
    // Modifier for moving first corner (anchor)
    public var anchorModifier: UInt
    // Modifier for moving second corner (target)
    public var targetModifier: UInt

    // Key codes for actions
    public var applyKeyCode: UInt16      // Default: Enter (36)
    public var cancelKeyCode: UInt16     // Default: Escape (53)
    public var cycleGridKeyCode: UInt16  // Default: Space (49)

    public static let `default` = OverlayKeyboardSettings(
        panModifier: KeyboardShortcut.Modifiers.none,
        anchorModifier: KeyboardShortcut.Modifiers.shift,
        targetModifier: KeyboardShortcut.Modifiers.option,
        applyKeyCode: 36,   // Enter
        cancelKeyCode: 53,  // Escape
        cycleGridKeyCode: 49 // Space
    )

    public init(
        panModifier: UInt,
        anchorModifier: UInt,
        targetModifier: UInt,
        applyKeyCode: UInt16,
        cancelKeyCode: UInt16,
        cycleGridKeyCode: UInt16
    ) {
        self.panModifier = panModifier
        self.anchorModifier = anchorModifier
        self.targetModifier = targetModifier
        self.applyKeyCode = applyKeyCode
        self.cancelKeyCode = cancelKeyCode
        self.cycleGridKeyCode = cycleGridKeyCode
    }

    /// Get display string for a modifier
    public static func modifierDisplayString(_ modifier: UInt) -> String {
        if modifier == KeyboardShortcut.Modifiers.none { return "None" }
        var parts: [String] = []
        if modifier & KeyboardShortcut.Modifiers.control != 0 { parts.append("⌃") }
        if modifier & KeyboardShortcut.Modifiers.option != 0 { parts.append("⌥") }
        if modifier & KeyboardShortcut.Modifiers.shift != 0 { parts.append("⇧") }
        if modifier & KeyboardShortcut.Modifiers.command != 0 { parts.append("⌘") }
        return parts.joined()
    }

    /// Get display string for a key code
    public static func keyCodeDisplayString(_ keyCode: UInt16) -> String {
        let keyMap: [UInt16: String] = [
            36: "Enter", 53: "Escape", 49: "Space", 48: "Tab", 51: "Delete",
            123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return keyMap[keyCode] ?? "Key \(keyCode)"
    }
}

// MARK: - Preset Position

/// A single position configuration for a tiling preset
public struct PresetPosition: Codable, Equatable {
    /// Start X coordinate as proportion (0.0 to 1.0, where 0 = left edge)
    public var startX: CGFloat
    /// Start Y coordinate as proportion (0.0 to 1.0, where 0 = top edge)
    public var startY: CGFloat
    /// End X coordinate as proportion (0.0 to 1.0, where 1 = right edge)
    public var endX: CGFloat
    /// End Y coordinate as proportion (0.0 to 1.0, where 1 = bottom edge)
    public var endY: CGFloat

    public init(startX: CGFloat, startY: CGFloat, endX: CGFloat, endY: CGFloat) {
        self.startX = max(0, min(1, startX))
        self.startY = max(0, min(1, startY))
        self.endX = max(0, min(1, endX))
        self.endY = max(0, min(1, endY))
    }

    /// Display string for the coordinates
    public var coordinateString: String {
        return String(format: "(%.2f,%.2f);(%.2f,%.2f)", startX, startY, endX, endY)
    }

    /// Convert proportional coordinates to a grid selection
    public func toGridSelection(gridSize: GridSize) -> GridSelection {
        // Normalize so start <= end
        let x1 = min(startX, endX)
        let y1 = min(startY, endY)
        let x2 = max(startX, endX)
        let y2 = max(startY, endY)

        // Calculate the size in grid units using rounding for accuracy
        // This ensures that 1/3 of 12 columns = 4, not 3
        let widthProportion = x2 - x1
        let heightProportion = y2 - y1

        let gridWidth = max(1, Int(round(widthProportion * CGFloat(gridSize.cols))))
        let gridHeight = max(1, Int(round(heightProportion * CGFloat(gridSize.rows))))

        // Calculate starting position by rounding the start coordinates
        // and then clamping to ensure the selection fits within bounds
        let startCol = Int(round(x1 * CGFloat(gridSize.cols)))
        let startRow = Int(round(y1 * CGFloat(gridSize.rows)))

        // Clamp to grid bounds
        let clampedStartCol = max(0, min(gridSize.cols - gridWidth, startCol))
        let clampedStartRow = max(0, min(gridSize.rows - gridHeight, startRow))

        let endCol = min(gridSize.cols - 1, clampedStartCol + gridWidth - 1)
        let endRow = min(gridSize.rows - 1, clampedStartRow + gridHeight - 1)

        return GridSelection(
            anchor: GridOffset(col: clampedStartCol, row: clampedStartRow),
            target: GridOffset(col: endCol, row: endRow)
        )
    }
}

// MARK: - Tiling Preset

/// A keyboard shortcut that tiles to proportional screen regions with cycling support
public struct TilingPreset: Codable, Equatable {
    /// The key code for this preset
    public var keyCode: UInt16
    /// Human-readable key name (e.g., "R", "1")
    public var keyString: String
    /// Modifier flags (control, option, shift, command)
    public var modifiers: UInt

    /// Array of positions to cycle through
    public var positions: [PresetPosition]

    /// If true, immediately apply the selection; if false, just select the area
    public var autoConfirm: Bool

    /// Timeout in milliseconds to wait for next keypress before resetting cycle
    public var cycleTimeout: Int

    public init(
        keyCode: UInt16,
        keyString: String,
        modifiers: UInt = KeyboardShortcut.Modifiers.none,
        positions: [PresetPosition],
        autoConfirm: Bool,
        cycleTimeout: Int = 2000
    ) {
        self.keyCode = keyCode
        self.keyString = keyString
        self.modifiers = modifiers
        self.positions = positions.isEmpty ? [PresetPosition(startX: 0, startY: 0, endX: 0.5, endY: 1)] : positions
        self.autoConfirm = autoConfirm
        self.cycleTimeout = max(500, min(10000, cycleTimeout))
    }

    /// Convenience initializer for single position (backwards compatibility)
    public init(
        keyCode: UInt16,
        keyString: String,
        modifiers: UInt = KeyboardShortcut.Modifiers.none,
        startX: CGFloat,
        startY: CGFloat,
        endX: CGFloat,
        endY: CGFloat,
        autoConfirm: Bool,
        cycleTimeout: Int = 2000
    ) {
        self.init(
            keyCode: keyCode,
            keyString: keyString,
            modifiers: modifiers,
            positions: [PresetPosition(startX: startX, startY: startY, endX: endX, endY: endY)],
            autoConfirm: autoConfirm,
            cycleTimeout: cycleTimeout
        )
    }

    /// Display string for the key combination (e.g., "⌃⌥R")
    public var shortcutDisplayString: String {
        var parts: [String] = []
        if modifiers & KeyboardShortcut.Modifiers.control != 0 { parts.append("⌃") }
        if modifiers & KeyboardShortcut.Modifiers.option != 0 { parts.append("⌥") }
        if modifiers & KeyboardShortcut.Modifiers.shift != 0 { parts.append("⇧") }
        if modifiers & KeyboardShortcut.Modifiers.command != 0 { parts.append("⌘") }
        parts.append(keyString)
        return parts.joined()
    }

    /// Display string for all positions (separated by " | ")
    public var coordinateString: String {
        return positions.map { $0.coordinateString }.joined(separator: " | ")
    }

    /// Parse multiple positions from string format "(x1,y1);(x2,y2) | (x1,y1);(x2,y2) | ..."
    public static func parsePositions(_ string: String) -> [PresetPosition] {
        let positionStrings = string.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
        return positionStrings.compactMap { parseCoordinates($0) }.map {
            PresetPosition(startX: $0.startX, startY: $0.startY, endX: $0.endX, endY: $0.endY)
        }
    }

    /// Parse coordinates from string format "(x1,y1);(x2,y2)"
    public static func parseCoordinates(_ string: String) -> (startX: CGFloat, startY: CGFloat, endX: CGFloat, endY: CGFloat)? {
        let cleaned = string.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")

        let parts = cleaned.split(separator: ";")
        guard parts.count == 2 else { return nil }

        let start = parts[0].split(separator: ",")
        let end = parts[1].split(separator: ",")

        guard start.count == 2, end.count == 2,
              let x1 = Double(start[0]), let y1 = Double(start[1]),
              let x2 = Double(end[0]), let y2 = Double(end[1]) else {
            return nil
        }

        return (CGFloat(x1), CGFloat(y1), CGFloat(x2), CGFloat(y2))
    }

    /// Get grid selection for a specific position index
    public func toGridSelection(gridSize: GridSize, positionIndex: Int = 0) -> GridSelection {
        let index = max(0, min(positions.count - 1, positionIndex))
        return positions[index].toGridSelection(gridSize: gridSize)
    }

    /// Number of cycle positions
    public var cycleCount: Int {
        return positions.count
    }

    /// Check if this preset matches the given key event
    public func matches(keyCode: UInt16, modifiers: UInt) -> Bool {
        return self.keyCode == keyCode && self.modifiers == modifiers
    }
}

// MARK: - Virtual Space Window

/// Represents a saved window in a virtual space
public struct VirtualSpaceWindow: Codable, Equatable {
    /// Bundle ID of the application
    public var appBundleID: String
    /// Window title (for identification)
    public var windowTitle: String
    /// Window frame in screen coordinates
    public var frame: CGRect
    /// Z-order index (0 = topmost/frontmost)
    public var zIndex: Int

    public init(
        appBundleID: String,
        windowTitle: String,
        frame: CGRect,
        zIndex: Int
    ) {
        self.appBundleID = appBundleID
        self.windowTitle = windowTitle
        self.frame = frame
        self.zIndex = zIndex
    }

    /// Comparison function for restore order (back to front).
    /// When restoring, we raise windows from back (high zIndex) to front (low zIndex)
    /// so the topmost window ends up on top.
    /// This is the canonical sorting logic used by VirtualSpaceManager.restoreWindows().
    public static func restoreOrderComparator(_ lhs: VirtualSpaceWindow, _ rhs: VirtualSpaceWindow) -> Bool {
        return lhs.zIndex > rhs.zIndex
    }

    /// Comparison function for z-order (front to back).
    /// zIndex 0 = topmost/frontmost, higher values = further back.
    public static func zOrderComparator(_ lhs: VirtualSpaceWindow, _ rhs: VirtualSpaceWindow) -> Bool {
        return lhs.zIndex < rhs.zIndex
    }
}

// MARK: - Virtual Space

/// Represents a single virtual space (a saved arrangement of windows)
public struct VirtualSpace: Codable, Equatable {
    /// The space number (0-9)
    public var number: Int
    /// Optional user-defined name
    public var name: String?
    /// Windows saved in this space
    public var windows: [VirtualSpaceWindow]
    /// Display ID of the monitor this space belongs to
    public var displayID: UInt32

    /// Human-readable display name for the space (shown in menubar)
    public var displayName: String {
        if let name = name, !name.isEmpty {
            return "\(number): \(name)"
        }
        return "\(number)"
    }

    /// Whether this space has any saved windows
    public var isEmpty: Bool {
        return windows.isEmpty
    }

    /// Returns windows sorted in the order they should be restored (back to front)
    /// When restoring, we raise windows from back to front so the final z-order is correct.
    /// Windows with higher zIndex (further back) should be restored first.
    /// Uses VirtualSpaceWindow.restoreOrderComparator - the same logic used by VirtualSpaceManager.
    public var windowsInRestoreOrder: [VirtualSpaceWindow] {
        return windows.sorted(by: VirtualSpaceWindow.restoreOrderComparator)
    }

    /// Returns windows sorted by z-order (front to back, zIndex 0 = topmost)
    /// Uses VirtualSpaceWindow.zOrderComparator.
    public var windowsByZOrder: [VirtualSpaceWindow] {
        return windows.sorted(by: VirtualSpaceWindow.zOrderComparator)
    }

    public init(
        number: Int,
        name: String? = nil,
        windows: [VirtualSpaceWindow] = [],
        displayID: UInt32
    ) {
        self.number = max(0, min(9, number))
        self.name = name
        self.windows = windows
        self.displayID = displayID
    }

    /// Create an empty space for a given number and display
    public static func empty(number: Int, displayID: UInt32) -> VirtualSpace {
        return VirtualSpace(number: number, displayID: displayID)
    }
}

// MARK: - Virtual Spaces Storage

/// Storage for all virtual spaces across monitors
/// Key is display ID (UInt32), value is dictionary of space number to VirtualSpace
public struct VirtualSpacesStorage: Codable, Equatable {
    /// Spaces by display ID, then by space number (0-9)
    public var spacesByMonitor: [String: [String: VirtualSpace]]

    public init() {
        self.spacesByMonitor = [:]
    }

    /// Get a virtual space for a monitor and space number
    public func getSpace(displayID: UInt32, number: Int) -> VirtualSpace? {
        let displayKey = String(displayID)
        let numberKey = String(number)
        return spacesByMonitor[displayKey]?[numberKey]
    }

    /// Set a virtual space for a monitor
    /// Uses space.number (which is clamped to 0-9) as the key to ensure consistency
    public mutating func setSpace(_ space: VirtualSpace, displayID: UInt32) {
        let displayKey = String(displayID)
        let numberKey = String(space.number)  // Use the clamped number from the space itself
        if spacesByMonitor[displayKey] == nil {
            spacesByMonitor[displayKey] = [:]
        }
        spacesByMonitor[displayKey]?[numberKey] = space
    }

    /// Get all spaces for a monitor (0-9)
    public func getSpaces(displayID: UInt32) -> [VirtualSpace] {
        let displayKey = String(displayID)
        guard let spaces = spacesByMonitor[displayKey] else { return [] }
        return (0...9).compactMap { spaces[String($0)] }
    }

    /// Get all non-empty spaces for a monitor
    public func getNonEmptySpaces(displayID: UInt32) -> [VirtualSpace] {
        return getSpaces(displayID: displayID).filter { !$0.isEmpty }
    }
}

// MARK: - Focus Preset

/// A keyboard shortcut to focus windows of a specific application
public struct FocusPreset: Codable, Equatable {
    /// The key code for this preset
    public var keyCode: UInt16
    /// Human-readable key name (e.g., "T", "B")
    public var keyString: String
    /// Modifier flags (control, option, shift, command)
    public var modifiers: UInt

    /// The bundle identifier of the target application (e.g., "com.googlecode.iterm2")
    public var appBundleID: String
    /// Display name of the application (e.g., "iTerm2")
    public var appName: String

    /// If true, this hotkey works globally (even without overlay)
    public var worksWithoutOverlay: Bool
    /// If true, this hotkey works when the overlay is active
    public var worksWithOverlay: Bool
    /// If true, launch the app if it's not already running
    public var openIfNotRunning: Bool

    public init(
        keyCode: UInt16,
        keyString: String,
        modifiers: UInt = KeyboardShortcut.Modifiers.none,
        appBundleID: String,
        appName: String,
        worksWithoutOverlay: Bool = true,
        worksWithOverlay: Bool = true,
        openIfNotRunning: Bool = false
    ) {
        self.keyCode = keyCode
        self.keyString = keyString
        self.modifiers = modifiers
        self.appBundleID = appBundleID
        self.appName = appName
        self.worksWithoutOverlay = worksWithoutOverlay
        self.worksWithOverlay = worksWithOverlay
        self.openIfNotRunning = openIfNotRunning
    }

    /// Display string for the key combination (e.g., "⌃⌥T")
    public var shortcutDisplayString: String {
        var parts: [String] = []
        if modifiers & KeyboardShortcut.Modifiers.control != 0 { parts.append("⌃") }
        if modifiers & KeyboardShortcut.Modifiers.option != 0 { parts.append("⌥") }
        if modifiers & KeyboardShortcut.Modifiers.shift != 0 { parts.append("⇧") }
        if modifiers & KeyboardShortcut.Modifiers.command != 0 { parts.append("⌘") }
        parts.append(keyString)
        return parts.joined()
    }

    /// Check if this preset matches the given key event
    public func matches(keyCode: UInt16, modifiers: UInt) -> Bool {
        return self.keyCode == keyCode && self.modifiers == modifiers
    }
}

// MARK: - MacTile Settings

/// All configurable settings for MacTile
public struct MacTileSettings: Equatable {
    // MARK: - Grid Configuration

    /// List of grid sizes to cycle through with Space key
    public var gridSizes: [GridSize]

    /// Default grid size (first in the list)
    public var defaultGridSize: GridSize {
        gridSizes.first ?? GridSize(cols: 8, rows: 2)
    }

    // MARK: - Spacing and Insets

    /// Spacing between windows in pixels
    public var windowSpacing: CGFloat

    /// Insets from screen edges
    public var insets: EdgeInsets

    // MARK: - Behavior

    /// Automatically close overlay after applying resize
    public var autoClose: Bool

    /// Show icon in menu bar
    public var showMenuBarIcon: Bool

    /// Launch MacTile when user logs in
    public var launchAtLogin: Bool

    /// When true, clicking without dragging confirms the current selection
    /// When false, clicking without dragging selects the single cell at click position
    public var confirmOnClickWithoutDrag: Bool

    // MARK: - Overlay Display

    /// Show help text at the top of the overlay
    public var showHelpText: Bool

    /// Show monitor indicator when multiple monitors are connected
    public var showMonitorIndicator: Bool

    // MARK: - Keyboard Shortcuts

    /// Global shortcut to toggle overlay (primary)
    public var toggleOverlayShortcut: KeyboardShortcut

    /// Secondary global shortcut to toggle overlay (optional)
    public var secondaryToggleOverlayShortcut: KeyboardShortcut?

    /// Overlay keyboard configuration
    public var overlayKeyboard: OverlayKeyboardSettings

    /// Quick tiling presets (0-30 presets)
    public var tilingPresets: [TilingPreset]

    /// Focus presets for switching between application windows
    public var focusPresets: [FocusPreset]

    // MARK: - Appearance

    /// Visual appearance settings
    public var appearance: AppearanceSettings

    // MARK: - Virtual Spaces

    /// Virtual spaces storage for window arrangements
    public var virtualSpaces: VirtualSpacesStorage

    /// Whether virtual spaces feature is enabled
    public var virtualSpacesEnabled: Bool

    /// Modifiers for saving virtual spaces (default: Control+Option+Shift)
    public var virtualSpaceSaveModifiers: UInt

    /// Modifiers for restoring virtual spaces (default: Control+Option)
    public var virtualSpaceRestoreModifiers: UInt

    // MARK: - Default Values

    public static let defaultGridSizes = [
        GridSize(cols: 8, rows: 2),
        GridSize(cols: 6, rows: 4),
        GridSize(cols: 4, rows: 4),
        GridSize(cols: 3, rows: 3),
        GridSize(cols: 2, rows: 2)
    ]

    /// Default modifiers for saving virtual spaces (Control+Option+Shift)
    public static let defaultVirtualSpaceSaveModifiers: UInt =
        KeyboardShortcut.Modifiers.control | KeyboardShortcut.Modifiers.option | KeyboardShortcut.Modifiers.shift

    /// Default modifiers for restoring virtual spaces (Control+Option)
    public static let defaultVirtualSpaceRestoreModifiers: UInt =
        KeyboardShortcut.Modifiers.control | KeyboardShortcut.Modifiers.option

    /// Default tiling presets for quick window positioning
    public static let defaultTilingPresets: [TilingPreset] = [
        // R: Right half -> Right third -> Right quarter
        TilingPreset(
            keyCode: 15,  // R key
            keyString: "R",
            modifiers: KeyboardShortcut.Modifiers.none,
            positions: [
                PresetPosition(startX: 0.5, startY: 0, endX: 1, endY: 1),      // Right half
                PresetPosition(startX: 0.667, startY: 0, endX: 1, endY: 1),    // Right third
                PresetPosition(startX: 0.75, startY: 0, endX: 1, endY: 1)      // Right quarter
            ],
            autoConfirm: true,
            cycleTimeout: 2000
        ),
        // E: Left half -> Left third -> Left quarter
        TilingPreset(
            keyCode: 14,  // E key
            keyString: "E",
            modifiers: KeyboardShortcut.Modifiers.none,
            positions: [
                PresetPosition(startX: 0, startY: 0, endX: 0.5, endY: 1),      // Left half
                PresetPosition(startX: 0, startY: 0, endX: 0.333, endY: 1),    // Left third
                PresetPosition(startX: 0, startY: 0, endX: 0.25, endY: 1)      // Left quarter
            ],
            autoConfirm: true,
            cycleTimeout: 2000
        ),
        // F: Full screen
        TilingPreset(
            keyCode: 3,   // F key
            keyString: "F",
            modifiers: KeyboardShortcut.Modifiers.none,
            positions: [
                PresetPosition(startX: 0, startY: 0, endX: 1, endY: 1)         // Full screen
            ],
            autoConfirm: true,
            cycleTimeout: 2000
        ),
        // C: Center third -> Center half
        TilingPreset(
            keyCode: 8,   // C key
            keyString: "C",
            modifiers: KeyboardShortcut.Modifiers.none,
            positions: [
                PresetPosition(startX: 0.333, startY: 0, endX: 0.667, endY: 1), // Center third
                PresetPosition(startX: 0.25, startY: 0, endX: 0.75, endY: 1)    // Center half
            ],
            autoConfirm: true,
            cycleTimeout: 2000
        )
    ]

    public static let `default` = MacTileSettings(
        gridSizes: defaultGridSizes,
        windowSpacing: 0,
        insets: .zero,
        autoClose: true,
        showMenuBarIcon: true,
        launchAtLogin: false,
        confirmOnClickWithoutDrag: true,
        showHelpText: true,
        showMonitorIndicator: true,
        toggleOverlayShortcut: .defaultToggleOverlay,
        secondaryToggleOverlayShortcut: .defaultSecondaryToggleOverlay,
        overlayKeyboard: .default,
        tilingPresets: defaultTilingPresets,
        focusPresets: [],
        appearance: .default,
        virtualSpaces: VirtualSpacesStorage(),
        virtualSpacesEnabled: true,
        virtualSpaceSaveModifiers: defaultVirtualSpaceSaveModifiers,
        virtualSpaceRestoreModifiers: defaultVirtualSpaceRestoreModifiers
    )

    public init(
        gridSizes: [GridSize],
        windowSpacing: CGFloat,
        insets: EdgeInsets,
        autoClose: Bool,
        showMenuBarIcon: Bool,
        launchAtLogin: Bool,
        confirmOnClickWithoutDrag: Bool,
        showHelpText: Bool,
        showMonitorIndicator: Bool,
        toggleOverlayShortcut: KeyboardShortcut,
        secondaryToggleOverlayShortcut: KeyboardShortcut?,
        overlayKeyboard: OverlayKeyboardSettings,
        tilingPresets: [TilingPreset],
        focusPresets: [FocusPreset],
        appearance: AppearanceSettings,
        virtualSpaces: VirtualSpacesStorage = VirtualSpacesStorage(),
        virtualSpacesEnabled: Bool = true,
        virtualSpaceSaveModifiers: UInt = defaultVirtualSpaceSaveModifiers,
        virtualSpaceRestoreModifiers: UInt = defaultVirtualSpaceRestoreModifiers
    ) {
        self.gridSizes = gridSizes.isEmpty ? Self.defaultGridSizes : gridSizes
        self.windowSpacing = max(0, windowSpacing)
        self.insets = insets
        self.autoClose = autoClose
        self.showMenuBarIcon = showMenuBarIcon
        self.launchAtLogin = launchAtLogin
        self.confirmOnClickWithoutDrag = confirmOnClickWithoutDrag
        self.showHelpText = showHelpText
        self.showMonitorIndicator = showMonitorIndicator
        self.toggleOverlayShortcut = toggleOverlayShortcut
        self.secondaryToggleOverlayShortcut = secondaryToggleOverlayShortcut
        self.overlayKeyboard = overlayKeyboard
        // Limit to 30 presets each
        self.tilingPresets = Array(tilingPresets.prefix(30))
        self.focusPresets = Array(focusPresets.prefix(30))
        self.appearance = appearance
        self.virtualSpaces = virtualSpaces
        self.virtualSpacesEnabled = virtualSpacesEnabled
        self.virtualSpaceSaveModifiers = virtualSpaceSaveModifiers
        self.virtualSpaceRestoreModifiers = virtualSpaceRestoreModifiers
    }
}

// MARK: - MacTileSettings Codable (backward compatibility)

extension MacTileSettings: Codable {
    enum CodingKeys: String, CodingKey {
        case gridSizes, windowSpacing, insets, autoClose, showMenuBarIcon
        case launchAtLogin, confirmOnClickWithoutDrag, showHelpText, showMonitorIndicator
        case toggleOverlayShortcut, secondaryToggleOverlayShortcut, overlayKeyboard
        case tilingPresets, focusPresets, appearance, virtualSpaces
        case virtualSpacesEnabled, virtualSpaceSaveModifiers, virtualSpaceRestoreModifiers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required fields
        gridSizes = try container.decode([GridSize].self, forKey: .gridSizes)
        windowSpacing = try container.decode(CGFloat.self, forKey: .windowSpacing)
        insets = try container.decode(EdgeInsets.self, forKey: .insets)
        autoClose = try container.decode(Bool.self, forKey: .autoClose)
        showMenuBarIcon = try container.decode(Bool.self, forKey: .showMenuBarIcon)
        launchAtLogin = try container.decode(Bool.self, forKey: .launchAtLogin)
        confirmOnClickWithoutDrag = try container.decode(Bool.self, forKey: .confirmOnClickWithoutDrag)
        showHelpText = try container.decode(Bool.self, forKey: .showHelpText)
        showMonitorIndicator = try container.decode(Bool.self, forKey: .showMonitorIndicator)
        toggleOverlayShortcut = try container.decode(KeyboardShortcut.self, forKey: .toggleOverlayShortcut)
        secondaryToggleOverlayShortcut = try container.decodeIfPresent(KeyboardShortcut.self, forKey: .secondaryToggleOverlayShortcut)
        overlayKeyboard = try container.decode(OverlayKeyboardSettings.self, forKey: .overlayKeyboard)
        tilingPresets = try container.decode([TilingPreset].self, forKey: .tilingPresets)
        focusPresets = try container.decode([FocusPreset].self, forKey: .focusPresets)
        appearance = try container.decode(AppearanceSettings.self, forKey: .appearance)

        // Optional fields for backward compatibility - older settings won't have these
        virtualSpaces = try container.decodeIfPresent(VirtualSpacesStorage.self, forKey: .virtualSpaces) ?? VirtualSpacesStorage()
        virtualSpacesEnabled = try container.decodeIfPresent(Bool.self, forKey: .virtualSpacesEnabled) ?? true
        virtualSpaceSaveModifiers = try container.decodeIfPresent(UInt.self, forKey: .virtualSpaceSaveModifiers) ?? Self.defaultVirtualSpaceSaveModifiers
        virtualSpaceRestoreModifiers = try container.decodeIfPresent(UInt.self, forKey: .virtualSpaceRestoreModifiers) ?? Self.defaultVirtualSpaceRestoreModifiers
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(gridSizes, forKey: .gridSizes)
        try container.encode(windowSpacing, forKey: .windowSpacing)
        try container.encode(insets, forKey: .insets)
        try container.encode(autoClose, forKey: .autoClose)
        try container.encode(showMenuBarIcon, forKey: .showMenuBarIcon)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(confirmOnClickWithoutDrag, forKey: .confirmOnClickWithoutDrag)
        try container.encode(showHelpText, forKey: .showHelpText)
        try container.encode(showMonitorIndicator, forKey: .showMonitorIndicator)
        try container.encode(toggleOverlayShortcut, forKey: .toggleOverlayShortcut)
        try container.encodeIfPresent(secondaryToggleOverlayShortcut, forKey: .secondaryToggleOverlayShortcut)
        try container.encode(overlayKeyboard, forKey: .overlayKeyboard)
        try container.encode(tilingPresets, forKey: .tilingPresets)
        try container.encode(focusPresets, forKey: .focusPresets)
        try container.encode(appearance, forKey: .appearance)
        try container.encode(virtualSpaces, forKey: .virtualSpaces)
        try container.encode(virtualSpacesEnabled, forKey: .virtualSpacesEnabled)
        try container.encode(virtualSpaceSaveModifiers, forKey: .virtualSpaceSaveModifiers)
        try container.encode(virtualSpaceRestoreModifiers, forKey: .virtualSpaceRestoreModifiers)
    }
}

// MARK: - GridSize Codable

extension GridSize: Codable {
    enum CodingKeys: String, CodingKey {
        case cols, rows
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let cols = try container.decode(Int.self, forKey: .cols)
        let rows = try container.decode(Int.self, forKey: .rows)
        self.init(cols: cols, rows: rows)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cols, forKey: .cols)
        try container.encode(rows, forKey: .rows)
    }

    /// String representation for display and storage
    public var stringValue: String {
        return "\(cols)x\(rows)"
    }
}

// MARK: - EdgeInsets Codable

extension EdgeInsets: Codable {
    enum CodingKeys: String, CodingKey {
        case top, left, bottom, right
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let top = try container.decode(CGFloat.self, forKey: .top)
        let left = try container.decode(CGFloat.self, forKey: .left)
        let bottom = try container.decode(CGFloat.self, forKey: .bottom)
        let right = try container.decode(CGFloat.self, forKey: .right)
        self.init(top: top, left: left, bottom: bottom, right: right)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(top, forKey: .top)
        try container.encode(left, forKey: .left)
        try container.encode(bottom, forKey: .bottom)
        try container.encode(right, forKey: .right)
    }
}

// MARK: - Grid Size Parsing

extension MacTileSettings {
    /// Parse grid sizes from comma-separated string (e.g., "8x2,6x4,4x4")
    public static func parseGridSizes(_ string: String) -> [GridSize] {
        return string
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .compactMap { GridSize.parse($0) }
    }

    /// Convert grid sizes to comma-separated string
    public static func gridSizesToString(_ sizes: [GridSize]) -> String {
        return sizes.map { $0.stringValue }.joined(separator: ", ")
    }
}
