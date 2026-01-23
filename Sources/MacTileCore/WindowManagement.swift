import Foundation
import CoreGraphics

// MARK: - Window Info Protocol

/// Protocol representing a window's information
public protocol WindowInfo {
    var identifier: UInt32 { get }
    var title: String { get }
    var frame: CGRect { get }
    var processIdentifier: pid_t { get }
    var isMinimized: Bool { get }
}

// MARK: - Screen Info Protocol

/// Protocol representing screen/monitor information
public protocol ScreenInfo {
    var identifier: UInt32 { get }
    var frame: CGRect { get }
    var visibleFrame: CGRect { get }  // Frame excluding menu bar, dock
    var isMain: Bool { get }
}

// MARK: - Window Manager Protocol

/// Protocol for window management operations - allows for testing with mocks
public protocol WindowManagerProtocol {
    /// Get the currently focused window
    func getFocusedWindow() -> WindowInfo?

    /// Get all windows
    func getAllWindows() -> [WindowInfo]

    /// Get all screens
    func getAllScreens() -> [ScreenInfo]

    /// Get the main screen
    func getMainScreen() -> ScreenInfo?

    /// Move and resize a window
    func setWindowFrame(_ window: WindowInfo, frame: CGRect) -> Bool

    /// Check if accessibility permissions are granted
    func hasAccessibilityPermissions() -> Bool

    /// Request accessibility permissions
    func requestAccessibilityPermissions() -> Bool
}

// MARK: - Mock Window Info (for testing)

public struct MockWindowInfo: WindowInfo {
    public var identifier: UInt32
    public var title: String
    public var frame: CGRect
    public var processIdentifier: pid_t
    public var isMinimized: Bool

    public init(identifier: UInt32 = 1, title: String = "Test Window", frame: CGRect = CGRect(x: 0, y: 0, width: 800, height: 600), processIdentifier: pid_t = 1, isMinimized: Bool = false) {
        self.identifier = identifier
        self.title = title
        self.frame = frame
        self.processIdentifier = processIdentifier
        self.isMinimized = isMinimized
    }
}

// MARK: - Mock Screen Info (for testing)

public struct MockScreenInfo: ScreenInfo {
    public var identifier: UInt32
    public var frame: CGRect
    public var visibleFrame: CGRect
    public var isMain: Bool

    public init(identifier: UInt32 = 1, frame: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080), visibleFrame: CGRect? = nil, isMain: Bool = true) {
        self.identifier = identifier
        self.frame = frame
        self.visibleFrame = visibleFrame ?? CGRect(x: 0, y: 25, width: frame.width, height: frame.height - 25) // Account for menu bar
        self.isMain = isMain
    }
}

// MARK: - Mock Window Manager (for testing)

public class MockWindowManager: WindowManagerProtocol {
    public var windows: [WindowInfo] = []
    public var screens: [ScreenInfo] = []
    public var focusedWindow: WindowInfo?
    public var hasPermissions: Bool = true
    public var lastSetFrame: CGRect?
    public var lastSetWindow: WindowInfo?

    public init() {
        // Default screen
        screens = [MockScreenInfo()]
    }

    public func getFocusedWindow() -> WindowInfo? {
        return focusedWindow ?? windows.first
    }

    public func getAllWindows() -> [WindowInfo] {
        return windows
    }

    public func getAllScreens() -> [ScreenInfo] {
        return screens
    }

    public func getMainScreen() -> ScreenInfo? {
        return screens.first { $0.isMain } ?? screens.first
    }

    public func setWindowFrame(_ window: WindowInfo, frame: CGRect) -> Bool {
        lastSetWindow = window
        lastSetFrame = frame
        return hasPermissions
    }

    public func hasAccessibilityPermissions() -> Bool {
        return hasPermissions
    }

    public func requestAccessibilityPermissions() -> Bool {
        return hasPermissions
    }
}

// MARK: - Window Tiler

/// Handles the logic of tiling windows based on grid selections
public class WindowTiler {
    private let windowManager: WindowManagerProtocol
    public var spacing: CGFloat = 10
    public var insets: EdgeInsets = EdgeInsets.zero

    public init(windowManager: WindowManagerProtocol) {
        self.windowManager = windowManager
    }

    /// Tile the focused window to a grid selection
    public func tileFocusedWindow(to selection: GridSelection, gridSize: GridSize) -> Bool {
        guard let window = windowManager.getFocusedWindow(),
              let screen = windowManager.getMainScreen() else {
            return false
        }

        let targetFrame = GridOperations.selectionToRect(
            selection: selection,
            gridSize: gridSize,
            screenFrame: screen.visibleFrame,
            spacing: spacing,
            insets: insets
        )

        return windowManager.setWindowFrame(window, frame: targetFrame)
    }

    /// Get the current grid selection for a window
    public func getWindowSelection(gridSize: GridSize) -> GridSelection? {
        guard let window = windowManager.getFocusedWindow(),
              let screen = windowManager.getMainScreen() else {
            return nil
        }

        return GridOperations.rectToSelection(
            rect: window.frame,
            gridSize: gridSize,
            screenFrame: screen.visibleFrame,
            insets: insets
        )
    }
}
