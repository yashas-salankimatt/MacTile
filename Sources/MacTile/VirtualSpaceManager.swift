import AppKit
import MacTileCore
import Darwin

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

    /// Throttle layout matching checks per monitor
    private var lastLayoutCheck: [UInt32: Date] = [:]
    private let layoutCheckInterval: TimeInterval = 0.3
    private let layoutCheckDelay: TimeInterval = 0.1
    private var pendingLayoutChecks: [UInt32: DispatchWorkItem] = [:]
    private var debugLoggingEnabled: Bool {
        ProcessInfo.processInfo.environment["MACTILE_VS_DEBUG"] == "1"
    }
    private var didLogPrivateAXSuccess = false
    private var didLogPrivateAXFallback = false
    private typealias AXUIElementGetWindowFunc = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    private lazy var axGetWindowFunc: AXUIElementGetWindowFunc? = {
        let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2) // RTLD_DEFAULT
        guard let symbol = dlsym(rtldDefault, "_AXUIElementGetWindow") else {
            return nil
        }
        return unsafeBitCast(symbol, to: AXUIElementGetWindowFunc.self)
    }()

    private init() {
        ensureActivationObserver()
    }

    deinit {
        stopMonitoring()
        removeActivationObserver()
    }

    // MARK: - Sketchybar Integration

    /// Action types for sketchybar notifications
    enum SketchybarAction: String {
        case save
        case restore
        case activate
        case deactivate
        case clear
    }

    /// Find sketchybar executable in common locations
    private static let sketchybarPath: String? = {
        let paths = [
            "/opt/homebrew/bin/sketchybar",  // Homebrew on Apple Silicon
            "/usr/local/bin/sketchybar",      // Homebrew on Intel
            "/run/current-system/sw/bin/sketchybar"  // NixOS
        ]
        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        // Try to find via PATH using `which`
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["sketchybar"]
        let pipe = Pipe()
        whichProcess.standardOutput = pipe
        whichProcess.standardError = FileHandle.nullDevice
        do {
            try whichProcess.run()
            whichProcess.waitUntilExit()
            if whichProcess.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {}
        return nil
    }()

    /// Notify sketchybar about virtual space changes
    private func notifySketchybar(action: SketchybarAction, space: VirtualSpace?, monitor displayID: UInt32) {
        print("[Sketchybar] notifySketchybar called: action=\(action.rawValue) space=\(space?.number ?? -1)")
        print("[Sketchybar] sketchybarIntegrationEnabled=\(SettingsManager.shared.settings.sketchybarIntegrationEnabled)")

        guard SettingsManager.shared.settings.sketchybarIntegrationEnabled else {
            print("[Sketchybar] Integration disabled, returning early")
            return
        }

        // Check for custom command first
        if let customCommand = SettingsManager.shared.settings.sketchybarCommand, !customCommand.isEmpty {
            runCustomSketchybarCommand(customCommand, action: action, space: space, displayID: displayID)
            return
        }

        // Use direct sketchybar invocation (safer, no shell injection)
        guard let sketchybarPath = Self.sketchybarPath else {
            print("[Sketchybar] sketchybar not found in common paths")
            return
        }

        let spaceNumber = space?.number ?? -1
        let spaceName = space?.name ?? ""
        let appBundleIDs = space?.uniqueAppBundleIDs ?? []
        let appNames = resolveAppNames(from: appBundleIDs)

        // Build arguments for sketchybar --trigger
        // Format: sketchybar --trigger event_name KEY1=value1 KEY2=value2 ...
        var args = ["--trigger", "mactile_space_change"]
        args.append("MACTILE_SPACE=\(spaceNumber)")
        args.append("MACTILE_SPACE_NAME=\(spaceName)")
        args.append("MACTILE_MONITOR=\(displayID)")
        args.append("MACTILE_ACTION=\(action.rawValue)")
        args.append("MACTILE_APPS=\(appBundleIDs.joined(separator: ","))")
        args.append("MACTILE_APP_NAMES=\(appNames.joined(separator: ","))")
        args.append("MACTILE_APP_COUNT=\(appBundleIDs.count)")

        // Include app info and names for ALL saved spaces
        let allSpaces = SettingsManager.shared.settings.virtualSpaces.getNonEmptySpaces(displayID: displayID)
        for savedSpace in allSpaces {
            let savedAppBundleIDs = savedSpace.uniqueAppBundleIDs
            let savedAppNames = resolveAppNames(from: savedAppBundleIDs)
            args.append("MACTILE_SPACE_\(savedSpace.number)_APPS=\(savedAppNames.joined(separator: ","))")
            args.append("MACTILE_SPACE_\(savedSpace.number)_NAME=\(savedSpace.name ?? "")")
        }

        print("[Sketchybar] Running: \(sketchybarPath) \(args.joined(separator: " "))")

        // Run asynchronously to not block UI
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: sketchybarPath)
            process.arguments = args

            let errorPipe = Pipe()
            process.standardOutput = FileHandle.nullDevice
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()
                let status = process.terminationStatus
                print("[Sketchybar] Command finished with status: \(status)")
                if status != 0 {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    if let errorStr = String(data: errorData, encoding: .utf8), !errorStr.isEmpty {
                        print("[Sketchybar] Error output: \(errorStr)")
                    }
                }
            } catch {
                print("[Sketchybar] Failed to run command: \(error)")
            }
        }
    }

    /// Run a custom sketchybar command (for advanced users)
    /// Uses environment variables to pass data safely
    private func runCustomSketchybarCommand(_ command: String, action: SketchybarAction, space: VirtualSpace?, displayID: UInt32) {
        let spaceNumber = space?.number ?? -1
        let spaceName = space?.name ?? ""
        let appBundleIDs = space?.uniqueAppBundleIDs ?? []
        let appNames = resolveAppNames(from: appBundleIDs)

        // Build environment variables (safer than interpolating into command)
        var env = ProcessInfo.processInfo.environment
        env["MACTILE_SPACE"] = String(spaceNumber)
        env["MACTILE_SPACE_NAME"] = spaceName
        env["MACTILE_MONITOR"] = String(displayID)
        env["MACTILE_ACTION"] = action.rawValue
        env["MACTILE_APPS"] = appBundleIDs.joined(separator: ",")
        env["MACTILE_APP_NAMES"] = appNames.joined(separator: ",")
        env["MACTILE_APP_COUNT"] = String(appBundleIDs.count)

        let allSpaces = SettingsManager.shared.settings.virtualSpaces.getNonEmptySpaces(displayID: displayID)
        for savedSpace in allSpaces {
            let savedAppBundleIDs = savedSpace.uniqueAppBundleIDs
            let savedAppNames = resolveAppNames(from: savedAppBundleIDs)
            env["MACTILE_SPACE_\(savedSpace.number)_APPS"] = savedAppNames.joined(separator: ",")
            env["MACTILE_SPACE_\(savedSpace.number)_NAME"] = savedSpace.name ?? ""
        }

        print("[Sketchybar] Running custom command with env vars")

        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", command]
            process.environment = env

            let errorPipe = Pipe()
            process.standardOutput = FileHandle.nullDevice
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()
                let status = process.terminationStatus
                if status != 0 {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    if let errorStr = String(data: errorData, encoding: .utf8), !errorStr.isEmpty {
                        print("[Sketchybar] Custom command error: \(errorStr)")
                    }
                }
            } catch {
                print("[Sketchybar] Failed to run custom command: \(error)")
            }
        }
    }

    /// Resolve app names from bundle IDs
    private func resolveAppNames(from bundleIDs: [String]) -> [String] {
        return bundleIDs.compactMap { bundleID in
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                return FileManager.default.displayName(atPath: appURL.path)
                    .replacingOccurrences(of: ".app", with: "")
            }
            // Fallback: extract last component of bundle ID
            return bundleID.split(separator: ".").last.map(String.init)
        }
    }

    // MARK: - Coordinate System Helpers

    /// Get the height of the primary screen (the screen with the menu bar).
    /// This is used for coordinate conversions between:
    /// - CGWindowList/AX API (top-left origin)
    /// - NSScreen/Cocoa (bottom-left origin)
    /// NSScreen.screens.first is documented to always be the screen containing the menu bar.
    private var primaryScreenHeight: CGFloat {
        // NSScreen.screens.first is always the primary (menu bar) screen per Apple docs
        guard let primaryScreen = NSScreen.screens.first else { return 0 }
        return primaryScreen.frame.height
    }

    // MARK: - Public API

    /// Save currently connected monitors' visible windows to a virtual space number.
    /// Existing layouts for disconnected monitors are preserved.
    func saveToSpace(number: Int, forMonitor displayID: UInt32) {
        guard SettingsManager.shared.virtualSpacesSharedAcrossMonitors else {
            saveToSpacePerMonitor(number: number, displayID: displayID)
            return
        }

        print("[VirtualSpaces] Saving space \(number) across connected monitors (trigger monitor: \(displayID))")

        var storage = SettingsManager.shared.settings.virtualSpaces
        let existingName = getExistingSpaceName(number: number, preferredDisplayID: displayID, storage: storage)

        let connectedDisplayIDs = NSScreen.screens.map { Self.displayID(for: $0) }
        let targetDisplayIDs = connectedDisplayIDs.isEmpty ? [displayID] : connectedDisplayIDs
        var savedSpacesByDisplay: [UInt32: VirtualSpace] = [:]

        for monitorID in targetDisplayIDs {
            let windows = captureTopmostWindows(forMonitor: monitorID)
            if debugLoggingEnabled {
                print("[VirtualSpaces] Monitor \(monitorID): captured \(windows.count) windows")
                for window in windows {
                    let idString = window.windowID.map(String.init) ?? "nil"
                    print("[VirtualSpaces]   Save window: \(window.appBundleID) '\(window.windowTitle)' id=\(idString) frame=\(window.frame)")
                }
            }

            let space = VirtualSpace(
                number: number,
                name: existingName,
                windows: windows,
                displayID: monitorID
            )
            storage.setSpace(space, displayID: monitorID)
            savedSpacesByDisplay[monitorID] = space
        }

        // Persist without re-registering hotkeys.
        SettingsManager.shared.saveVirtualSpacesQuietly(storage)

        // Mark all connected monitors in this shared slot as active.
        // Activate trigger monitor last so menu/UI focus is consistent.
        let activationOrder = targetDisplayIDs.sorted { lhs, rhs in
            if lhs == displayID { return false }
            if rhs == displayID { return true }
            return lhs < rhs
        }
        for monitorID in activationOrder {
            guard let activeSpace = savedSpacesByDisplay[monitorID] else { continue }
            activateSpace(activeSpace, forMonitor: activeSpace.displayID)
            notifySketchybar(action: .save, space: activeSpace, monitor: activeSpace.displayID)
        }

        print("[VirtualSpaces] Space \(number) saved for \(savedSpacesByDisplay.count) connected monitor(s)")
    }

    /// Restore windows from a virtual space number for all currently connected monitors
    /// that have saved layouts.
    func restoreFromSpace(number: Int, forMonitor displayID: UInt32) {
        guard SettingsManager.shared.virtualSpacesSharedAcrossMonitors else {
            restoreFromSpacePerMonitor(number: number, displayID: displayID)
            return
        }

        print("[VirtualSpaces] Restoring space \(number) across connected monitors (trigger monitor: \(displayID))")

        let storage = SettingsManager.shared.settings.virtualSpaces
        let spacesForNumber = storage.getSpacesForNumber(number).filter { !$0.isEmpty }
        guard !spacesForNumber.isEmpty else {
            print("[VirtualSpaces] Space \(number) not found")
            return
        }

        let connectedDisplayIDs = Set(NSScreen.screens.map { Self.displayID(for: $0) })
        let restorableSpaces = spacesForNumber.filter { connectedDisplayIDs.contains($0.displayID) }
        guard !restorableSpaces.isEmpty else {
            print("[VirtualSpaces] Space \(number) has no saved layouts for currently connected monitors")
            return
        }

        // Restore non-trigger monitors first, then trigger monitor last so focus ends there.
        let sortedSpaces = restorableSpaces.sorted { lhs, rhs in
            if lhs.displayID == displayID { return false }
            if rhs.displayID == displayID { return true }
            return lhs.displayID < rhs.displayID
        }

        for space in sortedSpaces {
            print("[VirtualSpaces] Restoring monitor \(space.displayID) with \(space.windows.count) windows")
            restoreWindows(from: space)
        }

        // Mark all restored monitors as active so tracking/deactivation remains accurate.
        for space in sortedSpaces {
            activateSpace(space, forMonitor: space.displayID)
        }

        // Notify sketchybar for restored monitors.
        for space in restorableSpaces {
            notifySketchybar(action: .restore, space: space, monitor: space.displayID)
        }

        print("[VirtualSpaces] Space \(number) restored on \(restorableSpaces.count) connected monitor(s)")
    }

    private func saveToSpacePerMonitor(number: Int, displayID: UInt32) {
        print("[VirtualSpaces] Saving to space \(number) for monitor \(displayID)")

        // Capture topmost windows on this monitor
        let windows = captureTopmostWindows(forMonitor: displayID)
        print("[VirtualSpaces] Captured \(windows.count) windows")
        if debugLoggingEnabled {
            for window in windows {
                let idString = window.windowID.map(String.init) ?? "nil"
                print("[VirtualSpaces]   Save window: \(window.appBundleID) '\(window.windowTitle)' id=\(idString) frame=\(window.frame)")
            }
        }

        let existingName = SettingsManager.shared.settings.virtualSpaces.getSpace(displayID: displayID, number: number)?.name

        // Create the virtual space
        let space = VirtualSpace(
            number: number,
            name: existingName,
            windows: windows,
            displayID: displayID
        )

        // Save to settings (using quiet save to avoid triggering hotkey re-registration)
        var storage = SettingsManager.shared.settings.virtualSpaces
        storage.setSpace(space, displayID: displayID)
        SettingsManager.shared.saveVirtualSpacesQuietly(storage)

        // Mark this space as active
        activateSpace(space, forMonitor: displayID)

        // Notify sketchybar
        notifySketchybar(action: .save, space: space, monitor: displayID)

        print("[VirtualSpaces] Space \(number) saved with \(windows.count) windows")
    }

    private func restoreFromSpacePerMonitor(number: Int, displayID: UInt32) {
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

        // Notify sketchybar
        notifySketchybar(action: .restore, space: space, monitor: displayID)

        print("[VirtualSpaces] Space \(number) restored")
    }

    /// Clear (unset) a virtual space for the specified monitor
    func clearSpace(number: Int, forMonitor displayID: UInt32) {
        guard SettingsManager.shared.virtualSpacesSharedAcrossMonitors else {
            clearSpacePerMonitor(number: number, displayID: displayID)
            return
        }

        print("[VirtualSpaces] Clearing shared space \(number) across monitors (trigger monitor: \(displayID))")

        var storage = SettingsManager.shared.settings.virtualSpaces
        let monitorIDs = storage.getDisplayIDsForSpaceNumber(number)
        guard !monitorIDs.isEmpty else {
            print("[VirtualSpaces] Shared space \(number) not found")
            return
        }

        let clearedSpaces = monitorIDs.compactMap { monitorID in
            storage.getSpace(displayID: monitorID, number: number)
        }

        for monitorID in monitorIDs {
            storage.clearSpace(displayID: monitorID, number: number)
        }
        SettingsManager.shared.saveVirtualSpacesQuietly(storage)

        var deactivatedMonitors: [UInt32] = []
        for monitorID in monitorIDs where activeSpaces[monitorID] == number {
            activeSpaces.removeValue(forKey: monitorID)
            activeSpaceWindows.removeValue(forKey: monitorID)
            lastKnownFrames.removeValue(forKey: monitorID)
            deactivatedMonitors.append(monitorID)
        }

        if activeSpaces.isEmpty {
            stopMonitoring()
        }

        for monitorID in deactivatedMonitors {
            delegate?.virtualSpaceDidBecomeInactive(forMonitor: monitorID)
        }

        for clearedSpace in clearedSpaces {
            notifySketchybar(action: .clear, space: clearedSpace, monitor: clearedSpace.displayID)
        }

        print("[VirtualSpaces] Shared space \(number) cleared from \(monitorIDs.count) monitor(s)")
    }

    private func clearSpacePerMonitor(number: Int, displayID: UInt32) {
        print("[VirtualSpaces] Clearing space \(number) for monitor \(displayID)")

        // Check if this space was active
        let wasActive = activeSpaces[displayID] == number

        // Capture the space before clearing (for sketchybar notification)
        let clearedSpace = SettingsManager.shared.settings.virtualSpaces.getSpace(displayID: displayID, number: number)

        // Clear from storage
        var storage = SettingsManager.shared.settings.virtualSpaces
        storage.clearSpace(displayID: displayID, number: number)
        SettingsManager.shared.saveVirtualSpacesQuietly(storage)

        // If it was active, deactivate it
        if wasActive {
            activeSpaces.removeValue(forKey: displayID)
            activeSpaceWindows.removeValue(forKey: displayID)
            lastKnownFrames.removeValue(forKey: displayID)

            // Stop monitoring if no active spaces left
            if activeSpaces.isEmpty {
                stopMonitoring()
            }

            delegate?.virtualSpaceDidBecomeInactive(forMonitor: displayID)
        }

        // Notify sketchybar with the cleared space info (so it knows which space was cleared)
        notifySketchybar(action: .clear, space: clearedSpace, monitor: displayID)

        print("[VirtualSpaces] Space \(number) cleared")
    }

    /// Rename the active virtual space for a monitor
    func renameActiveSpace(name: String, forMonitor displayID: UInt32) {
        guard let spaceNumber = activeSpaces[displayID] else {
            print("[VirtualSpaces] No active space to rename")
            return
        }

        renameSpace(number: spaceNumber, name: name, forMonitor: displayID)
    }

    /// Rename a specific virtual space for a monitor (does not require it to be active)
    func renameSpace(number: Int, name: String, forMonitor displayID: UInt32) {
        guard !SettingsManager.shared.virtualSpacesSharedAcrossMonitors else {
            renameSharedSpace(number: number, name: name, triggerDisplayID: displayID)
            return
        }

        guard var space = SettingsManager.shared.settings.virtualSpaces.getSpace(displayID: displayID, number: number) else {
            print("[VirtualSpaces] Space \(number) not found for monitor \(displayID)")
            return
        }

        space.name = name.isEmpty ? nil : name

        var storage = SettingsManager.shared.settings.virtualSpaces
        storage.setSpace(space, displayID: displayID)
        SettingsManager.shared.saveVirtualSpacesQuietly(storage)

        // Notify delegate if this space is currently active
        if activeSpaces[displayID] == number {
            delegate?.virtualSpaceDidBecomeActive(space, forMonitor: displayID)
        }

        // Notify sketchybar about the rename so it can update the space name display
        // Use the active space if this is the active one, otherwise just trigger a refresh
        if activeSpaces[displayID] == number {
            notifySketchybar(action: .activate, space: space, monitor: displayID)
        } else {
            // Still notify so the space list is updated
            let activeSpace = getActiveSpace(forMonitor: displayID)
            notifySketchybar(action: .activate, space: activeSpace, monitor: displayID)
        }

        print("[VirtualSpaces] Renamed space \(number) to '\(name)'")
    }

    private func renameSharedSpace(number: Int, name: String, triggerDisplayID: UInt32) {
        var storage = SettingsManager.shared.settings.virtualSpaces
        let monitorIDs = storage.getDisplayIDsForSpaceNumber(number)
        guard !monitorIDs.isEmpty else {
            print("[VirtualSpaces] Shared space \(number) not found")
            return
        }

        let normalizedName = name.isEmpty ? nil : name
        var renamedSpacesByDisplay: [UInt32: VirtualSpace] = [:]
        for monitorID in monitorIDs {
            guard var space = storage.getSpace(displayID: monitorID, number: number) else { continue }
            space.name = normalizedName
            storage.setSpace(space, displayID: monitorID)
            renamedSpacesByDisplay[monitorID] = space
        }
        SettingsManager.shared.saveVirtualSpacesQuietly(storage)

        // Notify delegate for any active monitor using this shared slot.
        for (monitorID, activeNumber) in activeSpaces where activeNumber == number {
            if let space = renamedSpacesByDisplay[monitorID] {
                delegate?.virtualSpaceDidBecomeActive(space, forMonitor: monitorID)
            }
        }

        // Notify sketchybar for all renamed monitor entries.
        for monitorID in monitorIDs {
            let space = renamedSpacesByDisplay[monitorID]
            notifySketchybar(action: .activate, space: space, monitor: monitorID)
        }

        print("[VirtualSpaces] Renamed shared space \(number) to '\(name)' across \(monitorIDs.count) monitor(s)")
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

        // Notify sketchybar
        notifySketchybar(action: .deactivate, space: nil, monitor: displayID)

        delegate?.virtualSpaceDidBecomeInactive(forMonitor: displayID)
    }

    /// Check if any virtual space is active for a monitor
    func isSpaceActive(forMonitor displayID: UInt32) -> Bool {
        return activeSpaces[displayID] != nil
    }

    /// Deactivate all virtual spaces on all monitors
    /// Called when the virtual spaces feature is disabled
    func deactivateAllSpaces() {
        let displayIDs = Array(activeSpaces.keys)
        for displayID in displayIDs {
            deactivateSpace(forMonitor: displayID)
        }
        print("[VirtualSpaces] All spaces deactivated")
    }

    // MARK: - Window Capture

    /// Capture the topmost visible windows on a monitor
    private func captureTopmostWindows(forMonitor displayID: UInt32, log: Bool = true) -> [VirtualSpaceWindow] {
        // Get monitor bounds
        guard let screen = screenForDisplayID(displayID) else {
            if log {
                print("[VirtualSpaces] Could not find screen for display ID \(displayID)")
            }
            return []
        }

        // Get all windows in z-order using CGWindowListCopyWindowInfo
        let windowListOptions: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(windowListOptions, kCGNullWindowID) as? [[String: Any]] else {
            if log {
                print("[VirtualSpaces] Failed to get window list")
            }
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

            let windowID = (windowInfo[kCGWindowNumber as String] as? NSNumber)?.uint32Value

            let spaceWindow = VirtualSpaceWindow(
                appBundleID: bundleID,
                windowTitle: windowTitle,
                windowID: windowID,
                frame: windowFrame,
                zIndex: zIndex
            )
            capturedWindows.append(spaceWindow)
            zIndex += 1
        }

        // Filter windows by visibility - only keep windows that are at least 40% visible
        let filteredWindows = filterWindowsByVisibility(capturedWindows, minimumVisibility: 40.0, log: log)
        if log {
            print("[VirtualSpaces] Filtered \(capturedWindows.count) windows to \(filteredWindows.count) visible windows")
        }

        return filteredWindows
    }

    /// Filter windows to only include those with sufficient visibility
    /// A window is considered visible if at least `minimumVisibility`% of its area
    /// is not covered by windows in front of it (lower zIndex)
    private func filterWindowsByVisibility(_ windows: [VirtualSpaceWindow], minimumVisibility: CGFloat, log: Bool = true) -> [VirtualSpaceWindow] {
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
                if log {
                    print("[VirtualSpaces]   ✓ \(window.appBundleID) '\(window.windowTitle)' - \(Int(visibility))% visible")
                }
            } else {
                if log {
                    print("[VirtualSpaces]   ✗ \(window.appBundleID) '\(window.windowTitle)' - \(Int(visibility))% visible (filtered out)")
                }
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
            if let (axWindow, pid) = findWindow(matching: spaceWindow, log: true) {
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
            // Uses VirtualSpaceWindow.restoreOrderComparator - the canonical restore order logic
            let sortedAppWindows = appWindows.sorted {
                VirtualSpaceWindow.restoreOrderComparator($0.spaceWindow, $1.spaceWindow)
            }
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
    ///
    /// Matching strategy (in order of preference):
    /// 1. Direct AX window number match (try both AXWindowNumber and _AXWindowNumber attributes)
    /// 2. CG → AX lookup: find windowID in CGWindowList, then match AX window by frame
    /// 3. Single-window fallback (only when app has exactly one window)
    ///
    /// Safety rules for multi-window apps:
    /// - If windowID exists but can't be matched, and multiple windows exist → return nil
    /// - If multiple AX windows have same frame → only proceed with unique title match, else return nil
    /// - If no windowID saved (legacy data) and multiple windows → return nil
    private func findWindow(matching spaceWindow: VirtualSpaceWindow, log: Bool = true) -> (AXUIElement, pid_t)? {
        // Find the app by bundle ID
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == spaceWindow.appBundleID && $0.activationPolicy == .regular
        }) else {
            if log && debugLoggingEnabled {
                let idString = spaceWindow.windowID.map(String.init) ?? "nil"
                print("[VirtualSpaces] findWindow: app not running for \(spaceWindow.appBundleID) title='\(spaceWindow.windowTitle)' id=\(idString)")
            }
            return nil
        }

        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var windowList: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowList) == .success,
              let windows = windowList as? [AXUIElement] else {
            if log && debugLoggingEnabled {
                let idString = spaceWindow.windowID.map(String.init) ?? "nil"
                print("[VirtualSpaces] findWindow: failed to get AX windows for \(spaceWindow.appBundleID) title='\(spaceWindow.windowTitle)' id=\(idString)")
            }
            return nil
        }

        guard !windows.isEmpty else {
            if log && debugLoggingEnabled {
                let idString = spaceWindow.windowID.map(String.init) ?? "nil"
                print("[VirtualSpaces] findWindow: no AX windows for \(spaceWindow.appBundleID) title='\(spaceWindow.windowTitle)' id=\(idString)")
            }
            return nil
        }

        if log && debugLoggingEnabled {
            let savedIDString = spaceWindow.windowID.map(String.init) ?? "nil"
            print("[VirtualSpaces] findWindow: target \(spaceWindow.appBundleID) title='\(spaceWindow.windowTitle)' id=\(savedIDString) frame=\(spaceWindow.frame)")
        }

        // Build list of AX windows with their properties
        var axWindows: [AXWindowInfo] = []
        for axWindow in windows {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef)
            let title = titleRef as? String ?? ""
            let frame = getWindowFrame(axWindow)
            let windowNumber = getAXWindowNumber(axWindow)
            axWindows.append(AXWindowInfo(element: axWindow, frame: frame, title: title, windowNumber: windowNumber))
        }
        if log && debugLoggingEnabled {
            print("[VirtualSpaces] findWindow: AX windows count=\(axWindows.count)")
            for (index, axWindow) in axWindows.enumerated() {
                let idString = axWindow.windowNumber.map(String.init) ?? "nil"
                print("[VirtualSpaces]   AX[\(index)] title='\(axWindow.title)' id=\(idString) frame=\(axWindow.frame)")
            }
        }

        // If no saved windowID, require single-window app (legacy data needs re-save)
        guard let savedWindowID = spaceWindow.windowID else {
            if axWindows.count == 1 {
                if log && debugLoggingEnabled {
                    print("[VirtualSpaces] findWindow: no saved windowID; single-window fallback")
                }
                return (axWindows[0].element, pid)
            }
            if log && debugLoggingEnabled {
                print("[VirtualSpaces] findWindow: no saved windowID; multiple windows -> no match")
            }
            return axWindows.count == 1 ? (axWindows[0].element, pid) : nil
        }

        // Strategy 1: Direct AX window number match (most reliable when available)
        if let directMatch = axWindows.first(where: { $0.windowNumber == savedWindowID }) {
            if log && debugLoggingEnabled {
                print("[VirtualSpaces] findWindow: matched by AX window number id=\(savedWindowID)")
            }
            return (directMatch.element, pid)
        }

        // Strategy 2: CG → AX lookup via frame matching
        let cgWindows = getWindowNumbersFromCGWindowList(forPID: pid)
        if log && debugLoggingEnabled {
            print("[VirtualSpaces] findWindow: CG windows count=\(cgWindows.count)")
            for (index, cgWindow) in cgWindows.enumerated() {
                print("[VirtualSpaces]   CG[\(index)] id=\(cgWindow.windowNumber) frame=\(cgWindow.frame)")
            }
        }

        guard let cgWindow = cgWindows.first(where: { $0.windowNumber == savedWindowID }) else {
            // WindowID not found in CGWindowList - window may be closed or app restarted
            // Only safe fallback: single-window app
            if axWindows.count == 1 {
                if log && debugLoggingEnabled {
                    print("[VirtualSpaces] findWindow: saved id \(savedWindowID) not in CG list; single-window fallback")
                }
                return (axWindows[0].element, pid)
            }
            if log && debugLoggingEnabled {
                print("[VirtualSpaces] findWindow: saved id \(savedWindowID) not in CG list; multiple windows -> no match")
            }
            return axWindows.count == 1 ? (axWindows[0].element, pid) : nil
        }

        if log && debugLoggingEnabled {
            print("[VirtualSpaces] findWindow: matched CG id=\(savedWindowID) frame=\(cgWindow.frame)")
        }

        // Found window in CGWindowList - find matching AX window(s) by frame
        let frameTolerance: CGFloat = 30
        let maxDistance = frameTolerance * 4  // 120px total Manhattan distance

        let frameMatches = axWindows.filter { axWindow in
            frameDistance(axWindow.frame, cgWindow.frame) < maxDistance
        }

        switch frameMatches.count {
        case 0:
            // No frame match - window might be minimized or in transition
            // Fall back to single-window if available
            if axWindows.count == 1 {
                if log && debugLoggingEnabled {
                    print("[VirtualSpaces] findWindow: no AX frame match; single-window fallback")
                }
                return (axWindows[0].element, pid)
            }
            if log && debugLoggingEnabled {
                print("[VirtualSpaces] findWindow: no AX frame match; multiple windows -> no match")
            }
            return axWindows.count == 1 ? (axWindows[0].element, pid) : nil

        case 1:
            // Unique frame match - use it
            if log && debugLoggingEnabled {
                print("[VirtualSpaces] findWindow: matched by frame (unique)")
            }
            return (frameMatches[0].element, pid)

        default:
            // Multiple AX windows with same frame (ambiguous)
            // Try to disambiguate by title
            let titleMatches = frameMatches.filter { $0.title == spaceWindow.windowTitle }

            if titleMatches.count == 1 {
                // Unique title match within frame matches - use it
                if log && debugLoggingEnabled {
                    print("[VirtualSpaces] findWindow: matched by frame + title")
                }
                return (titleMatches[0].element, pid)
            }

            // Still ambiguous (multiple windows with same frame and title, or no title match)
            // Don't guess - return nil for safety
            if log && debugLoggingEnabled {
                print("[VirtualSpaces] findWindow: ambiguous frame match; multiple windows -> no match")
            }
            return nil
        }
    }

    /// AX window info for matching
    private struct AXWindowInfo {
        let element: AXUIElement
        let frame: CGRect
        let title: String
        let windowNumber: UInt32?
    }

    /// Try to get window number directly from AX element
    /// Attempts both standard and private attribute names
    private func getAXWindowNumber(_ axWindow: AXUIElement) -> UInt32? {
        // 1) Try private API first (most reliable, avoids frame heuristics)
        if let axGetWindowFunc = axGetWindowFunc {
            var windowID: CGWindowID = 0
            let result = axGetWindowFunc(axWindow, &windowID)
            if result == .success, windowID != 0 {
                if debugLoggingEnabled && !didLogPrivateAXSuccess {
                    print("[VirtualSpaces] AX window id: using _AXUIElementGetWindow")
                    didLogPrivateAXSuccess = true
                }
                return UInt32(windowID)
            }
            if debugLoggingEnabled && !didLogPrivateAXFallback {
                print("[VirtualSpaces] AX window id: _AXUIElementGetWindow failed; falling back to AXWindowNumber attributes")
                didLogPrivateAXFallback = true
            }
        } else if debugLoggingEnabled && !didLogPrivateAXFallback {
            print("[VirtualSpaces] AX window id: private API unavailable; falling back to AXWindowNumber attributes")
            didLogPrivateAXFallback = true
        }

        // 2) Try standard attribute, then private attribute variant
        let attributeNames = ["AXWindowNumber", "_AXWindowNumber"]

        for attrName in attributeNames {
            var valueRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(axWindow, attrName as CFString, &valueRef)
            if result == .success, let number = (valueRef as? NSNumber)?.uint32Value {
                return number
            }
        }

        return nil
    }

    /// Calculate Manhattan distance between two frames (origin + size)
    private func frameDistance(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        abs(lhs.origin.x - rhs.origin.x) +
        abs(lhs.origin.y - rhs.origin.y) +
        abs(lhs.size.width - rhs.size.width) +
        abs(lhs.size.height - rhs.size.height)
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

    /// Set the frame of an AX window using the shared WindowManager implementation.
    /// This ensures consistent window positioning behavior with retry logic and
    /// proper handling of cross-monitor moves and async AX API behavior.
    private func setWindowFrame(_ axWindow: AXUIElement, frame: CGRect) {
        // Delegate to RealWindowManager's shared implementation which handles:
        // - Coordinate conversion
        // - Cross-monitor vs same-screen strategies
        // - Retry loops for async AX API
        // - Minimum window size constraints
        RealWindowManager.shared.setAXWindowFrame(axWindow, frame: frame)
    }

    // MARK: - Active State Management

    /// Mark a space as active and start monitoring
    /// - Parameter notifyBar: Whether to notify sketchybar (default false since callers notify separately)
    private func activateSpace(_ space: VirtualSpace, forMonitor displayID: UInt32, notifyBar: Bool = false) {
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

        // Notify sketchybar if requested (for auto-activation via layout matching)
        if notifyBar {
            notifySketchybar(action: .activate, space: space, monitor: displayID)
        }

        // Notify delegate
        delegate?.virtualSpaceDidBecomeActive(space, forMonitor: displayID)
    }

    /// Start monitoring for deactivation triggers
    private func startMonitoring() {
        ensureActivationObserver()

        // Start timer to check for window changes (only one)
        if windowCheckTimer == nil {
            windowCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.checkForWindowChanges()
            }
        }
    }

    /// Stop monitoring
    private func stopMonitoring() {
        windowCheckTimer?.invalidate()
        windowCheckTimer = nil
    }

    /// Ensure activation observer is always active (lightweight)
    private func ensureActivationObserver() {
        if focusObserver != nil { return }

        focusObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivation(notification)
        }
    }

    private func removeActivationObserver() {
        if let observer = focusObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            focusObserver = nil
        }
    }

    /// Handle app activation notification
    private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier else {
            return
        }

        guard SettingsManager.shared.settings.virtualSpacesEnabled else {
            return
        }

        // Ignore MacTile's own windows (overlay, settings, rename modal)
        if bundleID == Bundle.main.bundleIdentifier {
            return
        }

        // Attempt to re-activate a matching space for the focused monitor
        if let displayID = displayIDForActivatedApp(app) {
            scheduleLayoutCheck(forMonitor: displayID)
        } else {
            // Fall back to checking all monitors (throttled)
            for screen in NSScreen.screens {
                let id = VirtualSpaceManager.displayID(for: screen)
                scheduleLayoutCheck(forMonitor: id)
            }
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

                guard let (axWindow, _) = findWindow(matching: window, log: false),
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

    // MARK: - Layout Matching

    private struct WindowIDSignature: Hashable {
        let bundleID: String
        let windowID: UInt32
    }

    /// Determine which monitor the activated app's frontmost window is on, using CGWindowList.
    private func displayIDForActivatedApp(_ app: NSRunningApplication) -> UInt32? {
        let windowListOptions: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(windowListOptions, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for windowInfo in windowList {
            guard let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  pid == app.processIdentifier else {
                continue
            }

            guard let layer = windowInfo[kCGWindowLayer as String] as? Int,
                  layer == 0 else {
                continue
            }

            guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"] else {
                continue
            }

            let windowFrame = CGRect(
                x: x,
                y: self.primaryScreenHeight - y - height,
                width: width,
                height: height
            )
            let windowCenter = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
            return VirtualSpaceManager.displayIDForPoint(windowCenter)
        }

        return nil
    }

    /// Attempt to auto-activate a space if the current visible windows exactly match a saved space.
    /// Returns nil if a check was performed, or the remaining delay if throttled.
    private func attemptAutoActivateSpace(forMonitor displayID: UInt32) -> TimeInterval? {
        guard SettingsManager.shared.settings.virtualSpacesEnabled else { return nil }

        let now = Date()
        if let lastCheck = lastLayoutCheck[displayID] {
            let elapsed = now.timeIntervalSince(lastCheck)
            if elapsed < layoutCheckInterval {
                return max(0, layoutCheckInterval - elapsed)
            }
        }
        lastLayoutCheck[displayID] = now

        let spaces = SettingsManager.shared.settings.virtualSpaces.getNonEmptySpaces(displayID: displayID)
            .sorted { $0.number < $1.number }
        guard !spaces.isEmpty else { return nil }

        let currentWindows = captureTopmostWindows(forMonitor: displayID, log: false)
        guard !currentWindows.isEmpty else { return nil }

        for space in spaces {
            if layoutMatches(space: space, currentWindows: currentWindows) {
                if activeSpaces[displayID] != space.number {
                    // Auto-activation: notify sketchybar
                    activateSpace(space, forMonitor: displayID, notifyBar: true)
                }
                return nil
            }
        }

        return nil
    }

    private func layoutMatches(space: VirtualSpace, currentWindows: [VirtualSpaceWindow]) -> Bool {
        // Must be exact same number of windows
        guard space.windows.count == currentWindows.count else { return false }

        let savedIDs = space.windows.compactMap { window -> WindowIDSignature? in
            guard let windowID = window.windowID else { return nil }
            return WindowIDSignature(bundleID: window.appBundleID, windowID: windowID)
        }
        let currentIDs = currentWindows.compactMap { window -> WindowIDSignature? in
            guard let windowID = window.windowID else { return nil }
            return WindowIDSignature(bundleID: window.appBundleID, windowID: windowID)
        }

        // If all windows have IDs, match by (bundleID, windowID)
        if savedIDs.count == space.windows.count && currentIDs.count == currentWindows.count {
            return Set(savedIDs) == Set(currentIDs)
        }

        // Fallback: match by bundleID + frame (tolerant)
        return matchByFrame(saved: space.windows, current: currentWindows, tolerance: 10)
    }

    private func matchByFrame(saved: [VirtualSpaceWindow], current: [VirtualSpaceWindow], tolerance: CGFloat) -> Bool {
        var remaining = current

        for savedWindow in saved {
            guard let index = remaining.firstIndex(where: { candidate in
                candidate.appBundleID == savedWindow.appBundleID &&
                framesApproximatelyEqual(candidate.frame, savedWindow.frame, tolerance: tolerance)
            }) else {
                return false
            }
            remaining.remove(at: index)
        }

        return remaining.isEmpty
    }

    private func framesApproximatelyEqual(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) <= tolerance &&
        abs(lhs.origin.y - rhs.origin.y) <= tolerance &&
        abs(lhs.size.width - rhs.size.width) <= tolerance &&
        abs(lhs.size.height - rhs.size.height) <= tolerance
    }

    private func scheduleLayoutCheck(forMonitor displayID: UInt32, delay: TimeInterval? = nil) {
        let delaySeconds = delay ?? layoutCheckDelay

        if let existing = pendingLayoutChecks[displayID] {
            existing.cancel()
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if let retryDelay = self.attemptAutoActivateSpace(forMonitor: displayID) {
                self.scheduleLayoutCheck(forMonitor: displayID, delay: retryDelay)
            }
        }

        pendingLayoutChecks[displayID] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds, execute: workItem)
    }

    // MARK: - Helpers

    /// Window info from CGWindowList
    private struct CGWindowInfo {
        let windowNumber: UInt32
        let frame: CGRect
    }

    /// Get window numbers from CGWindowList for a specific PID
    /// This is more reliable than AXWindowNumber which many apps don't expose
    /// Note: We don't use .optionOnScreenOnly so that minimized windows can be found and restored
    private func getWindowNumbersFromCGWindowList(forPID pid: pid_t) -> [CGWindowInfo] {
        // Don't use .optionOnScreenOnly - we want to find minimized windows too
        let windowListOptions: CGWindowListOption = [.excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(windowListOptions, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var results: [CGWindowInfo] = []

        for windowInfo in windowList {
            guard let windowPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  windowPID == pid else {
                continue
            }

            guard let layer = windowInfo[kCGWindowLayer as String] as? Int,
                  layer == 0 else {
                continue
            }

            guard let windowNumber = (windowInfo[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"] else {
                continue
            }

            // Convert from CGWindowList coordinates (top-left origin) to screen coordinates (bottom-left origin)
            let frame = CGRect(
                x: x,
                y: self.primaryScreenHeight - y - height,
                width: width,
                height: height
            )

            results.append(CGWindowInfo(windowNumber: windowNumber, frame: frame))
        }

        return results
    }

    /// Get an existing space name for this number, preferring the trigger monitor.
    private func getExistingSpaceName(number: Int, preferredDisplayID: UInt32, storage: VirtualSpacesStorage) -> String? {
        if let preferred = storage.getSpace(displayID: preferredDisplayID, number: number)?.name,
           !preferred.isEmpty {
            return preferred
        }
        return storage.getSpacesForNumber(number)
            .compactMap { $0.name }
            .first { !$0.isEmpty }
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
        return displayID(for: NSScreen.main ?? NSScreen.screens.first ?? NSScreen())
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
