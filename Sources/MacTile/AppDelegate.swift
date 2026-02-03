import AppKit
import MacTileCore
import HotKey

/// Main application delegate for MacTile
class AppDelegate: NSObject, NSApplicationDelegate, VirtualSpaceManagerDelegate {
    private var statusItem: NSStatusItem?
    private var hotKey: HotKey?
    private var secondaryHotKey: HotKey?
    private var focusHotKeys: [HotKey] = []  // Global hotkeys for focus presets
    private var virtualSpaceHotKeys: [HotKey] = []  // Global hotkeys for virtual spaces
    private var overlayController: OverlayWindowController?
    private var settingsController: SettingsWindowController?
    private var settingsObserver: NSObjectProtocol?

    // Virtual space rename panel
    private var renamePanel: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("MacTile launched")

        // Set up as accessory app (no dock icon)
        NSApp.setActivationPolicy(.accessory)

        // Check and request accessibility permissions
        checkAccessibilityPermissions()

        // Create status bar item
        setupStatusItem()

        // Register global hotkey from settings
        setupHotKey()

        // Register focus preset hotkeys
        setupFocusHotKeys()

        // Register virtual space hotkeys
        setupVirtualSpaceHotKeys()

        // Set up virtual space manager delegate
        VirtualSpaceManager.shared.delegate = self

        // Sync launch at login with system state
        syncLaunchAtLogin()

        // Observe settings changes
        observeSettings()

        let settings = SettingsManager.shared.settings
        let shortcut = settings.toggleOverlayShortcut.displayString
        if let secondary = settings.secondaryToggleOverlayShortcut {
            print("MacTile ready. Press \(shortcut) or \(secondary.displayString) to show grid.")
        } else {
            print("MacTile ready. Press \(shortcut) to show grid.")
        }
    }

    private func observeSettings() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .settingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSettingsChanged()
        }
    }

    private func handleSettingsChanged() {
        // Re-register hotkey if it changed
        setupHotKey()

        // Re-register focus preset hotkeys
        setupFocusHotKeys()

        // Re-register virtual space hotkeys
        setupVirtualSpaceHotKeys()

        // Update status item visibility
        let settings = SettingsManager.shared.settings
        statusItem?.isVisible = settings.showMenuBarIcon

        // Update launch at login
        LaunchAtLoginManager.shared.setEnabled(settings.launchAtLogin)

        // Rebuild menu to show updated shortcuts and presets
        rebuildMenu()
    }

    private func syncLaunchAtLogin() {
        // Sync our stored setting with actual system state
        let settings = SettingsManager.shared.settings
        let actuallyEnabled = LaunchAtLoginManager.shared.isEnabled

        if settings.launchAtLogin != actuallyEnabled {
            // If setting says enabled but system says not, try to enable
            // If setting says disabled but system says enabled, disable
            LaunchAtLoginManager.shared.setEnabled(settings.launchAtLogin)
        }
    }

    private func checkAccessibilityPermissions() {
        // Always trigger the permission check which will prompt if needed
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        )

        if !trusted {
            print("Accessibility permissions not granted")

            // Show an additional alert with instructions
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = """
                MacTile needs accessibility permission to move and resize windows.

                If you're running from Terminal:
                1. Open System Settings > Privacy & Security > Accessibility
                2. Click the + button
                3. Add your Terminal app (Terminal, iTerm2, etc.)

                If running the app directly:
                1. MacTile should appear in the Accessibility list
                2. Enable the checkbox next to it

                You may need to restart MacTile after granting permission.
                """
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Continue Anyway")

                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    self.openAccessibilitySettings()
                }
            }
        } else {
            print("Accessibility permissions granted")
        }
    }

    private func setupStatusItem() {
        let settings = SettingsManager.shared.settings

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.isVisible = settings.showMenuBarIcon

        if let button = statusItem?.button {
            // Use a grid icon
            if let image = NSImage(systemSymbolName: "square.grid.3x3", accessibilityDescription: "MacTile") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "MT"
            }
        }

        rebuildMenu()
    }

    private func rebuildMenu() {
        let settings = SettingsManager.shared.settings
        let menu = NSMenu()

        // Show Grid item with current shortcut(s)
        var shortcutDisplay = settings.toggleOverlayShortcut.displayString
        if let secondary = settings.secondaryToggleOverlayShortcut {
            shortcutDisplay += " / \(secondary.displayString)"
        }
        menu.addItem(NSMenuItem(title: "Show Grid (\(shortcutDisplay))", action: #selector(showGrid), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // Grid presets submenu - dynamically built from settings
        let presetMenu = NSMenu()
        for size in settings.gridSizes {
            let item = NSMenuItem(title: "\(size.cols)x\(size.rows) Grid", action: #selector(setGridPreset(_:)), keyEquivalent: "")
            item.representedObject = size
            presetMenu.addItem(item)
        }

        let presetItem = NSMenuItem(title: "Grid Presets", action: nil, keyEquivalent: "")
        presetItem.submenu = presetMenu
        menu.addItem(presetItem)

        menu.addItem(NSMenuItem.separator())

        // Settings item
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Check Accessibility...", action: #selector(recheckAccessibility), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open Accessibility Settings...", action: #selector(openAccessibilitySettingsAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit MacTile", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func setupHotKey() {
        let settings = SettingsManager.shared.settings

        // Clear existing hotkeys first
        hotKey = nil
        secondaryHotKey = nil

        // Setup primary hotkey
        let shortcut = settings.toggleOverlayShortcut
        print("Setting up primary hotkey: keyCode=\(shortcut.keyCode), modifiers=\(shortcut.modifiers), display=\(shortcut.displayString)")
        hotKey = createHotKey(from: shortcut)
        if hotKey != nil {
            print("Successfully registered primary hotkey: \(shortcut.displayString)")
        } else {
            print("Failed to register primary hotkey - unknown key code: \(shortcut.keyCode)")
            // Fall back to default
            hotKey = HotKey(key: .g, modifiers: [.control, .option])
            hotKey?.keyDownHandler = { [weak self] in
                self?.toggleGrid()
            }
            print("Fell back to default hotkey: ⌃⌥G")
        }

        // Setup secondary hotkey (optional)
        if let secondaryShortcut = settings.secondaryToggleOverlayShortcut {
            print("Setting up secondary hotkey: keyCode=\(secondaryShortcut.keyCode), modifiers=\(secondaryShortcut.modifiers), display=\(secondaryShortcut.displayString)")
            secondaryHotKey = createHotKey(from: secondaryShortcut)
            if secondaryHotKey != nil {
                print("Successfully registered secondary hotkey: \(secondaryShortcut.displayString)")
            } else {
                print("Failed to register secondary hotkey - unknown key code: \(secondaryShortcut.keyCode)")
            }
        } else {
            secondaryHotKey = nil
            print("No secondary hotkey configured")
        }
    }

    private func setupFocusHotKeys() {
        let settings = SettingsManager.shared.settings

        // Clear existing focus hotkeys
        focusHotKeys.removeAll()

        // Set up hotkeys for focus presets that work without overlay
        for preset in settings.focusPresets {
            guard preset.worksWithoutOverlay,
                  preset.keyCode > 0,
                  !preset.keyString.isEmpty,
                  !preset.appBundleID.isEmpty else {
                continue
            }

            // Convert modifier flags to HotKey modifiers
            var modifiers: NSEvent.ModifierFlags = []
            if preset.modifiers & KeyboardShortcut.Modifiers.control != 0 {
                modifiers.insert(.control)
            }
            if preset.modifiers & KeyboardShortcut.Modifiers.option != 0 {
                modifiers.insert(.option)
            }
            if preset.modifiers & KeyboardShortcut.Modifiers.shift != 0 {
                modifiers.insert(.shift)
            }
            if preset.modifiers & KeyboardShortcut.Modifiers.command != 0 {
                modifiers.insert(.command)
            }

            // Map keyCode to HotKey.Key
            if let key = keyCodeToHotKey(preset.keyCode) {
                let bundleID = preset.appBundleID  // Capture for closure
                let worksWithOverlay = preset.worksWithOverlay  // Capture for closure
                let openIfNotRunning = preset.openIfNotRunning  // Capture for closure
                let hk = HotKey(key: key, modifiers: modifiers)
                hk.keyDownHandler = { [weak self] in
                    // If overlay is visible, delegate to overlay's handler (if preset supports it)
                    if self?.overlayController?.window?.isVisible == true {
                        if worksWithOverlay {
                            print("[FocusHotKey] Overlay visible, delegating to overlay for \(bundleID)")
                            self?.overlayController?.activateFocusPreset(bundleID: bundleID, openIfNotRunning: openIfNotRunning)
                        } else {
                            print("[FocusHotKey] Skipping - overlay visible but preset doesn't support overlay")
                        }
                        return
                    }
                    print("[FocusHotKey] Activated for \(bundleID)")
                    FocusManager.shared.focusNextWindow(forBundleID: bundleID, openIfNotRunning: openIfNotRunning)
                }
                focusHotKeys.append(hk)
                print("Registered focus hotkey: \(preset.shortcutDisplayString) -> \(preset.appName)")
            } else {
                print("Failed to register focus hotkey for \(preset.appName) - unknown key code: \(preset.keyCode)")
            }
        }

        print("Registered \(focusHotKeys.count) focus hotkeys")
    }

    private func setupVirtualSpaceHotKeys() {
        // Clear existing virtual space hotkeys
        virtualSpaceHotKeys.removeAll()

        // Key codes for numbers 1-9
        // 1=18, 2=19, 3=20, 4=21, 5=23, 6=22, 7=26, 8=28, 9=25
        let numberKeys: [(keyCode: UInt16, key: Key, number: Int)] = [
            (18, .one, 1),
            (19, .two, 2),
            (20, .three, 3),
            (21, .four, 4),
            (23, .five, 5),
            (22, .six, 6),
            (26, .seven, 7),
            (28, .eight, 8),
            (25, .nine, 9)
        ]

        for (_, key, spaceNumber) in numberKeys {
            // Restore: Control+Option+N
            let restoreKey = HotKey(key: key, modifiers: [.control, .option])
            restoreKey.keyDownHandler = { [weak self] in
                self?.restoreVirtualSpace(number: spaceNumber)
            }
            virtualSpaceHotKeys.append(restoreKey)

            // Save: Control+Option+Shift+N
            let saveKey = HotKey(key: key, modifiers: [.control, .option, .shift])
            saveKey.keyDownHandler = { [weak self] in
                self?.saveToVirtualSpace(number: spaceNumber)
            }
            virtualSpaceHotKeys.append(saveKey)
        }

        // Rename: Control+Option+Comma (keyCode 43)
        let renameKey = HotKey(key: .comma, modifiers: [.control, .option])
        renameKey.keyDownHandler = { [weak self] in
            self?.renameActiveVirtualSpace()
        }
        virtualSpaceHotKeys.append(renameKey)

        print("Registered \(virtualSpaceHotKeys.count) virtual space hotkeys")
    }

    // MARK: - Virtual Space Actions

    private func saveToVirtualSpace(number: Int) {
        // Get the currently focused screen
        let displayID = getCurrentDisplayID()
        VirtualSpaceManager.shared.saveToSpace(number: number, forMonitor: displayID)
    }

    private func restoreVirtualSpace(number: Int) {
        // Get the currently focused screen
        let displayID = getCurrentDisplayID()
        VirtualSpaceManager.shared.restoreFromSpace(number: number, forMonitor: displayID)
    }

    private func renameActiveVirtualSpace() {
        // Get the currently focused screen
        let displayID = getCurrentDisplayID()

        guard VirtualSpaceManager.shared.isSpaceActive(forMonitor: displayID) else {
            print("[VirtualSpaces] No active space to rename")
            return
        }

        // Show rename dialog
        showRenameDialog(forMonitor: displayID)
    }

    private func getCurrentDisplayID() -> UInt32 {
        // Get the screen with the currently focused window
        if let focusedWindow = RealWindowManager.shared.getFocusedWindow() {
            let center = CGPoint(
                x: focusedWindow.frame.midX,
                y: focusedWindow.frame.midY
            )
            return VirtualSpaceManager.displayIDForPoint(center)
        }

        // Fall back to main screen
        guard let mainScreen = NSScreen.main else {
            return VirtualSpaceManager.displayID(for: NSScreen.screens[0])
        }
        return VirtualSpaceManager.displayID(for: mainScreen)
    }

    private func showRenameDialog(forMonitor displayID: UInt32) {
        guard let space = VirtualSpaceManager.shared.getActiveSpace(forMonitor: displayID) else {
            return
        }

        // Use NSAlert with text field for simple input
        let alert = NSAlert()
        alert.messageText = "Rename Virtual Space \(space.number)"
        alert.informativeText = "Enter a name for this virtual space:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        textField.stringValue = space.name ?? ""
        textField.placeholderString = "Space \(space.number)"
        alert.accessoryView = textField

        // Make text field first responder
        alert.window.initialFirstResponder = textField

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            let newName = textField.stringValue.trimmingCharacters(in: .whitespaces)
            VirtualSpaceManager.shared.renameActiveSpace(name: newName, forMonitor: displayID)
        }
    }

    // MARK: - VirtualSpaceManagerDelegate

    func virtualSpaceDidBecomeActive(_ space: VirtualSpace, forMonitor displayID: UInt32) {
        // Update menubar to show space name
        updateMenuBarForVirtualSpace(space)
    }

    func virtualSpaceDidBecomeInactive(forMonitor displayID: UInt32) {
        // Check if any space is still active
        let anyActive = NSScreen.screens.contains { screen in
            let id = VirtualSpaceManager.displayID(for: screen)
            return VirtualSpaceManager.shared.isSpaceActive(forMonitor: id)
        }

        if !anyActive {
            // Restore normal menubar
            updateMenuBarForVirtualSpace(nil)
        }
    }

    private func updateMenuBarForVirtualSpace(_ space: VirtualSpace?) {
        guard let button = statusItem?.button else { return }

        if let space = space {
            // Show space name in menubar
            button.title = space.displayName
            button.image = nil
        } else {
            // Restore normal icon
            button.title = ""
            if let image = NSImage(systemSymbolName: "square.grid.3x3", accessibilityDescription: "MacTile") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "MT"
            }
        }
    }

    private func createHotKey(from shortcut: KeyboardShortcut) -> HotKey? {
        // Convert our modifier flags to HotKey modifiers
        var modifiers: NSEvent.ModifierFlags = []
        if shortcut.modifiers & KeyboardShortcut.Modifiers.control != 0 {
            modifiers.insert(.control)
        }
        if shortcut.modifiers & KeyboardShortcut.Modifiers.option != 0 {
            modifiers.insert(.option)
        }
        if shortcut.modifiers & KeyboardShortcut.Modifiers.shift != 0 {
            modifiers.insert(.shift)
        }
        if shortcut.modifiers & KeyboardShortcut.Modifiers.command != 0 {
            modifiers.insert(.command)
        }

        // Map keyCode to HotKey.Key
        if let key = keyCodeToHotKey(shortcut.keyCode) {
            let hk = HotKey(key: key, modifiers: modifiers)
            hk.keyDownHandler = { [weak self] in
                self?.toggleGrid()
            }
            return hk
        }
        return nil
    }

    private func keyCodeToHotKey(_ keyCode: UInt16) -> Key? {
        // Map common key codes to HotKey.Key
        let keyMap: [UInt16: Key] = [
            0: .a, 1: .s, 2: .d, 3: .f, 4: .h, 5: .g, 6: .z, 7: .x,
            8: .c, 9: .v, 11: .b, 12: .q, 13: .w, 14: .e, 15: .r,
            16: .y, 17: .t, 18: .one, 19: .two, 20: .three, 21: .four, 22: .six,
            23: .five, 24: .equal, 25: .nine, 26: .seven, 27: .minus, 28: .eight, 29: .zero,
            30: .rightBracket, 31: .o, 32: .u, 33: .leftBracket, 34: .i, 35: .p, 36: .return,
            37: .l, 38: .j, 39: .quote, 40: .k, 41: .semicolon, 42: .backslash, 43: .comma,
            44: .slash, 45: .n, 46: .m, 47: .period, 48: .tab, 49: .space,
            50: .grave, 51: .delete, 53: .escape,
            123: .leftArrow, 124: .rightArrow, 125: .downArrow, 126: .upArrow
        ]
        return keyMap[keyCode]
    }

    @objc private func showGrid() {
        toggleGrid()
    }

    private func toggleGrid() {
        if overlayController == nil {
            overlayController = OverlayWindowController()
        }

        if overlayController?.window?.isVisible == true {
            // Toggling off should return focus to the original window (same as Escape)
            overlayController?.hideOverlay(cancelled: true)
        } else {
            overlayController?.showOverlay()
        }
    }

    @objc private func setGridPreset(_ sender: NSMenuItem) {
        guard let size = sender.representedObject as? GridSize else { return }
        overlayController?.setGridSize(size)
    }

    @objc private func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController()
        }
        settingsController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func recheckAccessibility() {
        let trusted = AXIsProcessTrusted()
        let alert = NSAlert()
        if trusted {
            alert.messageText = "Accessibility Enabled"
            alert.informativeText = "MacTile has accessibility permissions and can move/resize windows."
            alert.alertStyle = .informational
        } else {
            alert.messageText = "Accessibility Not Enabled"
            alert.informativeText = "MacTile does not have accessibility permissions. Window tiling will not work until permissions are granted."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "OK")

            if alert.runModal() == .alertFirstButtonReturn {
                openAccessibilitySettings()
                return
            }
            return
        }
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func openAccessibilitySettingsAction() {
        openAccessibilitySettings()
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        print("MacTile terminating")
    }
}
