import AppKit
import MacTileCore
import HotKey

/// Main application delegate for MacTile
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hotKey: HotKey?
    private var overlayController: OverlayWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("MacTile launched")

        // Set up as accessory app (no dock icon)
        NSApp.setActivationPolicy(.accessory)

        // Check and request accessibility permissions
        checkAccessibilityPermissions()

        // Create status bar item
        setupStatusItem()

        // Register global hotkey (Control + Option + G)
        setupHotKey()

        print("MacTile ready. Press Control+Option+G to show grid.")
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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Use a grid icon
            if let image = NSImage(systemSymbolName: "square.grid.3x3", accessibilityDescription: "MacTile") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "MT"
            }
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Grid (^⌥G)", action: #selector(showGrid), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let presetMenu = NSMenu()
        presetMenu.addItem(NSMenuItem(title: "8x2 Grid", action: #selector(setGrid8x2), keyEquivalent: ""))
        presetMenu.addItem(NSMenuItem(title: "6x4 Grid", action: #selector(setGrid6x4), keyEquivalent: ""))
        presetMenu.addItem(NSMenuItem(title: "4x4 Grid", action: #selector(setGrid4x4), keyEquivalent: ""))
        presetMenu.addItem(NSMenuItem(title: "3x3 Grid", action: #selector(setGrid3x3), keyEquivalent: ""))
        presetMenu.addItem(NSMenuItem(title: "2x2 Grid", action: #selector(setGrid2x2), keyEquivalent: ""))

        let presetItem = NSMenuItem(title: "Grid Presets", action: nil, keyEquivalent: "")
        presetItem.submenu = presetMenu
        menu.addItem(presetItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Check Accessibility...", action: #selector(recheckAccessibility), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open Accessibility Settings...", action: #selector(openAccessibilitySettingsAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit MacTile", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func setupHotKey() {
        // Control + Option + G to toggle grid
        hotKey = HotKey(key: .g, modifiers: [.control, .option])
        hotKey?.keyDownHandler = { [weak self] in
            self?.toggleGrid()
        }
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

    @objc private func setGrid8x2() {
        overlayController?.setGridSize(GridSize(cols: 8, rows: 2))
    }

    @objc private func setGrid6x4() {
        overlayController?.setGridSize(GridSize(cols: 6, rows: 4))
    }

    @objc private func setGrid4x4() {
        overlayController?.setGridSize(GridSize(cols: 4, rows: 4))
    }

    @objc private func setGrid3x3() {
        overlayController?.setGridSize(GridSize(cols: 3, rows: 3))
    }

    @objc private func setGrid2x2() {
        overlayController?.setGridSize(GridSize(cols: 2, rows: 2))
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
        print("MacTile terminating")
    }
}
