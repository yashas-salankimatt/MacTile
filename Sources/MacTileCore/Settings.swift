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

    // MARK: - Keyboard Shortcuts

    /// Global shortcut to toggle overlay
    public var toggleOverlayShortcut: KeyboardShortcut

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
        toggleOverlayShortcut: .defaultToggleOverlay
    )

    public init(
        gridSizes: [GridSize],
        windowSpacing: CGFloat,
        insets: EdgeInsets,
        autoClose: Bool,
        showMenuBarIcon: Bool,
        toggleOverlayShortcut: KeyboardShortcut
    ) {
        self.gridSizes = gridSizes.isEmpty ? Self.defaultGridSizes : gridSizes
        self.windowSpacing = max(0, windowSpacing)
        self.insets = insets
        self.autoClose = autoClose
        self.showMenuBarIcon = showMenuBarIcon
        self.toggleOverlayShortcut = toggleOverlayShortcut
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
