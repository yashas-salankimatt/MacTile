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

    /// Get the primary screen height for AX coordinate conversion
    /// The AX coordinate system uses the primary display (with menu bar) as reference
    /// This is always NSScreen.screens.first according to Apple documentation
    private var primaryScreenHeight: CGFloat {
        return NSScreen.screens.first?.frame.height ?? 0
    }

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

        // CFTypeRef is always castable to AXUIElement (both are CoreFoundation types)
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
            print("[WindowManager] ERROR: Window is not a RealWindowInfo")
            return false
        }

        return setAXWindowFrame(realWindow.axWindow, frame: frame)
    }

    /// Set the frame of an AXUIElement window.
    /// This is the shared implementation used by both WindowManager and VirtualSpaceManager.
    /// The frame should be in NSScreen coordinates (bottom-left origin).
    @discardableResult
    func setAXWindowFrame(_ axWindow: AXUIElement, frame: CGRect) -> Bool {
        // Use primary screen for AX coordinate conversion
        // AX coordinates have origin at top-left of the PRIMARY display (with menu bar)
        // NSScreen.main returns the screen with keyboard focus, which may not be the primary
        guard let primaryScreen = NSScreen.screens.first else {
            print("[WindowManager] ERROR: No screens available")
            return false
        }

        let screenHeight = primaryScreen.frame.height

        // Convert from NSScreen coords (bottom-left origin) to AX coords (top-left origin)
        // The conversion uses the primary screen height as the reference
        let axY = screenHeight - frame.origin.y - frame.height

        let targetSize = CGSize(width: frame.width, height: frame.height)
        let targetPosition = CGPoint(x: frame.origin.x, y: axY)

        print("[WindowManager] ═══════════════════════════════════════════════")
        print("[WindowManager] Target frame (screen coords): \(frame)")
        print("[WindowManager] Target position (AX coords): \(targetPosition)")
        print("[WindowManager] Target size: \(targetSize)")
        print("[WindowManager] Primary screen height: \(screenHeight)")

        // Read current window state before changes
        let beforeState = readWindowState(axWindow)
        print("[WindowManager] BEFORE - Position: \(beforeState.position), Size: \(beforeState.size)")

        // Detect if this is a cross-monitor move
        // Convert current AX position to screen coordinates to find current screen
        let currentWindowCenter = CGPoint(
            x: beforeState.position.x + beforeState.size.width / 2,
            y: screenHeight - beforeState.position.y - beforeState.size.height / 2
        )
        let targetCenter = CGPoint(
            x: frame.origin.x + frame.width / 2,
            y: frame.origin.y + frame.height / 2
        )

        let currentScreen = screenContaining(point: currentWindowCenter)
        let targetScreen = screenContaining(point: targetCenter)
        let isCrossMonitorMove = currentScreen != targetScreen

        if isCrossMonitorMove {
            print("[WindowManager] Cross-monitor move detected: \(currentScreen?.localizedName ?? "unknown") -> \(targetScreen?.localizedName ?? "unknown")")
        }

        // STRATEGY depends on whether this is a cross-monitor move
        // For cross-monitor moves: Shrink first, move, then resize (avoids browser visibility protection)
        // For same-screen moves: Safe position, resize, then move (handles edge-anchoring apps)

        if isCrossMonitorMove {
            // CROSS-MONITOR STRATEGY: Shrink window first, then move, then resize to final
            // Browsers refuse to move large windows "mostly off-screen", but small windows
            // will move freely. By shrinking first, we ensure the move succeeds.

            print("[WindowManager] Using cross-monitor strategy: shrink, move, then resize")

            // Step 1: Shrink window to a small size that will fit anywhere
            // Use a size small enough to not trigger visibility protection
            let smallSize = CGSize(width: 400, height: 300)
            print("[WindowManager] Step 1: Shrinking to intermediate size \(smallSize)")
            var size = smallSize
            if let sizeValue = AXValueCreate(.cgSize, &size) {
                AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, sizeValue)
            }
            usleep(50000) // 50ms - give window time to shrink

            // Step 2: Move to target position (small window will move freely)
            print("[WindowManager] Step 2: Moving to target position \(targetPosition)")
            var position = targetPosition
            if let posValue = AXValueCreate(.cgPoint, &position) {
                AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, posValue)
            }
            usleep(50000) // 50ms - give window time to move across monitors

            // Step 3: Resize to final size
            print("[WindowManager] Step 3: Resizing to final size \(targetSize)")
            size = targetSize
            if let sizeValue = AXValueCreate(.cgSize, &size) {
                AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, sizeValue)
            }
            usleep(50000) // 50ms

            // Step 4: Correct position (resize may have shifted it)
            print("[WindowManager] Step 4: Correcting position to \(targetPosition)")
            if let posValue = AXValueCreate(.cgPoint, &position) {
                AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, posValue)
            }
            usleep(30000) // 30ms

        } else {
            // SAME-SCREEN STRATEGY: Safe position first, then resize, then final position
            // This handles apps that anchor edges during resize

            print("[WindowManager] Using same-screen strategy: safe position, size, then final position")

            // Step 1: Move window to left edge to give it room to resize
            // Only do this if the window is not already near the left edge of the target screen
            let screenLeftEdge = targetScreen?.frame.origin.x ?? 0
            let needsSafeMove = beforeState.position.x > screenLeftEdge + 100

            if needsSafeMove {
                var safePosition = CGPoint(x: screenLeftEdge, y: beforeState.position.y)
                print("[WindowManager] Step 1: Moving to safe position \(safePosition) first")
                if let posValue = AXValueCreate(.cgPoint, &safePosition) {
                    AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, posValue)
                }
                usleep(30000) // 30ms - give window time to move
            }

            // Step 2: Initial size set
            print("[WindowManager] Step 2: Setting initial size to \(targetSize)")
            var size = targetSize
            if let sizeValue = AXValueCreate(.cgSize, &size) {
                AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, sizeValue)
            }
            usleep(40000) // 40ms

            // Step 3: Set position
            print("[WindowManager] Step 3: Setting position to \(targetPosition)")
            var position = targetPosition
            if let posValue = AXValueCreate(.cgPoint, &position) {
                AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, posValue)
            }
            usleep(30000) // 30ms
        }

        // Unified correction loop - some apps link position and size
        // Setting size can move the window, so we need to correct both together
        // Some apps resize gradually and need multiple attempts
        // Key insight from gTile: they don't use retry logic because GNOME API is synchronous
        // But macOS AX API is asynchronous - we MUST retry until stable for ALL window types
        print("[WindowManager] Unified correction loop")
        let maxCorrectionAttempts = 10
        var positionOK = false
        var sizeOK = false
        var lastState = readWindowState(axWindow)
        var stuckCount = 0

        for attempt in 1...maxCorrectionAttempts {
            let state = readWindowState(axWindow)

            // Check position accuracy using ResizeStateChecker
            positionOK = ResizeStateChecker.isPositionOK(actual: state.position, target: targetPosition)

            // Check size accuracy using ResizeStateChecker
            sizeOK = ResizeStateChecker.isSizeOK(actual: state.size, target: targetSize)

            if positionOK && sizeOK {
                print("[WindowManager]   Attempt \(attempt): Both position and size OK")
                break
            }

            // Check if we're stuck - same state as last attempt
            // Only consider minimum constraint if we're truly stuck (no change for 3+ attempts)
            if state.position == lastState.position && state.size == lastState.size {
                stuckCount += 1
                if stuckCount >= 3 {
                    // Now check if this looks like a minimum constraint using ResizeStateChecker
                    if ResizeStateChecker.isMinimumConstraint(actual: state.size, target: targetSize) {
                        print("[WindowManager]   Attempt \(attempt): Stuck at minimum constraint (w:\(state.size.width) vs \(targetSize.width), h:\(state.size.height) vs \(targetSize.height))")
                        sizeOK = true // Accept this as the best we can do
                        break
                    } else {
                        print("[WindowManager]   Attempt \(attempt): Stuck (no progress for \(stuckCount) attempts), stopping")
                        break
                    }
                }
            } else {
                stuckCount = 0 // Reset if we made progress
            }
            lastState = state

            print("[WindowManager]   Attempt \(attempt): pos=\(state.position) (ok=\(positionOK)), size=\(state.size) (ok=\(sizeOK))")

            // Always set both size and position each iteration
            // Set size first
            var sz = targetSize
            if let sizeValue = AXValueCreate(.cgSize, &sz) {
                AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, sizeValue)
            }
            usleep(30000) // 30ms

            // Then set position
            var pos = targetPosition
            if let posValue = AXValueCreate(.cgPoint, &pos) {
                AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, posValue)
            }
            usleep(25000)

            // Set size again (position change can affect size)
            if let sizeValue = AXValueCreate(.cgSize, &sz) {
                AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, sizeValue)
            }
            usleep(25000)

            // Final position adjustment (size change can affect position)
            if let posValue = AXValueCreate(.cgPoint, &pos) {
                AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, posValue)
            }
            usleep(20000)
        }

        // Read final state and check using ResizeStateChecker
        let finalState = readWindowState(axWindow)
        positionOK = ResizeStateChecker.isPositionOK(actual: finalState.position, target: targetPosition)
        sizeOK = ResizeStateChecker.isSizeOK(actual: finalState.size, target: targetSize)

        print("[WindowManager] FINAL - Position: \(finalState.position), Size: \(finalState.size)")

        if !positionOK {
            print("[WindowManager] ⚠️  Position mismatch! Target: \(targetPosition), Actual: \(finalState.position)")
            print("[WindowManager]     Delta: x=\(finalState.position.x - targetPosition.x), y=\(finalState.position.y - targetPosition.y)")
        }
        if !sizeOK {
            // Check if it's a minimum size constraint
            if finalState.size.width > targetSize.width {
                print("[WindowManager] ⚠️  Size mismatch (likely minimum window size constraint)")
                print("[WindowManager]     App minimum width appears to be: \(finalState.size.width)")
            } else {
                print("[WindowManager] ⚠️  Size mismatch! Target: \(targetSize), Actual: \(finalState.size)")
            }
            print("[WindowManager]     Delta: w=\(finalState.size.width - targetSize.width), h=\(finalState.size.height - targetSize.height)")
        }
        if positionOK && sizeOK {
            print("[WindowManager] ✓ Window frame set successfully")
        }

        print("[WindowManager] ═══════════════════════════════════════════════")

        // Consider it a success if position is correct, even if size hit minimum constraint
        // (user can't make window smaller than app allows anyway)
        let sizeAcceptable = sizeOK || (finalState.size.width >= targetSize.width && finalState.size.height >= targetSize.height - 5)
        return positionOK && sizeAcceptable
    }

    /// Read current window position and size
    private func readWindowState(_ axWindow: AXUIElement) -> (position: CGPoint, size: CGSize) {
        var position = CGPoint.zero
        var size = CGSize.zero

        var positionValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &positionValue) == .success,
           let posAXValue = positionValue {
            AXValueGetValue(posAXValue as! AXValue, .cgPoint, &position)
        }

        var sizeValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeValue) == .success,
           let sizeAXValue = sizeValue {
            AXValueGetValue(sizeAXValue as! AXValue, .cgSize, &size)
        }

        return (position, size)
    }

    /// Set window size with verify-and-retry loop
    /// Returns the actual achieved size and number of attempts made
    private func setSizeWithRetry(_ axWindow: AXUIElement, targetSize: CGSize, maxAttempts: Int) -> (actualSize: CGSize, attempts: Int) {
        var actualSize = CGSize.zero

        for attempt in 1...maxAttempts {
            var size = targetSize
            if let sizeValue = AXValueCreate(.cgSize, &size) {
                AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, sizeValue)
            }

            // Wait for the window to actually resize - longer wait for first attempt
            let waitTime: UInt32 = attempt == 1 ? 40000 : 30000
            usleep(waitTime)

            // Read back the actual size
            actualSize = readWindowState(axWindow).size

            // Check if we achieved the target size using ResizeStateChecker
            if ResizeStateChecker.isSizeOK(actual: actualSize, target: targetSize) {
                return (actualSize, attempt)
            }

            // If size exceeds target, it's likely a minimum size constraint - don't retry
            // Use a simplified check here (any dimension exceeding is enough to stop)
            if actualSize.width > targetSize.width + ResizeStateChecker.exceedsThreshold ||
               actualSize.height > targetSize.height + ResizeStateChecker.exceedsThreshold {
                print("[WindowManager]     Size exceeded target (likely minimum constraint), not retrying")
                return (actualSize, attempt)
            }

            // Wait a bit more before retry to let window settle
            if attempt < maxAttempts {
                usleep(20000)
            }
        }

        return (actualSize, maxAttempts)
    }

    /// Set window position with verify-and-retry loop
    /// Returns the actual achieved position and number of attempts made
    private func setPositionWithRetry(_ axWindow: AXUIElement, targetPosition: CGPoint, maxAttempts: Int) -> (actualPosition: CGPoint, attempts: Int) {
        var actualPosition = CGPoint.zero

        for attempt in 1...maxAttempts {
            var position = targetPosition
            if let posValue = AXValueCreate(.cgPoint, &position) {
                AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, posValue)
            }

            // Wait for the window to actually move
            usleep(30000)

            // Read back the actual position
            actualPosition = readWindowState(axWindow).position

            // Check if we achieved the target position using ResizeStateChecker
            if ResizeStateChecker.isPositionOK(actual: actualPosition, target: targetPosition) {
                return (actualPosition, attempt)
            }

            // Wait a bit more before retry
            if attempt < maxAttempts {
                usleep(20000)
            }
        }

        return (actualPosition, maxAttempts)
    }

    /// Convert AXError to readable string
    private func axErrorString(_ error: AXError) -> String {
        switch error {
        case .success: return "success"
        case .failure: return "failure"
        case .illegalArgument: return "illegalArgument"
        case .invalidUIElement: return "invalidUIElement"
        case .invalidUIElementObserver: return "invalidUIElementObserver"
        case .cannotComplete: return "cannotComplete"
        case .attributeUnsupported: return "attributeUnsupported"
        case .actionUnsupported: return "actionUnsupported"
        case .notificationUnsupported: return "notificationUnsupported"
        case .notImplemented: return "notImplemented"
        case .notificationAlreadyRegistered: return "notificationAlreadyRegistered"
        case .notificationNotRegistered: return "notificationNotRegistered"
        case .apiDisabled: return "apiDisabled"
        case .noValue: return "noValue"
        case .parameterizedAttributeUnsupported: return "parameterizedAttributeUnsupported"
        case .notEnoughPrecision: return "notEnoughPrecision"
        @unknown default: return "unknown(\(error.rawValue))"
        }
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

    /// Find which screen contains a given point (in NSScreen coordinates)
    private func screenContaining(point: CGPoint) -> NSScreen? {
        for screen in NSScreen.screens {
            if screen.frame.contains(point) {
                return screen
            }
        }
        // If point is not in any screen (e.g., between monitors), find closest screen
        var closestScreen: NSScreen?
        var closestDistance = CGFloat.greatestFiniteMagnitude

        for screen in NSScreen.screens {
            let screenCenter = CGPoint(
                x: screen.frame.midX,
                y: screen.frame.midY
            )
            let distance = hypot(point.x - screenCenter.x, point.y - screenCenter.y)
            if distance < closestDistance {
                closestDistance = distance
                closestScreen = screen
            }
        }
        return closestScreen
    }

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
        // Use primary screen height as AX coordinates are relative to the primary display
        let convertedY = primaryScreenHeight - position.y - size.height

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
