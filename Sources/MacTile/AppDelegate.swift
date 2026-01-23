import AppKit
import MacTileCore
import HotKey

/// Main application delegate for MacTile
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hotKey: HotKey?
    private var secondaryHotKey: HotKey?
    private var overlayController: OverlayWindowController?
    private var settingsController: SettingsWindowController?
    private var settingsObserver: NSObjectProtocol?

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

        // Update status item visibility
        let settings = SettingsManager.shared.settings
        statusItem?.isVisible = settings.showMenuBarIcon

        // Rebuild menu to show updated shortcuts and presets
        rebuildMenu()
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

        // Setup primary hotkey
        let shortcut = settings.toggleOverlayShortcut
        hotKey = createHotKey(from: shortcut)
        if hotKey != nil {
            print("Registered primary hotkey: \(shortcut.displayString)")
        } else {
            print("Failed to register primary hotkey - unknown key code: \(shortcut.keyCode)")
            // Fall back to default
            hotKey = HotKey(key: .g, modifiers: [.control, .option])
            hotKey?.keyDownHandler = { [weak self] in
                self?.toggleGrid()
            }
        }

        // Setup secondary hotkey (optional)
        if let secondaryShortcut = settings.secondaryToggleOverlayShortcut {
            secondaryHotKey = createHotKey(from: secondaryShortcut)
            if secondaryHotKey != nil {
                print("Registered secondary hotkey: \(secondaryShortcut.displayString)")
            } else {
                print("Failed to register secondary hotkey - unknown key code: \(secondaryShortcut.keyCode)")
            }
        } else {
            secondaryHotKey = nil
            print("No secondary hotkey configured")
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
            overlayController?.hideOverlay()
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
