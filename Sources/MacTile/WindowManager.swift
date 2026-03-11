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
    ///
    /// Uses AeroSpace-inspired approach:
    /// - Disables animations via AXEnhancedUserInterface before frame changes
    /// - Uses Size → Position → Size order to handle macOS AX quirks
    /// - No synchronous delays between AX calls (fire-and-forget like AeroSpace)
    /// - For cross-monitor: shrinks first to bypass browser visibility protection,
    ///   then applies Size → Position → Size on target monitor
    /// - Correction loop runs as safety net (should rarely be needed)
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

        // Disable animations (AeroSpace technique: toggle AXEnhancedUserInterface)
        // This suppresses macOS window animations during move/resize for instant visual feedback
        let appElement = getAppElement(for: axWindow)
        let animationsWereEnabled = disableAnimations(appElement: appElement)
        defer { restoreAnimations(appElement: appElement, wasEnabled: animationsWereEnabled) }

        // STRATEGY depends on whether this is a cross-monitor move
        // Both strategies use AeroSpace's Size → Position → Size order for the final placement

        if isCrossMonitorMove {
            // CROSS-MONITOR STRATEGY: Shrink window, move to target monitor, then Size → Position → Size
            // Browsers refuse to move large windows "mostly off-screen", but small windows
            // will move freely. By shrinking first, we ensure the move succeeds.
            //
            // Note: AX calls are serialized per-app at the accessibility server level,
            // so the shrink will be processed before the move even without explicit delays.

            print("[WindowManager] Using cross-monitor strategy: shrink, move, then Size→Position→Size")

            // Step 1: Shrink window to a small size that will fit anywhere
            // Use min of 400/300 and target to avoid growing the window if target is already small
            let smallSize = CGSize(width: min(400, targetSize.width), height: min(300, targetSize.height))
            print("[WindowManager] Step 1: Shrinking to intermediate size \(smallSize)")
            setWindowSize(axWindow, size: smallSize)

            // Step 2: Move to target position (small window will move freely across monitors)
            print("[WindowManager] Step 2: Moving to target position \(targetPosition)")
            setWindowPosition(axWindow, position: targetPosition)

            // Step 3: Apply Size → Position → Size (AeroSpace pattern) for final placement
            print("[WindowManager] Step 3: Size→Position→Size for final placement")
            setWindowSize(axWindow, size: targetSize)
            setWindowPosition(axWindow, position: targetPosition)
            setWindowSize(axWindow, size: targetSize)

        } else {
            // SAME-SCREEN STRATEGY: Direct Size → Position → Size (AeroSpace pattern)
            // No safe-move needed — the S→P→S order handles edge-anchoring

            print("[WindowManager] Using same-screen strategy: Size→Position→Size")

            setWindowSize(axWindow, size: targetSize)
            setWindowPosition(axWindow, position: targetPosition)
            setWindowSize(axWindow, size: targetSize)
        }

        // Quick synchronous check — did it land correctly?
        let immediateState = readWindowState(axWindow)
        let positionOKImmediate = ResizeStateChecker.isPositionOK(actual: immediateState.position, target: targetPosition)
        let sizeOKImmediate = ResizeStateChecker.isSizeOK(actual: immediateState.size, target: targetSize)
        let sizeAcceptableImmediate = sizeOKImmediate || ResizeStateChecker.isMinimumConstraint(actual: immediateState.size, target: targetSize)

        if positionOKImmediate && sizeAcceptableImmediate {
            print("[WindowManager] ✓ Window frame set successfully (no correction needed)")
            print("[WindowManager] FINAL - Position: \(immediateState.position), Size: \(immediateState.size)")
            print("[WindowManager] ═══════════════════════════════════════════════")
            return true
        }

        print("[WindowManager] Initial placement needs correction, starting correction loop")
        print("[WindowManager]   Current: pos=\(immediateState.position), size=\(immediateState.size)")

        // Correction loop — safety net for apps that don't respond instantly
        // This should rarely be needed with animation disabling + S→P→S order
        let correctionResult = runCorrectionLoop(axWindow, targetPosition: targetPosition, targetSize: targetSize)

        print("[WindowManager] ═══════════════════════════════════════════════")

        return correctionResult
    }

    // MARK: - Animation Control (AeroSpace technique)

    /// Get the app-level AXUIElement for a window (needed for AXEnhancedUserInterface)
    private func getAppElement(for axWindow: AXUIElement) -> AXUIElement? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(axWindow, &pid) == .success else {
            return nil
        }
        return AXUIElementCreateApplication(pid)
    }

    /// Disable window animations by setting AXEnhancedUserInterface to false
    /// Returns whether animations were previously enabled (so we can restore)
    private func disableAnimations(appElement: AXUIElement?) -> Bool {
        guard let app = appElement else { return false }

        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, "AXEnhancedUserInterface" as CFString, &value)
        let wasEnabled = (result == .success) && (value as? Bool == true)

        if wasEnabled {
            AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse)
            print("[WindowManager] Disabled AXEnhancedUserInterface for snappy positioning")
        }

        return wasEnabled
    }

    /// Restore animations if they were previously enabled
    private func restoreAnimations(appElement: AXUIElement?, wasEnabled: Bool) {
        guard let app = appElement, wasEnabled else { return }
        AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        print("[WindowManager] Restored AXEnhancedUserInterface")
    }

    // MARK: - AX Attribute Helpers (no delays, fire-and-forget like AeroSpace)

    private func setWindowSize(_ axWindow: AXUIElement, size: CGSize) {
        var s = size
        if let sizeValue = AXValueCreate(.cgSize, &s) {
            AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, sizeValue)
        }
    }

    private func setWindowPosition(_ axWindow: AXUIElement, position: CGPoint) {
        var p = position
        if let posValue = AXValueCreate(.cgPoint, &p) {
            AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, posValue)
        }
    }

    // MARK: - Correction Loop (safety net)

    /// Runs a correction loop as a safety net. Should rarely be needed with animation
    /// disabling + Size→Position→Size order. Returns whether final state is acceptable.
    private func runCorrectionLoop(_ axWindow: AXUIElement, targetPosition: CGPoint, targetSize: CGSize) -> Bool {
        let maxCorrectionAttempts = 10
        var positionOK = false
        var sizeOK = false
        // Initialize lastState to a sentinel so the first iteration never counts as "stuck"
        var lastState: (position: CGPoint, size: CGSize) = (CGPoint(x: -1, y: -1), CGSize(width: -1, height: -1))
        var stuckCount = 0

        for attempt in 1...maxCorrectionAttempts {
            let state = readWindowState(axWindow)

            // Bail out if AX reads are failing (window may have closed)
            if state.size == .zero {
                print("[WindowManager]   Correction attempt \(attempt): AX read returned zero size, window may be gone")
                return false
            }

            positionOK = ResizeStateChecker.isPositionOK(actual: state.position, target: targetPosition)
            sizeOK = ResizeStateChecker.isSizeOK(actual: state.size, target: targetSize)

            if positionOK && sizeOK {
                print("[WindowManager]   Correction attempt \(attempt): Both position and size OK")
                break
            }

            // Check if we're stuck - same state as last attempt
            if state.position == lastState.position && state.size == lastState.size {
                stuckCount += 1
                if stuckCount >= 3 {
                    if ResizeStateChecker.isMinimumConstraint(actual: state.size, target: targetSize) {
                        print("[WindowManager]   Correction attempt \(attempt): Stuck at minimum constraint (w:\(state.size.width) vs \(targetSize.width), h:\(state.size.height) vs \(targetSize.height))")
                        sizeOK = true
                        break
                    } else {
                        print("[WindowManager]   Correction attempt \(attempt): Stuck (no progress for \(stuckCount) attempts), stopping")
                        break
                    }
                }
            } else {
                stuckCount = 0
            }
            lastState = state

            print("[WindowManager]   Correction attempt \(attempt): pos=\(state.position) (ok=\(positionOK)), size=\(state.size) (ok=\(sizeOK))")

            // Apply Size → Position → Size correction pattern
            setWindowSize(axWindow, size: targetSize)
            usleep(30000) // 30ms — delay in the correction loop to let AX settle
            setWindowPosition(axWindow, position: targetPosition)
            usleep(25000)
            setWindowSize(axWindow, size: targetSize)
            usleep(25000)
        }

        // Read final state
        let finalState = readWindowState(axWindow)
        positionOK = ResizeStateChecker.isPositionOK(actual: finalState.position, target: targetPosition)
        sizeOK = ResizeStateChecker.isSizeOK(actual: finalState.size, target: targetSize)

        print("[WindowManager] FINAL - Position: \(finalState.position), Size: \(finalState.size)")

        if !positionOK {
            print("[WindowManager] ⚠️  Position mismatch! Target: \(targetPosition), Actual: \(finalState.position)")
            print("[WindowManager]     Delta: x=\(finalState.position.x - targetPosition.x), y=\(finalState.position.y - targetPosition.y)")
        }
        if !sizeOK {
            if finalState.size.width > targetSize.width {
                print("[WindowManager] ⚠️  Size mismatch (likely minimum window size constraint)")
                print("[WindowManager]     App minimum width appears to be: \(finalState.size.width)")
            } else {
                print("[WindowManager] ⚠️  Size mismatch! Target: \(targetSize), Actual: \(finalState.size)")
            }
            print("[WindowManager]     Delta: w=\(finalState.size.width - targetSize.width), h=\(finalState.size.height - targetSize.height)")
        }
        if positionOK && sizeOK {
            print("[WindowManager] ✓ Window frame set successfully (after correction)")
        }

        let sizeAcceptable = sizeOK || ResizeStateChecker.isMinimumConstraint(actual: finalState.size, target: targetSize)
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
