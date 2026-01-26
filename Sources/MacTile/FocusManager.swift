import AppKit
import MacTileCore

/// Manages application focus switching and window cycling
class FocusManager {
    static let shared = FocusManager()

    private init() {}

    /// Get all windows for a specific app bundle ID, ordered by window layer (front to back)
    /// Returns array of (windowID, windowTitle, ownerPID) tuples
    func getWindowsForApp(bundleID: String) -> [(windowID: CGWindowID, title: String, pid: pid_t)] {
        // Find running app with this bundle ID
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == bundleID && $0.activationPolicy == .regular
        }) else {
            print("[FocusManager] No running app found for bundle ID: \(bundleID)")
            return []
        }

        let pid = app.processIdentifier

        // Get all windows using CGWindowListCopyWindowInfo
        // This returns windows in front-to-back order (window layer order)
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            print("[FocusManager] Failed to get window list")
            return []
        }

        var windows: [(windowID: CGWindowID, title: String, pid: pid_t)] = []

        for windowInfo in windowList {
            guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid,
                  let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let windowLayer = windowInfo[kCGWindowLayer as String] as? Int,
                  windowLayer == 0  // Normal window layer (not menu bar, dock, etc.)
            else {
                continue
            }

            let title = windowInfo[kCGWindowName as String] as? String ?? "Untitled"

            // Skip windows with empty titles (often utility windows)
            if !title.isEmpty {
                windows.append((windowID: windowID, title: title, pid: ownerPID))
            }
        }

        print("[FocusManager] Found \(windows.count) windows for \(bundleID): \(windows.map { $0.title })")
        return windows
    }

    /// Focus the next window of the specified app
    /// If no window of that app is focused, focuses the frontmost window
    /// If a window of that app is already focused, cycles to the next one
    /// - Parameters:
    ///   - bundleID: The bundle identifier of the target app
    ///   - forceCycle: If true, skip the frontmost check and always cycle windows.
    ///                 Use this when calling from overlay where the app appears not-frontmost
    ///                 but was actually focused before the overlay appeared.
    ///   - openIfNotRunning: If true and the app is not running, launch it.
    /// Returns true if successful
    @discardableResult
    func focusNextWindow(forBundleID bundleID: String, forceCycle: Bool = false, openIfNotRunning: Bool = false) -> Bool {
        // Find running app
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == bundleID && $0.activationPolicy == .regular
        }) else {
            print("[FocusManager] No running app found for bundle ID: \(bundleID)")

            // If openIfNotRunning is enabled, try to launch the app
            if openIfNotRunning {
                return launchApp(bundleID: bundleID)
            }
            return false
        }

        let pid = app.processIdentifier

        // Check if this app is already frontmost (unless forceCycle is set)
        let isFrontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID

        if !isFrontmost && !forceCycle {
            // App is not frontmost - just activate it (will show frontmost window)
            print("[FocusManager] Activating app: \(bundleID)")
            app.activate(options: [.activateIgnoringOtherApps])
            return true
        }

        if forceCycle {
            print("[FocusManager] Force cycling enabled for \(bundleID)")
        }

        // App is already frontmost - cycle to next window using AX API
        // AX windows are in Z-order (front to back), so to cycle we raise the second window
        let appElement = AXUIElementCreateApplication(pid)

        var windowListRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowListRef) == .success,
              let axWindows = windowListRef as? [AXUIElement] else {
            print("[FocusManager] No AX windows for \(bundleID)")
            return true
        }

        // Filter to only include "standard" windows that have a close button.
        // This excludes special windows like Finder's Desktop, which appears as an AXWindow
        // but cannot be raised/cycled in the normal sense.
        let cyclableWindows = axWindows.filter { window in
            var closeButtonRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &closeButtonRef)
            return result == .success && closeButtonRef != nil
        }

        guard cyclableWindows.count > 1 else {
            print("[FocusManager] Only \(cyclableWindows.count) cyclable window(s) for \(bundleID) (filtered from \(axWindows.count) total), nothing to cycle")
            return true
        }

        print("[FocusManager] Found \(cyclableWindows.count) cyclable windows for \(bundleID) (from \(axWindows.count) total), cycling to next")

        // Raise the LAST window - this properly cycles through all windows
        // AX windows are in Z-order: [front, ..., back]
        // By raising the back-most window, we cycle: A,B,C -> C,A,B -> B,C,A -> A,B,C
        // This works correctly for any number of windows (2, 3, or more)
        let targetWindow = cyclableWindows[cyclableWindows.count - 1]

        // Get target window title for logging
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(targetWindow, kAXTitleAttribute as CFString, &titleRef)
        let title = titleRef as? String ?? "Untitled"
        print("[FocusManager] Raising window: '\(title)'")

        // Raise the window
        AXUIElementPerformAction(targetWindow, kAXRaiseAction as CFString)

        // Also set it as main window
        AXUIElementSetAttributeValue(targetWindow, kAXMainAttribute as CFString, kCFBooleanTrue)

        // Activate the app to ensure it receives keyboard focus
        // This is essential when called with forceCycle (from overlay) since MacTile was frontmost
        app.activate(options: [.activateIgnoringOtherApps])

        return true
    }

    /// Get list of running regular applications (for UI picker)
    func getRunningApps() -> [(bundleID: String, name: String)] {
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .compactMap { app -> (bundleID: String, name: String)? in
                guard let bundleID = app.bundleIdentifier else { return nil }
                return (bundleID: bundleID, name: app.localizedName ?? bundleID)
            }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// Launch an application by its bundle ID
    /// Returns true if the launch was initiated successfully
    @discardableResult
    private func launchApp(bundleID: String) -> Bool {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            print("[FocusManager] Could not find app URL for bundle ID: \(bundleID)")
            return false
        }

        print("[FocusManager] Launching app: \(bundleID)")

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { app, error in
            if let error = error {
                print("[FocusManager] Failed to launch app: \(error.localizedDescription)")
            } else if let app = app {
                print("[FocusManager] Successfully launched: \(app.localizedName ?? bundleID)")
            }
        }

        return true
    }
}
