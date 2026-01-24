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

// MARK: - Tiling Preset

/// A keyboard shortcut that tiles to a proportional screen region
public struct TilingPreset: Codable, Equatable {
    /// The key code for this preset
    public var keyCode: UInt16
    /// Human-readable key name (e.g., "R", "1")
    public var keyString: String

    /// Start X coordinate as proportion (0.0 to 1.0, where 0 = left edge)
    public var startX: CGFloat
    /// Start Y coordinate as proportion (0.0 to 1.0, where 0 = top edge)
    public var startY: CGFloat
    /// End X coordinate as proportion (0.0 to 1.0, where 1 = right edge)
    public var endX: CGFloat
    /// End Y coordinate as proportion (0.0 to 1.0, where 1 = bottom edge)
    public var endY: CGFloat

    /// If true, immediately apply the selection; if false, just select the area
    public var autoConfirm: Bool

    public init(
        keyCode: UInt16,
        keyString: String,
        startX: CGFloat,
        startY: CGFloat,
        endX: CGFloat,
        endY: CGFloat,
        autoConfirm: Bool
    ) {
        self.keyCode = keyCode
        self.keyString = keyString
        self.startX = max(0, min(1, startX))
        self.startY = max(0, min(1, startY))
        self.endX = max(0, min(1, endX))
        self.endY = max(0, min(1, endY))
        self.autoConfirm = autoConfirm
    }

    /// Display string for the coordinates
    public var coordinateString: String {
        return String(format: "(%.2f,%.2f);(%.2f,%.2f)", startX, startY, endX, endY)
    }

    /// Parse coordinates from string format "(x1,y1);(x2,y2)"
    public static func parseCoordinates(_ string: String) -> (startX: CGFloat, startY: CGFloat, endX: CGFloat, endY: CGFloat)? {
        // Remove whitespace and parentheses
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

    /// Convert proportional coordinates to a grid selection
    /// - Sizes are rounded down
    /// - Position is determined by center of mass:
    ///   - If center is on left half, align to left
    ///   - If center is on right half, align to right
    ///   - Same logic for top/bottom
    public func toGridSelection(gridSize: GridSize) -> GridSelection {
        // Normalize so start <= end
        let x1 = min(startX, endX)
        let y1 = min(startY, endY)
        let x2 = max(startX, endX)
        let y2 = max(startY, endY)

        // Calculate the center of the preset area
        let centerX = (x1 + x2) / 2
        let centerY = (y1 + y2) / 2

        // Calculate the size in grid units (round down, minimum 1)
        let widthProportion = x2 - x1
        let heightProportion = y2 - y1

        let gridWidth = max(1, Int(widthProportion * CGFloat(gridSize.cols)))
        let gridHeight = max(1, Int(heightProportion * CGFloat(gridSize.rows)))

        // Calculate starting position based on center of mass
        let startCol: Int
        if centerX < 0.5 {
            // Left side - start from the proportional position, round down
            startCol = Int(x1 * CGFloat(gridSize.cols))
        } else {
            // Right side - align so selection ends at the right edge of the proportional area
            let endCol = Int(ceil(x2 * CGFloat(gridSize.cols))) - 1
            startCol = max(0, endCol - gridWidth + 1)
        }

        let startRow: Int
        if centerY < 0.5 {
            // Top side - start from the proportional position, round down
            startRow = Int(y1 * CGFloat(gridSize.rows))
        } else {
            // Bottom side - align so selection ends at the bottom edge
            let endRow = Int(ceil(y2 * CGFloat(gridSize.rows))) - 1
            startRow = max(0, endRow - gridHeight + 1)
        }

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

    /// Common presets
    public static let leftHalf = TilingPreset(
        keyCode: 0, keyString: "", startX: 0, startY: 0, endX: 0.5, endY: 1, autoConfirm: true
    )
    public static let rightHalf = TilingPreset(
        keyCode: 0, keyString: "", startX: 0.5, startY: 0, endX: 1, endY: 1, autoConfirm: true
    )
    public static let topHalf = TilingPreset(
        keyCode: 0, keyString: "", startX: 0, startY: 0, endX: 1, endY: 0.5, autoConfirm: true
    )
    public static let bottomHalf = TilingPreset(
        keyCode: 0, keyString: "", startX: 0, startY: 0.5, endX: 1, endY: 1, autoConfirm: true
    )
    public static let fullScreen = TilingPreset(
        keyCode: 0, keyString: "", startX: 0, startY: 0, endX: 1, endY: 1, autoConfirm: true
    )
}

// MARK: - MacTile Settings

/// All configurable settings for MacTile
public struct MacTileSettings: Codable, Equatable {
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

    /// Quick tiling presets (0-10 presets)
    public var tilingPresets: [TilingPreset]

    // MARK: - Appearance

    /// Visual appearance settings
    public var appearance: AppearanceSettings

    // MARK: - Default Values

    public static let defaultGridSizes = [
        GridSize(cols: 8, rows: 2),
        GridSize(cols: 6, rows: 4),
        GridSize(cols: 4, rows: 4),
        GridSize(cols: 3, rows: 3),
        GridSize(cols: 2, rows: 2)
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
        tilingPresets: [],
        appearance: .default
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
        appearance: AppearanceSettings
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
        // Limit to 10 presets
        self.tilingPresets = Array(tilingPresets.prefix(10))
        self.appearance = appearance
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
