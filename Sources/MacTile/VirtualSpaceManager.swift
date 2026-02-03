import AppKit
import MacTileCore

/// Protocol for virtual space manager delegate
protocol VirtualSpaceManagerDelegate: AnyObject {
    func virtualSpaceDidBecomeActive(_ space: VirtualSpace, forMonitor displayID: UInt32)
    func virtualSpaceDidBecomeInactive(forMonitor displayID: UInt32)
}

/// Manages virtual spaces for window arrangements
class VirtualSpaceManager {
    static let shared = VirtualSpaceManager()

    /// Delegate for UI updates
    weak var delegate: VirtualSpaceManagerDelegate?

    /// Active space per monitor (display ID -> space number, nil if none active)
    private var activeSpaces: [UInt32: Int] = [:]

    /// Windows that are part of the active space per monitor (for tracking deactivation)
    private var activeSpaceWindows: [UInt32: Set<WindowIdentifier>] = [:]

    /// Observer for app activation changes
    private var focusObserver: Any?

    /// Timer for checking window changes
    private var windowCheckTimer: Timer?

    /// Last known window frames for detecting resizes
    private var lastKnownFrames: [UInt32: [WindowIdentifier: CGRect]] = [:]

    private init() {}

    deinit {
        stopMonitoring()
    }

    // MARK: - Coordinate System Helpers

    /// Get the height of the primary screen (the screen with the menu bar).
    /// This is used for coordinate conversions between:
    /// - CGWindowList/AX API (top-left origin)
    /// - NSScreen/Cocoa (bottom-left origin)
    /// NSScreen.screens[0] is documented to always be the screen containing the menu bar.
    private var primaryScreenHeight: CGFloat {
        // NSScreen.screens[0] is always the primary (menu bar) screen per Apple docs
        guard !NSScreen.screens.isEmpty else { return 0 }
        return NSScreen.screens[0].frame.height
    }

    // MARK: - Public API

    /// Save the current monitor's visible windows to a virtual space
    func saveToSpace(number: Int, forMonitor displayID: UInt32) {
        print("[VirtualSpaces] Saving to space \(number) for monitor \(displayID)")

        // Capture topmost windows on this monitor
        let windows = captureTopmostWindows(forMonitor: displayID)
        print("[VirtualSpaces] Captured \(windows.count) windows")

        // Create the virtual space
        let space = VirtualSpace(
            number: number,
            name: getExistingSpaceName(number: number, displayID: displayID),
            windows: windows,
            displayID: displayID
        )

        // Save to settings (using quiet save to avoid triggering hotkey re-registration)
        var storage = SettingsManager.shared.settings.virtualSpaces
        storage.setSpace(space, displayID: displayID)
        SettingsManager.shared.saveVirtualSpacesQuietly(storage)

        // Mark this space as active
        activateSpace(space, forMonitor: displayID)

        print("[VirtualSpaces] Space \(number) saved with \(windows.count) windows")
    }

    /// Restore windows from a virtual space
    func restoreFromSpace(number: Int, forMonitor displayID: UInt32) {
        print("[VirtualSpaces] Restoring from space \(number) for monitor \(displayID)")

        guard let space = SettingsManager.shared.settings.virtualSpaces.getSpace(displayID: displayID, number: number) else {
            print("[VirtualSpaces] Space \(number) not found for monitor \(displayID)")
            return
        }

        guard !space.isEmpty else {
            print("[VirtualSpaces] Space \(number) is empty")
            return
        }

        // Restore windows
        restoreWindows(from: space)

        // Mark this space as active
        activateSpace(space, forMonitor: displayID)

        print("[VirtualSpaces] Space \(number) restored")
    }

    /// Rename the active virtual space for a monitor
    func renameActiveSpace(name: String, forMonitor displayID: UInt32) {
        guard let spaceNumber = activeSpaces[displayID],
              var space = SettingsManager.shared.settings.virtualSpaces.getSpace(displayID: displayID, number: spaceNumber) else {
            print("[VirtualSpaces] No active space to rename")
            return
        }

        space.name = name.isEmpty ? nil : name

        var storage = SettingsManager.shared.settings.virtualSpaces
        storage.setSpace(space, displayID: displayID)
        SettingsManager.shared.saveVirtualSpacesQuietly(storage)

        // Notify delegate of updated space
        delegate?.virtualSpaceDidBecomeActive(space, forMonitor: displayID)

        print("[VirtualSpaces] Renamed space \(spaceNumber) to '\(name)'")
    }

    /// Get the active virtual space for a monitor
    func getActiveSpace(forMonitor displayID: UInt32) -> VirtualSpace? {
        guard let spaceNumber = activeSpaces[displayID] else {
            return nil
        }
        return SettingsManager.shared.settings.virtualSpaces.getSpace(displayID: displayID, number: spaceNumber)
    }

    /// Deactivate the virtual space for a monitor
    func deactivateSpace(forMonitor displayID: UInt32) {
        guard activeSpaces[displayID] != nil else { return }

        print("[VirtualSpaces] Deactivating space for monitor \(displayID)")
        activeSpaces.removeValue(forKey: displayID)
        activeSpaceWindows.removeValue(forKey: displayID)
        lastKnownFrames.removeValue(forKey: displayID)

        // Stop monitoring if no active spaces left
        if activeSpaces.isEmpty {
            stopMonitoring()
        }

        delegate?.virtualSpaceDidBecomeInactive(forMonitor: displayID)
    }

    /// Check if any virtual space is active for a monitor
    func isSpaceActive(forMonitor displayID: UInt32) -> Bool {
        return activeSpaces[displayID] != nil
    }

    // MARK: - Window Capture

    /// Capture the topmost visible windows on a monitor
    private func captureTopmostWindows(forMonitor displayID: UInt32) -> [VirtualSpaceWindow] {
        // Get monitor bounds
        guard let screen = screenForDisplayID(displayID) else {
            print("[VirtualSpaces] Could not find screen for display ID \(displayID)")
            return []
        }

        // Get all windows in z-order using CGWindowListCopyWindowInfo
        let windowListOptions: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(windowListOptions, kCGNullWindowID) as? [[String: Any]] else {
            print("[VirtualSpaces] Failed to get window list")
            return []
        }

        var capturedWindows: [VirtualSpaceWindow] = []
        var zIndex = 0

        for windowInfo in windowList {
            // Skip windows not on the target monitor
            guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"] else {
                continue
            }

            // CGWindowList uses top-left origin coordinates (origin at top-left of primary screen)
            // Convert to NSScreen coordinates (bottom-left origin, origin at bottom-left of primary screen)
            // This conversion works for ALL screens because both coordinate systems use the primary screen as reference
            let windowFrame = CGRect(
                x: x,
                y: self.primaryScreenHeight - y - height,
                width: width,
                height: height
            )

            // Check if window center is on our target monitor
            let windowCenter = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
            guard screen.frame.contains(windowCenter) else {
                continue
            }

            // Get window layer (0 = normal window)
            guard let layer = windowInfo[kCGWindowLayer as String] as? Int,
                  layer == 0 else {
                continue
            }

            // Get process ID and bundle ID
            guard let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t else {
                continue
            }

            guard let app = NSRunningApplication(processIdentifier: pid),
                  let bundleID = app.bundleIdentifier else {
                continue
            }

            // Get window title
            let windowTitle = windowInfo[kCGWindowName as String] as? String ?? ""

            // Skip windows without titles (often internal/system windows)
            // But allow empty titles from some apps that don't set window names
            if windowTitle.isEmpty {
                // Check if this app has at least one other window with a title
                // to determine if this is a "real" window
                let hasOtherTitledWindow = windowList.contains { info in
                    let infoPid = info[kCGWindowOwnerPID as String] as? pid_t
                    let infoTitle = info[kCGWindowName as String] as? String ?? ""
                    return infoPid == pid && !infoTitle.isEmpty
                }

                // Skip if app has titled windows (this is likely a utility window)
                if hasOtherTitledWindow {
                    continue
                }
            }

            // Skip MacTile's own windows
            if bundleID == Bundle.main.bundleIdentifier {
                continue
            }

            let spaceWindow = VirtualSpaceWindow(
                appBundleID: bundleID,
                windowTitle: windowTitle,
                frame: windowFrame,
                zIndex: zIndex
            )
            capturedWindows.append(spaceWindow)
            zIndex += 1
        }

        // Filter windows by visibility - only keep windows that are at least 40% visible
        let filteredWindows = filterWindowsByVisibility(capturedWindows, minimumVisibility: 40.0)
        print("[VirtualSpaces] Filtered \(capturedWindows.count) windows to \(filteredWindows.count) visible windows")

        return filteredWindows
    }

    /// Filter windows to only include those with sufficient visibility
    /// A window is considered visible if at least `minimumVisibility`% of its area
    /// is not covered by windows in front of it (lower zIndex)
    private func filterWindowsByVisibility(_ windows: [VirtualSpaceWindow], minimumVisibility: CGFloat) -> [VirtualSpaceWindow] {
        var visibleWindows: [VirtualSpaceWindow] = []

        for window in windows {
            // Get frames of all windows in front of this one (lower zIndex = in front)
            let occluders = windows
                .filter { $0.zIndex < window.zIndex }
                .map { $0.frame }

            let visibility = VisibilityCalculator.calculateVisibilityPercentage(
                of: window.frame,
                occludedBy: occluders
            )

            if visibility >= minimumVisibility {
                visibleWindows.append(window)
                print("[VirtualSpaces]   ✓ \(window.appBundleID) '\(window.windowTitle)' - \(Int(visibility))% visible")
            } else {
                print("[VirtualSpaces]   ✗ \(window.appBundleID) '\(window.windowTitle)' - \(Int(visibility))% visible (filtered out)")
            }
        }

        return visibleWindows
    }

    // MARK: - Window Restoration

    /// Restore windows from a virtual space
    /// Uses a phased approach to ensure all windows are properly restored:
    /// 1. Position all windows (without activating apps)
    /// 2. Activate apps in z-order (bottom-most first) to establish correct Alt+Tab order
    /// 3. Raise windows within each app and focus the topmost
    private func restoreWindows(from space: VirtualSpace) {
        print("[VirtualSpaces] Restoring \(space.windows.count) windows")

        // Build a list of found windows with their AX elements
        var foundWindows: [(spaceWindow: VirtualSpaceWindow, axWindow: AXUIElement, pid: pid_t)] = []

        for spaceWindow in space.windows {
            if let (axWindow, pid) = findWindow(matching: spaceWindow) {
                foundWindows.append((spaceWindow, axWindow, pid))
            } else {
                print("[VirtualSpaces] Could not find window: \(spaceWindow.appBundleID) - '\(spaceWindow.windowTitle)'")
            }
        }

        guard !foundWindows.isEmpty else {
            print("[VirtualSpaces] No windows found to restore")
            return
        }

        // Phase 1: Position all windows (just set frames, no raising or activation)
        print("[VirtualSpaces] Phase 1: Positioning \(foundWindows.count) windows")
        for (spaceWindow, axWindow, _) in foundWindows {
            setWindowFrame(axWindow, frame: spaceWindow.frame)
        }

        // Phase 2: Group windows by app and activate apps in z-order
        // Higher zIndex = further back, so we activate those apps first
        // This establishes the correct Alt+Tab order (last activated = first in Alt+Tab)
        var windowsByApp: [String: [(spaceWindow: VirtualSpaceWindow, axWindow: AXUIElement, pid: pid_t)]] = [:]
        for window in foundWindows {
            windowsByApp[window.spaceWindow.appBundleID, default: []].append(window)
        }

        // Sort apps by their highest zIndex (most-to-back app first)
        // We want to activate background apps first, foreground apps last
        let sortedApps = windowsByApp.sorted { app1, app2 in
            let maxZ1 = app1.value.map { $0.spaceWindow.zIndex }.max() ?? 0
            let maxZ2 = app2.value.map { $0.spaceWindow.zIndex }.max() ?? 0
            return maxZ1 > maxZ2  // Higher zIndex (more to back) first
        }

        print("[VirtualSpaces] Phase 2: Activating \(sortedApps.count) apps in z-order")

        for (bundleID, appWindows) in sortedApps {
            guard let pid = appWindows.first?.pid else { continue }

            // Activate the app
            if let app = NSRunningApplication(processIdentifier: pid) {
                print("[VirtualSpaces]   Activating \(bundleID)")
                app.activate(options: [.activateIgnoringOtherApps])

                // Small delay to let activation take effect
                // This is needed because activation is asynchronous
                Thread.sleep(forTimeInterval: 0.05)  // 50ms
            }

            // Raise windows for this app in z-order (back to front within the app)
            // So the frontmost window of this app ends up on top
            let sortedAppWindows = appWindows.sorted { $0.spaceWindow.zIndex > $1.spaceWindow.zIndex }
            for (_, axWindow, _) in sortedAppWindows {
                AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
            }
        }

        // Phase 3: Final focus on the topmost window (zIndex 0)
        print("[VirtualSpaces] Phase 3: Focusing topmost window")
        if let topmostWindow = foundWindows.first(where: { $0.spaceWindow.zIndex == 0 }) {
            if let app = NSRunningApplication(processIdentifier: topmostWindow.pid) {
                app.activate(options: [.activateIgnoringOtherApps])
            }
            // Raise and focus the specific window
            AXUIElementPerformAction(topmostWindow.axWindow, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(topmostWindow.axWindow, kAXMainAttribute as CFString, true as CFTypeRef)
            AXUIElementSetAttributeValue(topmostWindow.axWindow, kAXFocusedAttribute as CFString, true as CFTypeRef)
        }

        print("[VirtualSpaces] Restore complete")
    }

    /// Find a window matching the saved window info
    private func findWindow(matching spaceWindow: VirtualSpaceWindow) -> (AXUIElement, pid_t)? {
        // Find the app by bundle ID
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == spaceWindow.appBundleID && $0.activationPolicy == .regular
        }) else {
            return nil
        }

        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var windowList: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowList) == .success,
              let windows = windowList as? [AXUIElement] else {
            return nil
        }

        // Try to find by title first
        for axWindow in windows {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef)
            let title = titleRef as? String ?? ""

            if title == spaceWindow.windowTitle {
                return (axWindow, pid)
            }
        }

        // If no exact title match, try to find by position (closest to saved frame)
        var closestWindow: AXUIElement?
        var closestDistance = CGFloat.greatestFiniteMagnitude

        for axWindow in windows {
            let frame = getWindowFrame(axWindow)
            let distance = abs(frame.origin.x - spaceWindow.frame.origin.x) +
                          abs(frame.origin.y - spaceWindow.frame.origin.y)

            if distance < closestDistance {
                closestDistance = distance
                closestWindow = axWindow
            }
        }

        if let window = closestWindow, closestDistance < 100 {
            return (window, pid)
        }

        // Fall back to first window if only one window
        if windows.count == 1 {
            return (windows[0], pid)
        }

        return nil
    }

    /// Get the current frame of an AX window
    private func getWindowFrame(_ axWindow: AXUIElement) -> CGRect {
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

        // Convert from AX coordinates (top-left origin) to screen coordinates (bottom-left origin)
        // Both coordinate systems use the primary screen as reference, so this works for all monitors
        let convertedY = self.primaryScreenHeight - position.y - size.height

        return CGRect(x: position.x, y: convertedY, width: size.width, height: size.height)
    }

    /// Set the frame of an AX window
    private func setWindowFrame(_ axWindow: AXUIElement, frame: CGRect) {
        // Convert from screen coordinates (bottom-left origin) to AX coordinates (top-left origin)
        // Both coordinate systems use the primary screen as reference, so this works for all monitors
        let axY = self.primaryScreenHeight - frame.origin.y - frame.height

        var position = CGPoint(x: frame.origin.x, y: axY)
        var size = CGSize(width: frame.width, height: frame.height)

        if let posValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, posValue)
        }

        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, sizeValue)
        }
    }

    // MARK: - Active State Management

    /// Mark a space as active and start monitoring
    private func activateSpace(_ space: VirtualSpace, forMonitor displayID: UInt32) {
        activeSpaces[displayID] = space.number

        // Track windows in this space
        var windowIdentifiers: Set<WindowIdentifier> = []
        for window in space.windows {
            windowIdentifiers.insert(WindowIdentifier(
                bundleID: window.appBundleID,
                title: window.windowTitle,
                zIndex: window.zIndex,
                pid: nil
            ))
        }
        activeSpaceWindows[displayID] = windowIdentifiers

        // Store current frames for resize detection
        var frames: [WindowIdentifier: CGRect] = [:]
        for window in space.windows {
            let identifier = WindowIdentifier(bundleID: window.appBundleID, title: window.windowTitle, zIndex: window.zIndex, pid: nil)
            frames[identifier] = window.frame
        }
        lastKnownFrames[displayID] = frames

        // Start monitoring for deactivation
        startMonitoring()

        // Notify delegate
        delegate?.virtualSpaceDidBecomeActive(space, forMonitor: displayID)
    }

    /// Start monitoring for deactivation triggers
    private func startMonitoring() {
        // Only set up observers once
        if focusObserver != nil { return }

        // Monitor for app activation changes
        focusObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivation(notification)
        }

        // Start timer to check for window changes
        windowCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForWindowChanges()
        }
    }

    /// Stop monitoring
    private func stopMonitoring() {
        if let observer = focusObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            focusObserver = nil
        }

        windowCheckTimer?.invalidate()
        windowCheckTimer = nil
    }

    /// Handle app activation notification
    private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier else {
            return
        }

        // Check each active space to see if the focused app is part of it
        for (displayID, _) in activeSpaces {
            guard let windowIdentifiers = activeSpaceWindows[displayID] else { continue }

            let isInSpace = windowIdentifiers.contains { $0.bundleID == bundleID }

            if !isInSpace {
                // Focused window is not in the active space - deactivate
                print("[VirtualSpaces] Focus changed to app not in space: \(bundleID)")
                deactivateSpace(forMonitor: displayID)
            }
        }
    }

    /// Check for window changes (resize/move)
    private func checkForWindowChanges() {
        for (displayID, spaceNumber) in activeSpaces {
            guard let space = SettingsManager.shared.settings.virtualSpaces.getSpace(displayID: displayID, number: spaceNumber),
                  let lastFrames = lastKnownFrames[displayID] else {
                continue
            }

            for window in space.windows {
                let identifier = WindowIdentifier(bundleID: window.appBundleID, title: window.windowTitle, zIndex: window.zIndex, pid: nil)

                guard let (axWindow, _) = findWindow(matching: window),
                      let lastFrame = lastFrames[identifier] else {
                    continue
                }

                let currentFrame = getWindowFrame(axWindow)

                // Check if frame changed significantly
                let frameChanged = abs(currentFrame.origin.x - lastFrame.origin.x) > 20 ||
                                   abs(currentFrame.origin.y - lastFrame.origin.y) > 20 ||
                                   abs(currentFrame.width - lastFrame.width) > 20 ||
                                   abs(currentFrame.height - lastFrame.height) > 20

                if frameChanged {
                    print("[VirtualSpaces] Window frame changed: \(window.appBundleID)")
                    deactivateSpace(forMonitor: displayID)
                    break
                }
            }
        }
    }

    // MARK: - Helpers

    /// Get existing space name if any
    private func getExistingSpaceName(number: Int, displayID: UInt32) -> String? {
        return SettingsManager.shared.settings.virtualSpaces.getSpace(displayID: displayID, number: number)?.name
    }

    /// Get NSScreen for a display ID
    private func screenForDisplayID(_ displayID: UInt32) -> NSScreen? {
        return NSScreen.screens.first { screen in
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }
            return screenNumber.uint32Value == displayID
        }
    }

    /// Get display ID for an NSScreen
    static func displayID(for screen: NSScreen) -> UInt32 {
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return 0
        }
        return screenNumber.uint32Value
    }

    /// Get the display ID of the screen containing the given point
    static func displayIDForPoint(_ point: CGPoint) -> UInt32 {
        for screen in NSScreen.screens {
            if screen.frame.contains(point) {
                return displayID(for: screen)
            }
        }
        // Default to main screen
        return displayID(for: NSScreen.main ?? NSScreen.screens[0])
    }
}

// MARK: - Window Identifier

/// Identifier for tracking windows
/// Uses bundleID + title + zIndex to uniquely identify windows,
/// handling cases where multiple windows from the same app have the same title
struct WindowIdentifier: Hashable {
    let bundleID: String
    let title: String
    let zIndex: Int
    let pid: pid_t?

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleID)
        hasher.combine(title)
        hasher.combine(zIndex)
    }

    static func == (lhs: WindowIdentifier, rhs: WindowIdentifier) -> Bool {
        return lhs.bundleID == rhs.bundleID && lhs.title == rhs.title && lhs.zIndex == rhs.zIndex
    }
}
