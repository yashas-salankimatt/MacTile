import AppKit
import MacTileCore

// MARK: - Real Window Info

struct RealWindowInfo: WindowInfo {
    let identifier: UInt32
    let title: String
    let frame: CGRect
    let processIdentifier: pid_t
    let isMinimized: Bool
    let axWindow: AXUIElement
}

// MARK: - Real Screen Info

struct RealScreenInfo: ScreenInfo {
    let identifier: UInt32
    let frame: CGRect
    let visibleFrame: CGRect
    let isMain: Bool

    init(from screen: NSScreen, index: UInt32) {
        self.identifier = index
        self.frame = screen.frame
        self.visibleFrame = screen.visibleFrame
        self.isMain = screen == NSScreen.main
    }
}

// MARK: - Real Window Manager

/// Manages window operations using the Accessibility API
class RealWindowManager: WindowManagerProtocol {
    static let shared = RealWindowManager()

    private init() {}

    func getFocusedWindow() -> WindowInfo? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)

        guard result == .success, let windowElement = focusedWindow else {
            return nil
        }

        let axWindow = windowElement as! AXUIElement
        return createWindowInfo(from: axWindow, pid: frontApp.processIdentifier)
    }

    func getAllWindows() -> [WindowInfo] {
        var windows: [WindowInfo] = []

        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
        }

        for app in runningApps {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)

            var windowList: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowList)

            guard result == .success, let windowArray = windowList as? [AXUIElement] else {
                continue
            }

            for axWindow in windowArray {
                if let windowInfo = createWindowInfo(from: axWindow, pid: app.processIdentifier) {
                    windows.append(windowInfo)
                }
            }
        }

        return windows
    }

    func getAllScreens() -> [ScreenInfo] {
        return NSScreen.screens.enumerated().map { index, screen in
            RealScreenInfo(from: screen, index: UInt32(index))
        }
    }

    func getMainScreen() -> ScreenInfo? {
        guard let mainScreen = NSScreen.main else {
            return nil
        }
        let index = NSScreen.screens.firstIndex(of: mainScreen) ?? 0
        return RealScreenInfo(from: mainScreen, index: UInt32(index))
    }

    func setWindowFrame(_ window: WindowInfo, frame: CGRect) -> Bool {
        guard let realWindow = window as? RealWindowInfo else {
            return false
        }

        guard let screen = NSScreen.main else {
            return false
        }

        let screenHeight = screen.frame.height
        let axY = screenHeight - frame.origin.y - frame.height

        // For some apps (like Zen browser), we need to set size first, then position, then size again
        // This helps work around minimum size constraints
        var size = CGSize(width: frame.width, height: frame.height)
        var position = CGPoint(x: frame.origin.x, y: axY)

        // First, try to set size (helps with apps that have constraints)
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(realWindow.axWindow, kAXSizeAttribute as CFString, sizeValue)
        }

        // Set position
        if let posValue = AXValueCreate(.cgPoint, &position) {
            let posResult = AXUIElementSetAttributeValue(realWindow.axWindow, kAXPositionAttribute as CFString, posValue)
            if posResult != .success {
                print("Failed to set position: \(posResult.rawValue)")
            }
        }

        // Set size again after position (some apps need this order)
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            let sizeResult = AXUIElementSetAttributeValue(realWindow.axWindow, kAXSizeAttribute as CFString, sizeValue)
            if sizeResult != .success {
                print("Failed to set size: \(sizeResult.rawValue)")
            }
        }

        return true
    }

    /// Activate (bring to front) a window
    func activateWindow(_ window: WindowInfo) {
        guard let realWindow = window as? RealWindowInfo else { return }

        // Raise the window
        AXUIElementSetAttributeValue(realWindow.axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)

        // Activate the owning application
        if let app = NSRunningApplication(processIdentifier: realWindow.processIdentifier) {
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }

    func hasAccessibilityPermissions() -> Bool {
        return AXIsProcessTrusted()
    }

    func requestAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Private Helpers

    private func createWindowInfo(from axWindow: AXUIElement, pid: pid_t) -> RealWindowInfo? {
        // Get window title
        var titleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue)
        let title = titleValue as? String ?? "Untitled"

        // Get window position
        var positionValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &positionValue) == .success,
              let posAXValue = positionValue else {
            return nil
        }

        var position = CGPoint.zero
        guard AXValueGetValue(posAXValue as! AXValue, .cgPoint, &position) else {
            return nil
        }

        // Get window size
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let sizeAXValue = sizeValue else {
            return nil
        }

        var size = CGSize.zero
        guard AXValueGetValue(sizeAXValue as! AXValue, .cgSize, &size) else {
            return nil
        }

        // Convert from AX coordinates (top-left origin) to screen coordinates (bottom-left origin)
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let convertedY = screenHeight - position.y - size.height

        let frame = CGRect(x: position.x, y: convertedY, width: size.width, height: size.height)

        // Check if minimized
        var minimizedValue: CFTypeRef?
        AXUIElementCopyAttributeValue(axWindow, kAXMinimizedAttribute as CFString, &minimizedValue)
        let isMinimized = minimizedValue as? Bool ?? false

        return RealWindowInfo(
            identifier: UInt32(pid),  // Use PID as a simple identifier
            title: title,
            frame: frame,
            processIdentifier: pid,
            isMinimized: isMinimized,
            axWindow: axWindow
        )
    }
}

// MARK: - Legacy WindowManager (for backward compatibility)

/// Wrapper class for convenience - uses the shared RealWindowManager
class WindowManager {
    static let shared = WindowManager()

    private let realManager = RealWindowManager.shared

    private init() {}

    /// Resize the currently focused window to the given grid selection
    func resizeFocusedWindow(to selection: GridSelection, gridSize: GridSize) {
        guard let screen = realManager.getMainScreen() else {
            print("No main screen found")
            return
        }

        // Convert selection to screen coordinates
        let rect = GridOperations.selectionToRect(
            selection: selection,
            gridSize: gridSize,
            screenFrame: screen.visibleFrame,
            spacing: 10,
            insets: EdgeInsets.zero
        )

        guard let window = realManager.getFocusedWindow() else {
            print("No focused window")
            return
        }

        let success = realManager.setWindowFrame(window, frame: rect)
        if success {
            print("Resized window to: \(rect)")
        } else {
            print("Failed to resize window")
        }
    }

    /// Check if accessibility permissions are granted
    func checkAccessibilityPermissions() -> Bool {
        return realManager.requestAccessibilityPermissions()
    }
}
