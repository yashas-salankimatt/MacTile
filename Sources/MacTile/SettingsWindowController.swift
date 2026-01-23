import AppKit
import MacTileCore
import HotKey

/// Window controller for MacTile settings
class SettingsWindowController: NSWindowController {
    private var tabView: NSTabView!
    private var gridSizesField: NSTextField!
    private var spacingSlider: NSSlider!
    private var spacingLabel: NSLabel!
    private var insetTopField: NSTextField!
    private var insetLeftField: NSTextField!
    private var insetBottomField: NSTextField!
    private var insetRightField: NSTextField!
    private var autoCloseCheckbox: NSButton!
    private var showIconCheckbox: NSButton!
    private var shortcutField: NSTextField!
    private var shortcutRecordButton: NSButton!
    private var isRecordingShortcut = false
    private var recordedShortcut: KeyboardShortcut?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "MacTile Settings"
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)
        setupUI()
        loadCurrentSettings()
    }

    private func setupUI() {
        guard let window = window else { return }

        // Create tab view
        tabView = NSTabView(frame: NSRect(x: 20, y: 60, width: 460, height: 320))
        tabView.autoresizingMask = [.width, .height]

        // Add tabs
        let generalTab = createGeneralTab()
        generalTab.label = "General"
        tabView.addTabViewItem(generalTab)

        let shortcutsTab = createShortcutsTab()
        shortcutsTab.label = "Shortcuts"
        tabView.addTabViewItem(shortcutsTab)

        window.contentView?.addSubview(tabView)

        // Add buttons at the bottom
        let buttonY: CGFloat = 20

        let resetButton = NSButton(frame: NSRect(x: 20, y: buttonY, width: 120, height: 24))
        resetButton.title = "Reset to Defaults"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetToDefaults)
        window.contentView?.addSubview(resetButton)

        let applyButton = NSButton(frame: NSRect(x: 360, y: buttonY, width: 80, height: 24))
        applyButton.title = "Apply"
        applyButton.bezelStyle = .rounded
        applyButton.target = self
        applyButton.action = #selector(applySettings)
        applyButton.keyEquivalent = "\r"
        window.contentView?.addSubview(applyButton)
    }

    private func createGeneralTab() -> NSTabViewItem {
        let item = NSTabViewItem()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 280))

        var y: CGFloat = 240

        // Grid Sizes Section
        let gridLabel = createLabel("Grid Sizes (comma-separated, e.g., \"8x2, 6x4, 4x4\"):", frame: NSRect(x: 20, y: y, width: 400, height: 20))
        view.addSubview(gridLabel)
        y -= 25

        gridSizesField = NSTextField(frame: NSRect(x: 20, y: y, width: 400, height: 24))
        gridSizesField.placeholderString = "8x2, 6x4, 4x4, 3x3, 2x2"
        view.addSubview(gridSizesField)
        y -= 15

        let gridHint = createLabel("Press Space in overlay to cycle through these sizes", frame: NSRect(x: 20, y: y, width: 400, height: 16))
        gridHint.font = NSFont.systemFont(ofSize: 11)
        gridHint.textColor = .secondaryLabelColor
        view.addSubview(gridHint)
        y -= 35

        // Window Spacing Section
        let spacingTitleLabel = createLabel("Window Spacing:", frame: NSRect(x: 20, y: y, width: 120, height: 20))
        view.addSubview(spacingTitleLabel)

        spacingSlider = NSSlider(frame: NSRect(x: 140, y: y, width: 200, height: 20))
        spacingSlider.minValue = 0
        spacingSlider.maxValue = 50
        spacingSlider.integerValue = 0
        spacingSlider.target = self
        spacingSlider.action = #selector(spacingSliderChanged)
        view.addSubview(spacingSlider)

        spacingLabel = createLabel("0 px", frame: NSRect(x: 350, y: y, width: 60, height: 20))
        view.addSubview(spacingLabel)
        y -= 15

        let spacingHint = createLabel("Gap between tiled windows", frame: NSRect(x: 140, y: y, width: 250, height: 16))
        spacingHint.font = NSFont.systemFont(ofSize: 11)
        spacingHint.textColor = .secondaryLabelColor
        view.addSubview(spacingHint)
        y -= 40

        // Insets Section
        let insetsLabel = createLabel("Screen Insets (margins from screen edges):", frame: NSRect(x: 20, y: y, width: 400, height: 20))
        view.addSubview(insetsLabel)
        y -= 30

        // Top inset
        let topLabel = createLabel("Top:", frame: NSRect(x: 20, y: y, width: 50, height: 20))
        view.addSubview(topLabel)
        insetTopField = NSTextField(frame: NSRect(x: 70, y: y, width: 60, height: 22))
        insetTopField.placeholderString = "0"
        view.addSubview(insetTopField)

        // Bottom inset
        let bottomLabel = createLabel("Bottom:", frame: NSRect(x: 150, y: y, width: 60, height: 20))
        view.addSubview(bottomLabel)
        insetBottomField = NSTextField(frame: NSRect(x: 210, y: y, width: 60, height: 22))
        insetBottomField.placeholderString = "0"
        view.addSubview(insetBottomField)
        y -= 30

        // Left inset
        let leftLabel = createLabel("Left:", frame: NSRect(x: 20, y: y, width: 50, height: 20))
        view.addSubview(leftLabel)
        insetLeftField = NSTextField(frame: NSRect(x: 70, y: y, width: 60, height: 22))
        insetLeftField.placeholderString = "0"
        view.addSubview(insetLeftField)

        // Right inset
        let rightLabel = createLabel("Right:", frame: NSRect(x: 150, y: y, width: 60, height: 20))
        view.addSubview(rightLabel)
        insetRightField = NSTextField(frame: NSRect(x: 210, y: y, width: 60, height: 22))
        insetRightField.placeholderString = "0"
        view.addSubview(insetRightField)
        y -= 40

        // Behavior Section
        let behaviorLabel = createLabel("Behavior:", frame: NSRect(x: 20, y: y, width: 100, height: 20))
        behaviorLabel.font = NSFont.boldSystemFont(ofSize: 13)
        view.addSubview(behaviorLabel)
        y -= 25

        autoCloseCheckbox = NSButton(checkboxWithTitle: "Auto-close overlay after applying resize", target: nil, action: nil)
        autoCloseCheckbox.frame = NSRect(x: 20, y: y, width: 350, height: 20)
        view.addSubview(autoCloseCheckbox)
        y -= 25

        showIconCheckbox = NSButton(checkboxWithTitle: "Show icon in menu bar", target: nil, action: nil)
        showIconCheckbox.frame = NSRect(x: 20, y: y, width: 350, height: 20)
        view.addSubview(showIconCheckbox)

        item.view = view
        return item
    }

    private func createShortcutsTab() -> NSTabViewItem {
        let item = NSTabViewItem()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 280))

        var y: CGFloat = 240

        // Global Hotkey Section
        let hotkeyLabel = createLabel("Toggle Overlay Shortcut:", frame: NSRect(x: 20, y: y, width: 180, height: 20))
        hotkeyLabel.font = NSFont.boldSystemFont(ofSize: 13)
        view.addSubview(hotkeyLabel)
        y -= 30

        shortcutField = NSTextField(frame: NSRect(x: 20, y: y, width: 150, height: 24))
        shortcutField.isEditable = false
        shortcutField.isSelectable = false
        shortcutField.alignment = .center
        shortcutField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        view.addSubview(shortcutField)

        shortcutRecordButton = NSButton(frame: NSRect(x: 180, y: y, width: 100, height: 24))
        shortcutRecordButton.title = "Record"
        shortcutRecordButton.bezelStyle = .rounded
        shortcutRecordButton.target = self
        shortcutRecordButton.action = #selector(toggleRecordShortcut)
        view.addSubview(shortcutRecordButton)
        y -= 20

        let shortcutHint = createLabel("Click Record and press your desired key combination", frame: NSRect(x: 20, y: y, width: 400, height: 16))
        shortcutHint.font = NSFont.systemFont(ofSize: 11)
        shortcutHint.textColor = .secondaryLabelColor
        view.addSubview(shortcutHint)
        y -= 50

        // Overlay Shortcuts Info
        let overlayLabel = createLabel("Overlay Navigation (when overlay is visible):", frame: NSRect(x: 20, y: y, width: 400, height: 20))
        overlayLabel.font = NSFont.boldSystemFont(ofSize: 13)
        view.addSubview(overlayLabel)
        y -= 25

        let shortcuts = [
            "Arrow Keys / H J K L  →  Select first corner",
            "Shift + Arrows / H J K L  →  Select second corner",
            "Space  →  Cycle through grid sizes",
            "Enter  →  Apply selection and resize window",
            "Escape  →  Cancel and close overlay"
        ]

        for shortcut in shortcuts {
            let label = createLabel(shortcut, frame: NSRect(x: 30, y: y, width: 380, height: 18))
            label.font = NSFont.systemFont(ofSize: 12)
            view.addSubview(label)
            y -= 20
        }

        item.view = view
        return item
    }

    private func createLabel(_ text: String, frame: NSRect) -> NSTextField {
        let label = NSTextField(frame: frame)
        label.stringValue = text
        label.isBordered = false
        label.isEditable = false
        label.isSelectable = false
        label.backgroundColor = .clear
        return label
    }

    private func loadCurrentSettings() {
        let settings = SettingsManager.shared.settings

        // Grid sizes
        gridSizesField.stringValue = MacTileSettings.gridSizesToString(settings.gridSizes)

        // Spacing
        spacingSlider.integerValue = Int(settings.windowSpacing)
        spacingLabel.stringValue = "\(Int(settings.windowSpacing)) px"

        // Insets
        insetTopField.stringValue = "\(Int(settings.insets.top))"
        insetLeftField.stringValue = "\(Int(settings.insets.left))"
        insetBottomField.stringValue = "\(Int(settings.insets.bottom))"
        insetRightField.stringValue = "\(Int(settings.insets.right))"

        // Behavior
        autoCloseCheckbox.state = settings.autoClose ? .on : .off
        showIconCheckbox.state = settings.showMenuBarIcon ? .on : .off

        // Shortcut
        shortcutField.stringValue = settings.toggleOverlayShortcut.displayString
        recordedShortcut = settings.toggleOverlayShortcut
    }

    @objc private func spacingSliderChanged() {
        spacingLabel.stringValue = "\(spacingSlider.integerValue) px"
    }

    @objc private func toggleRecordShortcut() {
        isRecordingShortcut.toggle()

        if isRecordingShortcut {
            shortcutRecordButton.title = "Press Keys..."
            shortcutField.stringValue = "..."
            window?.makeFirstResponder(window?.contentView)

            // Set up local event monitor
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, self.isRecordingShortcut else { return event }

                // Get modifiers
                var modifiers: UInt = 0
                if event.modifierFlags.contains(.control) {
                    modifiers |= KeyboardShortcut.Modifiers.control
                }
                if event.modifierFlags.contains(.option) {
                    modifiers |= KeyboardShortcut.Modifiers.option
                }
                if event.modifierFlags.contains(.shift) {
                    modifiers |= KeyboardShortcut.Modifiers.shift
                }
                if event.modifierFlags.contains(.command) {
                    modifiers |= KeyboardShortcut.Modifiers.command
                }

                // Need at least one modifier for global hotkey
                if modifiers == 0 && event.keyCode != 53 { // Allow Escape without modifier
                    return nil
                }

                // Handle Escape to cancel
                if event.keyCode == 53 && modifiers == 0 {
                    self.isRecordingShortcut = false
                    self.shortcutRecordButton.title = "Record"
                    self.loadCurrentSettings()
                    return nil
                }

                let keyString = self.keyCodeToString(event.keyCode)
                self.recordedShortcut = KeyboardShortcut(
                    keyCode: event.keyCode,
                    modifiers: modifiers,
                    keyString: keyString
                )

                self.shortcutField.stringValue = self.recordedShortcut?.displayString ?? ""
                self.isRecordingShortcut = false
                self.shortcutRecordButton.title = "Record"

                return nil
            }
        } else {
            shortcutRecordButton.title = "Record"
            if recordedShortcut == nil {
                loadCurrentSettings()
            }
        }
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String {
        let keyMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
            50: "`", 51: "Delete", 53: "Escape",
            123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return keyMap[keyCode] ?? "Key\(keyCode)"
    }

    @objc private func applySettings() {
        // Parse grid sizes
        let gridSizes = MacTileSettings.parseGridSizes(gridSizesField.stringValue)
        if !gridSizes.isEmpty {
            SettingsManager.shared.updateGridSizes(gridSizes)
        }

        // Update spacing
        SettingsManager.shared.updateWindowSpacing(CGFloat(spacingSlider.integerValue))

        // Update insets
        let insets = EdgeInsets(
            top: CGFloat(Int(insetTopField.stringValue) ?? 0),
            left: CGFloat(Int(insetLeftField.stringValue) ?? 0),
            bottom: CGFloat(Int(insetBottomField.stringValue) ?? 0),
            right: CGFloat(Int(insetRightField.stringValue) ?? 0)
        )
        SettingsManager.shared.updateInsets(insets)

        // Update behavior
        SettingsManager.shared.updateAutoClose(autoCloseCheckbox.state == .on)
        SettingsManager.shared.updateShowMenuBarIcon(showIconCheckbox.state == .on)

        // Update shortcut
        if let shortcut = recordedShortcut {
            SettingsManager.shared.updateToggleOverlayShortcut(shortcut)
        }

        window?.close()
    }

    @objc private func resetToDefaults() {
        SettingsManager.shared.resetToDefaults()
        loadCurrentSettings()
    }
}

// Type alias for NSTextField used as label
typealias NSLabel = NSTextField
