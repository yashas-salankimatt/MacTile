import AppKit
import MacTileCore
import HotKey

/// Window controller for MacTile settings
class SettingsWindowController: NSWindowController, NSWindowDelegate {
    // Sidebar navigation
    private var sidebarButtons: [NSButton] = []
    private var sidebarHighlight: NSView!
    private var contentPages: [NSView] = []
    private var contentContainer: NSView!
    private var currentPageIndex = 0
    private let sidebarWidth: CGFloat = 170

    // General tab
    private var gridSizesField: NSTextField!
    private var spacingSlider: NSSlider!
    private var spacingLabel: NSLabel!
    private var insetTopField: NSTextField!
    private var insetLeftField: NSTextField!
    private var insetBottomField: NSTextField!
    private var insetRightField: NSTextField!
    private var autoCloseCheckbox: NSButton!
    private var showIconCheckbox: NSButton!
    private var launchAtLoginCheckbox: NSButton!
    private var confirmOnClickCheckbox: NSButton!
    private var showHelpTextCheckbox: NSButton!
    private var showMonitorIndicatorCheckbox: NSButton!

    // Shortcuts tab - Primary
    private var shortcutField: NSTextField!
    private var shortcutRecordButton: NSButton!
    private var isRecordingShortcut = false
    private var recordedShortcut: KeyboardShortcut?
    private var shortcutMonitor: Any?  // Store event monitor to remove it later

    // Shortcuts tab - Secondary
    private var secondaryShortcutField: NSTextField!
    private var secondaryShortcutRecordButton: NSButton!
    private var secondaryShortcutClearButton: NSButton!
    private var isRecordingSecondaryShortcut = false
    private var recordedSecondaryShortcut: KeyboardShortcut?
    private var hasSecondaryShortcut = true
    private var secondaryShortcutMonitor: Any?  // Store event monitor to remove it later

    private var panModifierPopup: NSPopUpButton!
    private var anchorModifierPopup: NSPopUpButton!
    private var targetModifierPopup: NSPopUpButton!
    private var applyKeyPopup: NSPopUpButton!
    private var cancelKeyPopup: NSPopUpButton!
    private var cycleGridKeyPopup: NSPopUpButton!

    // Presets tab
    private var presetRows: [PresetRowView] = []
    private var presetsScrollView: NSScrollView!
    private var presetsContainer: NSView!
    private var addPresetButton: NSButton!

    // Focus tab
    private var focusPresetRows: [FocusPresetRowView] = []
    private var focusPresetsScrollView: NSScrollView!
    private var focusPresetsContainer: NSView!
    private var addFocusPresetButton: NSButton!

    // Virtual Spaces tab
    private var virtualSpacesEnabledCheckbox: NSButton!
    private var sketchybarIntegrationCheckbox: NSButton!
    private var saveModifiersField: NSTextField!
    private var saveModifiersRecordButton: NSButton!
    private var restoreModifiersField: NSTextField!
    private var restoreModifiersRecordButton: NSButton!
    private var clearModifiersField: NSTextField!
    private var clearModifiersRecordButton: NSButton!
    private var isRecordingSaveModifiers = false
    private var isRecordingRestoreModifiers = false
    private var isRecordingClearModifiers = false
    private var saveModifiersMonitor: Any?
    private var restoreModifiersMonitor: Any?
    private var clearModifiersMonitor: Any?
    private var recordedSaveModifiers: UInt = 0
    private var recordedRestoreModifiers: UInt = 0
    private var recordedClearModifiers: UInt = 0

    // Overlay Virtual Space modifiers
    private var overlaySaveModifiersField: NSTextField!
    private var overlaySaveModifiersRecordButton: NSButton!
    private var overlayClearModifiersField: NSTextField!
    private var overlayClearModifiersRecordButton: NSButton!
    private var isRecordingOverlaySaveModifiers = false
    private var isRecordingOverlayClearModifiers = false
    private var overlaySaveModifiersMonitor: Any?
    private var overlayClearModifiersMonitor: Any?
    private var recordedOverlaySaveModifiers: UInt = 0
    private var recordedOverlayClearModifiers: UInt = 0

    // Appearance tab
    private var overlayOpacitySlider: NSSlider!
    private var overlayOpacityLabel: NSTextField!
    private var gridLineOpacitySlider: NSSlider!
    private var gridLineOpacityLabel: NSTextField!
    private var gridLineWidthSlider: NSSlider!
    private var gridLineWidthLabel: NSTextField!
    private var selectionFillOpacitySlider: NSSlider!
    private var selectionFillOpacityLabel: NSTextField!
    private var selectionBorderWidthSlider: NSSlider!
    private var selectionBorderWidthLabel: NSTextField!
    private var overlayColorWell: NSColorWell!
    private var gridLineColorWell: NSColorWell!
    private var selectionFillColorWell: NSColorWell!
    private var selectionBorderColorWell: NSColorWell!
    private var anchorMarkerColorWell: NSColorWell!
    private var targetMarkerColorWell: NSColorWell!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "MacTile Settings"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)
        window.delegate = self
        setupUI()
        loadCurrentSettings()
    }

    override func showWindow(_ sender: Any?) {
        setupMainMenu()
        // Reload current settings to discard any unsaved changes from previous session
        loadCurrentSettings()
        super.showWindow(sender)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // Clean up any active event monitors to prevent them from continuing
        // to swallow keyDown events after the window is closed
        cleanupAllEventMonitors()
    }

    /// Removes all active event monitors and resets recording states
    private func cleanupAllEventMonitors() {
        // Clean up primary shortcut monitor
        if let monitor = shortcutMonitor {
            NSEvent.removeMonitor(monitor)
            shortcutMonitor = nil
        }
        isRecordingShortcut = false

        // Clean up secondary shortcut monitor
        if let monitor = secondaryShortcutMonitor {
            NSEvent.removeMonitor(monitor)
            secondaryShortcutMonitor = nil
        }
        isRecordingSecondaryShortcut = false

        // Clean up save modifiers monitor
        if let monitor = saveModifiersMonitor {
            NSEvent.removeMonitor(monitor)
            saveModifiersMonitor = nil
        }
        isRecordingSaveModifiers = false

        // Clean up restore modifiers monitor
        if let monitor = restoreModifiersMonitor {
            NSEvent.removeMonitor(monitor)
            restoreModifiersMonitor = nil
        }
        isRecordingRestoreModifiers = false

        // Clean up clear modifiers monitor
        if let monitor = clearModifiersMonitor {
            NSEvent.removeMonitor(monitor)
            clearModifiersMonitor = nil
        }
        isRecordingClearModifiers = false

        // Clean up overlay save modifiers monitor
        if let monitor = overlaySaveModifiersMonitor {
            NSEvent.removeMonitor(monitor)
            overlaySaveModifiersMonitor = nil
        }
        isRecordingOverlaySaveModifiers = false

        // Clean up overlay clear modifiers monitor
        if let monitor = overlayClearModifiersMonitor {
            NSEvent.removeMonitor(monitor)
            overlayClearModifiersMonitor = nil
        }
        isRecordingOverlayClearModifiers = false
    }

    /// Sets up the main application menu with Edit menu for copy/paste support
    private func setupMainMenu() {
        // Only set up if not already present
        if NSApp.mainMenu == nil {
            let mainMenu = NSMenu()

            // Application menu (required)
            let appMenuItem = NSMenuItem()
            let appMenu = NSMenu()
            appMenu.addItem(NSMenuItem(title: "Quit MacTile", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            appMenuItem.submenu = appMenu
            mainMenu.addItem(appMenuItem)

            // Edit menu for copy/paste
            let editMenuItem = NSMenuItem()
            let editMenu = NSMenu(title: "Edit")
            editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
            editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
            editMenu.addItem(NSMenuItem.separator())
            editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
            editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
            editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
            editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
            editMenuItem.submenu = editMenu
            mainMenu.addItem(editMenuItem)

            NSApp.mainMenu = mainMenu
        }
    }

    private func setupUI() {
        guard let window = window, let windowContent = window.contentView else { return }

        // Full-window vibrancy background
        let effectView = NSVisualEffectView(frame: windowContent.bounds)
        effectView.autoresizingMask = [.width, .height]
        effectView.material = .sidebar
        effectView.state = .active
        effectView.blendingMode = .behindWindow
        windowContent.addSubview(effectView)

        let winH = windowContent.bounds.height
        let winW = windowContent.bounds.width

        // === SIDEBAR ===
        setupSidebar(in: effectView, height: winH)

        // Vertical separator
        let separator = NSView(frame: NSRect(x: sidebarWidth, y: 0, width: 1, height: winH))
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        separator.autoresizingMask = [.height]
        effectView.addSubview(separator)

        // === CONTENT AREA ===
        let contentX = sidebarWidth + 1
        let buttonBarHeight: CGFloat = 50
        contentContainer = NSView(frame: NSRect(
            x: contentX, y: buttonBarHeight,
            width: winW - contentX, height: winH - buttonBarHeight
        ))
        contentContainer.autoresizingMask = [.width, .height]
        effectView.addSubview(contentContainer)

        // Create all content pages
        let pages = [
            createGeneralContent(),
            createShortcutsContent(),
            createAppearanceContent(),
            createPresetsContent(),
            createFocusContent(),
            createVirtualSpacesContent(),
            createAboutContent()
        ]

        for (i, page) in pages.enumerated() {
            page.frame = contentContainer.bounds
            page.autoresizingMask = [.width, .height]
            page.isHidden = (i != 0)
            contentContainer.addSubview(page)
        }
        contentPages = pages

        // === BUTTON BAR ===
        let applyButton = NSButton(frame: NSRect(x: winW - 100, y: 12, width: 80, height: 28))
        applyButton.title = "Apply"
        applyButton.bezelStyle = .rounded
        applyButton.target = self
        applyButton.action = #selector(applySettings)
        applyButton.keyEquivalent = "\r"
        effectView.addSubview(applyButton)

        let cancelButton = NSButton(frame: NSRect(x: winW - 190, y: 12, width: 80, height: 28))
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelSettings)
        cancelButton.keyEquivalent = "\u{1b}"
        effectView.addSubview(cancelButton)

        // Select first sidebar item (without animation for initial display)
        if !sidebarButtons.isEmpty {
            sidebarHighlight.frame = sidebarButtons[0].frame
        }
        selectSidebarItem(0)
    }

    // MARK: - Sidebar

    private func setupSidebar(in parent: NSView, height: CGFloat) {
        let items: [(icon: String, title: String)] = [
            ("gearshape", "General"),
            ("keyboard", "Shortcuts"),
            ("paintbrush", "Appearance"),
            ("square.grid.2x2", "Presets"),
            ("eye", "Focus"),
            ("rectangle.stack", "Spaces"),
            ("info.circle", "About")
        ]

        // Selection highlight (positioned later in selectSidebarItem)
        sidebarHighlight = NSView(frame: .zero)
        sidebarHighlight.wantsLayer = true
        sidebarHighlight.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
        sidebarHighlight.layer?.cornerRadius = 6
        parent.addSubview(sidebarHighlight)

        // Position items from top, below title bar area
        let topInset: CGFloat = 50
        var y = height - topInset
        let itemHeight: CGFloat = 30
        let itemGap: CGFloat = 2
        let itemX: CGFloat = 12
        let itemWidth = sidebarWidth - 24

        for (i, item) in items.enumerated() {
            y -= itemHeight

            let btn = NSButton(frame: NSRect(x: itemX, y: y, width: itemWidth, height: itemHeight))
            btn.isBordered = false
            btn.title = "  \(item.title)"
            btn.alignment = .left
            btn.font = NSFont.systemFont(ofSize: 13, weight: .regular)
            btn.contentTintColor = .secondaryLabelColor
            btn.imagePosition = .imageLeft

            if let img = NSImage(systemSymbolName: item.icon, accessibilityDescription: item.title) {
                let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
                btn.image = img.withSymbolConfiguration(config)
            }

            btn.tag = i
            btn.target = self
            btn.action = #selector(sidebarItemClicked(_:))

            parent.addSubview(btn)
            sidebarButtons.append(btn)

            y -= itemGap
        }
    }

    @objc private func sidebarItemClicked(_ sender: NSButton) {
        selectSidebarItem(sender.tag)
    }

    private func selectSidebarItem(_ index: Int) {
        guard index >= 0, index < contentPages.count, index < sidebarButtons.count else { return }

        // Hide current, show new
        if currentPageIndex < contentPages.count {
            contentPages[currentPageIndex].isHidden = true
        }
        contentPages[index].isHidden = false
        currentPageIndex = index

        // Animate highlight to selected button
        let targetFrame = sidebarButtons[index].frame
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            sidebarHighlight.animator().frame = targetFrame
        }

        // Update button tints
        for (i, btn) in sidebarButtons.enumerated() {
            btn.contentTintColor = (i == index) ? .white : .secondaryLabelColor
            btn.font = NSFont.systemFont(ofSize: 13, weight: (i == index) ? .medium : .regular)
        }
    }

    // MARK: - Card Section Helper

    private func addCardBackground(to view: NSView, frame: NSRect) {
        let card = NSView(frame: frame)
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.04).cgColor
        card.layer?.cornerRadius = 8
        view.addSubview(card, positioned: .below, relativeTo: nil)
    }

    @objc private func cancelSettings() {
        // Clean up any active recording monitors before closing
        cleanupAllEventMonitors()
        window?.close()
    }

    private func createGeneralContent() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 460))

        var y: CGFloat = 420

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
        y -= 28

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
        y -= 30

        // Insets Section
        let insetsLabel = createLabel("Screen Insets (margins from screen edges):", frame: NSRect(x: 20, y: y, width: 400, height: 20))
        view.addSubview(insetsLabel)
        y -= 26

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
        y -= 26

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
        y -= 32

        // Behavior Section
        let behaviorLabel = createLabel("Behavior:", frame: NSRect(x: 20, y: y, width: 100, height: 20))
        behaviorLabel.font = NSFont.boldSystemFont(ofSize: 13)
        view.addSubview(behaviorLabel)
        y -= 22

        autoCloseCheckbox = NSButton(checkboxWithTitle: "Auto-close overlay after applying resize", target: nil, action: nil)
        autoCloseCheckbox.frame = NSRect(x: 20, y: y, width: 350, height: 20)
        view.addSubview(autoCloseCheckbox)
        y -= 22

        showIconCheckbox = NSButton(checkboxWithTitle: "Show icon in menu bar", target: nil, action: nil)
        showIconCheckbox.frame = NSRect(x: 20, y: y, width: 350, height: 20)
        view.addSubview(showIconCheckbox)
        y -= 22

        launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch MacTile at login", target: nil, action: nil)
        launchAtLoginCheckbox.frame = NSRect(x: 20, y: y, width: 350, height: 20)
        view.addSubview(launchAtLoginCheckbox)
        y -= 22

        confirmOnClickCheckbox = NSButton(checkboxWithTitle: "Click without drag confirms selection", target: nil, action: nil)
        confirmOnClickCheckbox.frame = NSRect(x: 20, y: y, width: 350, height: 20)
        view.addSubview(confirmOnClickCheckbox)
        y -= 26

        // Overlay Display Section
        let overlayDisplayLabel = createLabel("Overlay Display:", frame: NSRect(x: 20, y: y, width: 100, height: 20))
        overlayDisplayLabel.font = NSFont.boldSystemFont(ofSize: 13)
        view.addSubview(overlayDisplayLabel)
        y -= 22

        showHelpTextCheckbox = NSButton(checkboxWithTitle: "Show help text at top of overlay", target: nil, action: nil)
        showHelpTextCheckbox.frame = NSRect(x: 20, y: y, width: 350, height: 20)
        view.addSubview(showHelpTextCheckbox)
        y -= 22

        showMonitorIndicatorCheckbox = NSButton(checkboxWithTitle: "Show monitor indicator (when multiple monitors)", target: nil, action: nil)
        showMonitorIndicatorCheckbox.frame = NSRect(x: 20, y: y, width: 400, height: 20)
        view.addSubview(showMonitorIndicatorCheckbox)

        // Reset button for this tab (positioned at the bottom with enough clearance)
        let resetButton = NSButton(frame: NSRect(x: 20, y: 15, width: 180, height: 24))
        resetButton.title = "Reset General Settings"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetGeneralSettings)
        view.addSubview(resetButton)

        // Card backgrounds for visual grouping
        addCardBackground(to: view, frame: NSRect(x: 8, y: 240, width: 584, height: 200))
        addCardBackground(to: view, frame: NSRect(x: 8, y: 48, width: 584, height: 185))

        return view
    }

    @objc private func resetGeneralSettings() {
        let defaults = MacTileSettings.default

        // Reset grid sizes
        gridSizesField.stringValue = MacTileSettings.gridSizesToString(defaults.gridSizes)

        // Reset spacing
        spacingSlider.integerValue = Int(defaults.windowSpacing)
        spacingLabel.stringValue = "\(Int(defaults.windowSpacing)) px"

        // Reset insets
        insetTopField.stringValue = "\(Int(defaults.insets.top))"
        insetLeftField.stringValue = "\(Int(defaults.insets.left))"
        insetBottomField.stringValue = "\(Int(defaults.insets.bottom))"
        insetRightField.stringValue = "\(Int(defaults.insets.right))"

        // Reset behavior
        autoCloseCheckbox.state = defaults.autoClose ? .on : .off
        showIconCheckbox.state = defaults.showMenuBarIcon ? .on : .off
        launchAtLoginCheckbox.state = defaults.launchAtLogin ? .on : .off
        confirmOnClickCheckbox.state = defaults.confirmOnClickWithoutDrag ? .on : .off

        // Reset overlay display
        showHelpTextCheckbox.state = defaults.showHelpText ? .on : .off
        showMonitorIndicatorCheckbox.state = defaults.showMonitorIndicator ? .on : .off
    }

    private func createShortcutsContent() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 460))

        var y: CGFloat = 420
        let popupX: CGFloat = 240
        let popupWidth: CGFloat = 120

        // Primary Hotkey Section
        let hotkeyLabel = createLabel("Primary Shortcut:", frame: NSRect(x: 20, y: y, width: 220, height: 20))
        hotkeyLabel.font = NSFont.boldSystemFont(ofSize: 13)
        view.addSubview(hotkeyLabel)
        y -= 28

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
        y -= 30

        // Secondary Hotkey Section
        let secondaryLabel = createLabel("Secondary Shortcut (optional):", frame: NSRect(x: 20, y: y, width: 220, height: 20))
        secondaryLabel.font = NSFont.boldSystemFont(ofSize: 13)
        view.addSubview(secondaryLabel)
        y -= 28

        secondaryShortcutField = NSTextField(frame: NSRect(x: 20, y: y, width: 150, height: 24))
        secondaryShortcutField.isEditable = false
        secondaryShortcutField.isSelectable = false
        secondaryShortcutField.alignment = .center
        secondaryShortcutField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        view.addSubview(secondaryShortcutField)

        secondaryShortcutRecordButton = NSButton(frame: NSRect(x: 180, y: y, width: 100, height: 24))
        secondaryShortcutRecordButton.title = "Record"
        secondaryShortcutRecordButton.bezelStyle = .rounded
        secondaryShortcutRecordButton.target = self
        secondaryShortcutRecordButton.action = #selector(toggleRecordSecondaryShortcut)
        view.addSubview(secondaryShortcutRecordButton)

        secondaryShortcutClearButton = NSButton(frame: NSRect(x: 290, y: y, width: 60, height: 24))
        secondaryShortcutClearButton.title = "Clear"
        secondaryShortcutClearButton.bezelStyle = .rounded
        secondaryShortcutClearButton.target = self
        secondaryShortcutClearButton.action = #selector(clearSecondaryShortcut)
        view.addSubview(secondaryShortcutClearButton)
        y -= 18

        let shortcutHint = createLabel("Click Record and press your desired key combination", frame: NSRect(x: 20, y: y, width: 400, height: 16))
        shortcutHint.font = NSFont.systemFont(ofSize: 11)
        shortcutHint.textColor = .secondaryLabelColor
        view.addSubview(shortcutHint)
        y -= 35

        // Overlay Modifier Settings
        let modifiersLabel = createLabel("Selection Mode Modifiers:", frame: NSRect(x: 20, y: y, width: 400, height: 20))
        modifiersLabel.font = NSFont.boldSystemFont(ofSize: 13)
        view.addSubview(modifiersLabel)
        y -= 28

        // Pan modifier
        let panLabel = createLabel("Pan (move entire selection):", frame: NSRect(x: 20, y: y, width: 220, height: 20))
        view.addSubview(panLabel)
        panModifierPopup = NSPopUpButton(frame: NSRect(x: popupX, y: y - 2, width: popupWidth, height: 24))
        panModifierPopup.addItems(withTitles: ["None", "Shift", "Option", "Control", "Command"])
        view.addSubview(panModifierPopup)
        y -= 28

        // Anchor modifier
        let anchorLabel = createLabel("Anchor (move first corner):", frame: NSRect(x: 20, y: y, width: 220, height: 20))
        view.addSubview(anchorLabel)
        anchorModifierPopup = NSPopUpButton(frame: NSRect(x: popupX, y: y - 2, width: popupWidth, height: 24))
        anchorModifierPopup.addItems(withTitles: ["None", "Shift", "Option", "Control", "Command"])
        view.addSubview(anchorModifierPopup)
        y -= 28

        // Target modifier
        let targetLabel = createLabel("Target (move second corner):", frame: NSRect(x: 20, y: y, width: 220, height: 20))
        view.addSubview(targetLabel)
        targetModifierPopup = NSPopUpButton(frame: NSRect(x: popupX, y: y - 2, width: popupWidth, height: 24))
        targetModifierPopup.addItems(withTitles: ["None", "Shift", "Option", "Control", "Command"])
        view.addSubview(targetModifierPopup)
        y -= 35

        // Action keys
        let actionLabel = createLabel("Action Keys:", frame: NSRect(x: 20, y: y, width: 400, height: 20))
        actionLabel.font = NSFont.boldSystemFont(ofSize: 13)
        view.addSubview(actionLabel)
        y -= 28

        // Apply key
        let applyLabel = createLabel("Apply selection:", frame: NSRect(x: 20, y: y, width: 140, height: 20))
        view.addSubview(applyLabel)
        applyKeyPopup = NSPopUpButton(frame: NSRect(x: 160, y: y - 2, width: 100, height: 24))
        applyKeyPopup.addItems(withTitles: ["Enter", "Space", "Tab"])
        view.addSubview(applyKeyPopup)
        y -= 28

        // Cancel key
        let cancelLabel = createLabel("Cancel overlay:", frame: NSRect(x: 20, y: y, width: 140, height: 20))
        view.addSubview(cancelLabel)
        cancelKeyPopup = NSPopUpButton(frame: NSRect(x: 160, y: y - 2, width: 100, height: 24))
        cancelKeyPopup.addItems(withTitles: ["Escape", "Q"])
        view.addSubview(cancelKeyPopup)
        y -= 28

        // Cycle grid key
        let cycleLabel = createLabel("Cycle grid sizes:", frame: NSRect(x: 20, y: y, width: 140, height: 20))
        view.addSubview(cycleLabel)
        cycleGridKeyPopup = NSPopUpButton(frame: NSRect(x: 160, y: y - 2, width: 100, height: 24))
        cycleGridKeyPopup.addItems(withTitles: ["Space", "Tab", "G"])
        view.addSubview(cycleGridKeyPopup)
        y -= 35

        // Navigation hint
        let navHint = createLabel("Navigation: Arrow keys or H/J/K/L (vim-style)", frame: NSRect(x: 20, y: y, width: 400, height: 16))
        navHint.font = NSFont.systemFont(ofSize: 11)
        navHint.textColor = .secondaryLabelColor
        view.addSubview(navHint)

        // Reset button for this tab
        let resetButton = NSButton(frame: NSRect(x: 20, y: 10, width: 180, height: 24))
        resetButton.title = "Reset Shortcut Settings"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetShortcutSettings)
        view.addSubview(resetButton)

        // Card backgrounds
        addCardBackground(to: view, frame: NSRect(x: 8, y: 290, width: 584, height: 150))
        addCardBackground(to: view, frame: NSRect(x: 8, y: 22, width: 584, height: 262))

        return view
    }

    @objc private func resetShortcutSettings() {
        let defaults = MacTileSettings.default

        // Reset primary shortcut
        recordedShortcut = defaults.toggleOverlayShortcut
        shortcutField.stringValue = defaults.toggleOverlayShortcut.displayString

        // Reset secondary shortcut
        if let secondary = defaults.secondaryToggleOverlayShortcut {
            recordedSecondaryShortcut = secondary
            secondaryShortcutField.stringValue = secondary.displayString
            secondaryShortcutField.textColor = .labelColor
            hasSecondaryShortcut = true
            secondaryShortcutClearButton.isEnabled = true
        } else {
            recordedSecondaryShortcut = nil
            secondaryShortcutField.stringValue = "Not set"
            secondaryShortcutField.textColor = .secondaryLabelColor
            hasSecondaryShortcut = false
            secondaryShortcutClearButton.isEnabled = false
        }

        // Reset overlay keyboard settings
        let keyboard = defaults.overlayKeyboard
        panModifierPopup.selectItem(at: modifierToIndex(keyboard.panModifier))
        anchorModifierPopup.selectItem(at: modifierToIndex(keyboard.anchorModifier))
        targetModifierPopup.selectItem(at: modifierToIndex(keyboard.targetModifier))
        applyKeyPopup.selectItem(at: keyCodeToApplyIndex(keyboard.applyKeyCode))
        cancelKeyPopup.selectItem(at: keyCodeToCancelIndex(keyboard.cancelKeyCode))
        cycleGridKeyPopup.selectItem(at: keyCodeToCycleIndex(keyboard.cycleGridKeyCode))
    }

    private func createAppearanceContent() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 460))

        var y: CGFloat = 420
        let colorWellWidth: CGFloat = 44
        let sliderWidth: CGFloat = 150

        // Overlay Background
        let overlaySection = createLabel("Overlay Background:", frame: NSRect(x: 20, y: y, width: 200, height: 20))
        overlaySection.font = NSFont.boldSystemFont(ofSize: 13)
        view.addSubview(overlaySection)
        y -= 28

        let overlayColorLabel = createLabel("Color:", frame: NSRect(x: 20, y: y, width: 60, height: 20))
        view.addSubview(overlayColorLabel)
        overlayColorWell = NSColorWell(frame: NSRect(x: 80, y: y - 2, width: colorWellWidth, height: 24))
        view.addSubview(overlayColorWell)

        let overlayOpacityLabelTitle = createLabel("Opacity:", frame: NSRect(x: 150, y: y, width: 60, height: 20))
        view.addSubview(overlayOpacityLabelTitle)
        overlayOpacitySlider = NSSlider(frame: NSRect(x: 210, y: y, width: sliderWidth, height: 20))
        overlayOpacitySlider.minValue = 0
        overlayOpacitySlider.maxValue = 1
        overlayOpacitySlider.target = self
        overlayOpacitySlider.action = #selector(overlayOpacityChanged)
        view.addSubview(overlayOpacitySlider)
        overlayOpacityLabel = createLabel("40%", frame: NSRect(x: 365, y: y, width: 50, height: 20))
        view.addSubview(overlayOpacityLabel)
        y -= 35

        // Grid Lines
        let gridSection = createLabel("Grid Lines:", frame: NSRect(x: 20, y: y, width: 200, height: 20))
        gridSection.font = NSFont.boldSystemFont(ofSize: 13)
        view.addSubview(gridSection)
        y -= 28

        let gridColorLabel = createLabel("Color:", frame: NSRect(x: 20, y: y, width: 60, height: 20))
        view.addSubview(gridColorLabel)
        gridLineColorWell = NSColorWell(frame: NSRect(x: 80, y: y - 2, width: colorWellWidth, height: 24))
        view.addSubview(gridLineColorWell)

        let gridOpacityLabelTitle = createLabel("Opacity:", frame: NSRect(x: 150, y: y, width: 60, height: 20))
        view.addSubview(gridOpacityLabelTitle)
        gridLineOpacitySlider = NSSlider(frame: NSRect(x: 210, y: y, width: sliderWidth, height: 20))
        gridLineOpacitySlider.minValue = 0
        gridLineOpacitySlider.maxValue = 1
        gridLineOpacitySlider.target = self
        gridLineOpacitySlider.action = #selector(gridLineOpacityChanged)
        view.addSubview(gridLineOpacitySlider)
        gridLineOpacityLabel = createLabel("30%", frame: NSRect(x: 365, y: y, width: 50, height: 20))
        view.addSubview(gridLineOpacityLabel)
        y -= 26

        let gridWidthLabelTitle = createLabel("Line width:", frame: NSRect(x: 20, y: y, width: 80, height: 20))
        view.addSubview(gridWidthLabelTitle)
        gridLineWidthSlider = NSSlider(frame: NSRect(x: 100, y: y, width: 100, height: 20))
        gridLineWidthSlider.minValue = 0.5
        gridLineWidthSlider.maxValue = 5
        gridLineWidthSlider.target = self
        gridLineWidthSlider.action = #selector(gridLineWidthChanged)
        view.addSubview(gridLineWidthSlider)
        gridLineWidthLabel = createLabel("1.0 px", frame: NSRect(x: 205, y: y, width: 60, height: 20))
        view.addSubview(gridLineWidthLabel)
        y -= 35

        // Selection
        let selectionSection = createLabel("Selection:", frame: NSRect(x: 20, y: y, width: 200, height: 20))
        selectionSection.font = NSFont.boldSystemFont(ofSize: 13)
        view.addSubview(selectionSection)
        y -= 28

        // Fill color
        let fillColorLabel = createLabel("Fill color:", frame: NSRect(x: 20, y: y, width: 70, height: 20))
        view.addSubview(fillColorLabel)
        selectionFillColorWell = NSColorWell(frame: NSRect(x: 90, y: y - 2, width: colorWellWidth, height: 24))
        view.addSubview(selectionFillColorWell)

        let fillOpacityLabelTitle = createLabel("Opacity:", frame: NSRect(x: 150, y: y, width: 60, height: 20))
        view.addSubview(fillOpacityLabelTitle)
        selectionFillOpacitySlider = NSSlider(frame: NSRect(x: 210, y: y, width: sliderWidth, height: 20))
        selectionFillOpacitySlider.minValue = 0
        selectionFillOpacitySlider.maxValue = 1
        selectionFillOpacitySlider.target = self
        selectionFillOpacitySlider.action = #selector(selectionFillOpacityChanged)
        view.addSubview(selectionFillOpacitySlider)
        selectionFillOpacityLabel = createLabel("40%", frame: NSRect(x: 365, y: y, width: 50, height: 20))
        view.addSubview(selectionFillOpacityLabel)
        y -= 26

        // Border color
        let borderColorLabel = createLabel("Border color:", frame: NSRect(x: 20, y: y, width: 80, height: 20))
        view.addSubview(borderColorLabel)
        selectionBorderColorWell = NSColorWell(frame: NSRect(x: 100, y: y - 2, width: colorWellWidth, height: 24))
        view.addSubview(selectionBorderColorWell)

        let borderWidthLabelTitle = createLabel("Width:", frame: NSRect(x: 160, y: y, width: 50, height: 20))
        view.addSubview(borderWidthLabelTitle)
        selectionBorderWidthSlider = NSSlider(frame: NSRect(x: 210, y: y, width: 100, height: 20))
        selectionBorderWidthSlider.minValue = 1
        selectionBorderWidthSlider.maxValue = 10
        selectionBorderWidthSlider.target = self
        selectionBorderWidthSlider.action = #selector(selectionBorderWidthChanged)
        view.addSubview(selectionBorderWidthSlider)
        selectionBorderWidthLabel = createLabel("3.0 px", frame: NSRect(x: 315, y: y, width: 60, height: 20))
        view.addSubview(selectionBorderWidthLabel)
        y -= 35

        // Corner Markers
        let markersSection = createLabel("Corner Markers:", frame: NSRect(x: 20, y: y, width: 200, height: 20))
        markersSection.font = NSFont.boldSystemFont(ofSize: 13)
        view.addSubview(markersSection)
        y -= 28

        let anchorColorLabel = createLabel("Anchor (first):", frame: NSRect(x: 20, y: y, width: 90, height: 20))
        view.addSubview(anchorColorLabel)
        anchorMarkerColorWell = NSColorWell(frame: NSRect(x: 110, y: y - 2, width: colorWellWidth, height: 24))
        view.addSubview(anchorMarkerColorWell)

        let targetColorLabel = createLabel("Target (second):", frame: NSRect(x: 180, y: y, width: 100, height: 20))
        view.addSubview(targetColorLabel)
        targetMarkerColorWell = NSColorWell(frame: NSRect(x: 280, y: y - 2, width: colorWellWidth, height: 24))
        view.addSubview(targetMarkerColorWell)

        // Reset button for this tab
        let resetButton = NSButton(frame: NSRect(x: 20, y: 10, width: 200, height: 24))
        resetButton.title = "Reset Appearance Settings"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetAppearanceSettings)
        view.addSubview(resetButton)

        // Card backgrounds
        addCardBackground(to: view, frame: NSRect(x: 8, y: 270, width: 584, height: 170))
        addCardBackground(to: view, frame: NSRect(x: 8, y: 118, width: 584, height: 145))

        return view
    }

    @objc private func resetAppearanceSettings() {
        let defaults = AppearanceSettings.default

        overlayColorWell.color = defaults.overlayBackgroundColor.nsColor
        overlayOpacitySlider.doubleValue = Double(defaults.overlayOpacity)
        overlayOpacityLabel.stringValue = "\(Int(defaults.overlayOpacity * 100))%"

        gridLineColorWell.color = defaults.gridLineColor.nsColor
        gridLineOpacitySlider.doubleValue = Double(defaults.gridLineOpacity)
        gridLineOpacityLabel.stringValue = "\(Int(defaults.gridLineOpacity * 100))%"
        gridLineWidthSlider.doubleValue = Double(defaults.gridLineWidth)
        gridLineWidthLabel.stringValue = String(format: "%.1f px", defaults.gridLineWidth)

        selectionFillColorWell.color = defaults.selectionFillColor.nsColor
        selectionFillOpacitySlider.doubleValue = Double(defaults.selectionFillOpacity)
        selectionFillOpacityLabel.stringValue = "\(Int(defaults.selectionFillOpacity * 100))%"

        selectionBorderColorWell.color = defaults.selectionBorderColor.nsColor
        selectionBorderWidthSlider.doubleValue = Double(defaults.selectionBorderWidth)
        selectionBorderWidthLabel.stringValue = String(format: "%.1f px", defaults.selectionBorderWidth)

        anchorMarkerColorWell.color = defaults.anchorMarkerColor.nsColor
        targetMarkerColorWell.color = defaults.targetMarkerColor.nsColor
    }

    private func createPresetsContent() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 460))

        var y: CGFloat = 420

        // Header
        let headerLabel = createLabel("Quick Tiling Presets", frame: NSRect(x: 20, y: y, width: 300, height: 20))
        headerLabel.font = NSFont.boldSystemFont(ofSize: 14)
        view.addSubview(headerLabel)
        y -= 20

        let descLabel = createLabel("Define keyboard shortcuts for quick window positioning (up to 30 presets)", frame: NSRect(x: 20, y: y, width: 560, height: 16))
        descLabel.font = NSFont.systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor
        view.addSubview(descLabel)
        y -= 30

        // Column headers aligned with single-row layout
        let headerOffset: CGFloat = 12  // scroll view x (10) + border inset (2)

        let shortcutLabel = createLabel("Shortcut", frame: NSRect(x: headerOffset + 5, y: y, width: 100, height: 16))
        shortcutLabel.font = NSFont.boldSystemFont(ofSize: 11)
        view.addSubview(shortcutLabel)

        let coordLabel = createLabel("Positions (| = cycle)", frame: NSRect(x: headerOffset + 110, y: y, width: 160, height: 16))
        coordLabel.font = NSFont.boldSystemFont(ofSize: 11)
        view.addSubview(coordLabel)

        let cycleLabel = createLabel("Cycle ms", frame: NSRect(x: headerOffset + 345, y: y, width: 70, height: 16))
        cycleLabel.font = NSFont.boldSystemFont(ofSize: 11)
        view.addSubview(cycleLabel)

        let autoLabel = createLabel("Auto", frame: NSRect(x: headerOffset + 430, y: y, width: 40, height: 16))
        autoLabel.font = NSFont.boldSystemFont(ofSize: 11)
        view.addSubview(autoLabel)
        y -= 18  // header height (16) + small gap (2)

        // Scroll view for presets
        presetsScrollView = NSScrollView(frame: NSRect(x: 10, y: 60, width: 580, height: y - 60))
        presetsScrollView.hasVerticalScroller = true
        presetsScrollView.hasHorizontalScroller = false
        presetsScrollView.autohidesScrollers = true
        presetsScrollView.borderType = .bezelBorder

        presetsContainer = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 300))
        presetsScrollView.documentView = presetsContainer
        view.addSubview(presetsScrollView)

        // Add preset button
        addPresetButton = NSButton(frame: NSRect(x: 20, y: 25, width: 120, height: 24))
        addPresetButton.title = "Add Preset"
        addPresetButton.bezelStyle = .rounded
        addPresetButton.target = self
        addPresetButton.action = #selector(addPreset)
        view.addSubview(addPresetButton)

        // Help text
        let helpLabel = createLabel("Format: (x1,y1);(x2,y2) | Use | to add cycle positions. Press key again within timeout to cycle.", frame: NSRect(x: 150, y: 27, width: 360, height: 16))
        helpLabel.font = NSFont.systemFont(ofSize: 9)
        helpLabel.textColor = .secondaryLabelColor
        view.addSubview(helpLabel)

        // Reset button for this tab
        let resetButton = NSButton(frame: NSRect(x: 450, y: 25, width: 130, height: 24))
        resetButton.title = "Reset to Defaults"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetPresetsSettings)
        view.addSubview(resetButton)

        return view
    }

    @objc private func resetPresetsSettings() {
        // Clear existing rows
        for row in presetRows {
            row.removeFromSuperview()
        }
        presetRows.removeAll()

        // Add default presets
        for preset in MacTileSettings.defaultTilingPresets {
            addPresetRow(preset)
        }
        updatePresetsContainerHeight()
    }

    @objc private func addPreset() {
        guard presetRows.count < 30 else {
            let alert = NSAlert()
            alert.messageText = "Maximum Presets Reached"
            alert.informativeText = "You can have at most 30 presets."
            alert.alertStyle = .informational
            alert.runModal()
            return
        }

        let preset = TilingPreset(
            keyCode: 0,
            keyString: "",
            modifiers: 0,
            positions: [PresetPosition(startX: 0, startY: 0, endX: 0.5, endY: 1)],
            autoConfirm: true,
            cycleTimeout: 2000
        )
        addPresetRow(preset)
        updatePresetsContainerHeight()
    }

    private func addPresetRow(_ preset: TilingPreset) {
        let rowHeight: CGFloat = 35
        let y = CGFloat(presetRows.count) * rowHeight

        let row = PresetRowView(frame: NSRect(x: 0, y: y, width: 560, height: rowHeight), preset: preset)
        row.onDelete = { [weak self] in
            self?.removePresetRow(row)
        }
        presetsContainer.addSubview(row)
        presetRows.append(row)
    }

    private func removePresetRow(_ row: PresetRowView) {
        guard let index = presetRows.firstIndex(of: row) else { return }
        row.removeFromSuperview()
        presetRows.remove(at: index)

        // Reposition remaining rows
        for (i, row) in presetRows.enumerated() {
            let rowHeight: CGFloat = 35
            row.frame.origin.y = CGFloat(i) * rowHeight
        }
        updatePresetsContainerHeight()
    }

    private func updatePresetsContainerHeight() {
        let rowHeight: CGFloat = 35
        let height = max(300, CGFloat(presetRows.count) * rowHeight + 10)
        presetsContainer.frame.size.height = height

        // Flip y coordinates since we want newest at top
        for (i, row) in presetRows.enumerated() {
            row.frame.origin.y = height - CGFloat(i + 1) * rowHeight
        }

        presetsContainer.needsLayout = true
    }

    // MARK: - Focus Tab

    private func createFocusContent() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 460))

        var y: CGFloat = 420

        // Header
        let headerLabel = createLabel("Application Focus Presets", frame: NSRect(x: 20, y: y, width: 300, height: 20))
        headerLabel.font = NSFont.boldSystemFont(ofSize: 14)
        view.addSubview(headerLabel)
        y -= 20

        let descLabel = createLabel("Define keyboard shortcuts to quickly switch focus between application windows", frame: NSRect(x: 20, y: y, width: 560, height: 16))
        descLabel.font = NSFont.systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor
        view.addSubview(descLabel)
        y -= 30

        // Column headers
        let headerOffset: CGFloat = 12

        let shortcutLabel = createLabel("Shortcut", frame: NSRect(x: headerOffset + 5, y: y, width: 100, height: 16))
        shortcutLabel.font = NSFont.boldSystemFont(ofSize: 11)
        view.addSubview(shortcutLabel)

        let appLabel = createLabel("Application", frame: NSRect(x: headerOffset + 110, y: y, width: 180, height: 16))
        appLabel.font = NSFont.boldSystemFont(ofSize: 11)
        view.addSubview(appLabel)

        let globalLabel = createLabel("Global", frame: NSRect(x: headerOffset + 340, y: y, width: 50, height: 16))
        globalLabel.font = NSFont.boldSystemFont(ofSize: 11)
        view.addSubview(globalLabel)

        let overlayLabel = createLabel("Overlay", frame: NSRect(x: headerOffset + 400, y: y, width: 50, height: 16))
        overlayLabel.font = NSFont.boldSystemFont(ofSize: 11)
        view.addSubview(overlayLabel)

        let openLabel = createLabel("Open", frame: NSRect(x: headerOffset + 455, y: y, width: 40, height: 16))
        openLabel.font = NSFont.boldSystemFont(ofSize: 11)
        view.addSubview(openLabel)
        y -= 18

        // Scroll view for focus presets
        focusPresetsScrollView = NSScrollView(frame: NSRect(x: 10, y: 60, width: 580, height: y - 60))
        focusPresetsScrollView.hasVerticalScroller = true
        focusPresetsScrollView.hasHorizontalScroller = false
        focusPresetsScrollView.autohidesScrollers = true
        focusPresetsScrollView.borderType = .bezelBorder

        focusPresetsContainer = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 300))
        focusPresetsScrollView.documentView = focusPresetsContainer
        view.addSubview(focusPresetsScrollView)

        // Add preset button
        addFocusPresetButton = NSButton(frame: NSRect(x: 20, y: 25, width: 140, height: 24))
        addFocusPresetButton.title = "Add Focus Preset"
        addFocusPresetButton.bezelStyle = .rounded
        addFocusPresetButton.target = self
        addFocusPresetButton.action = #selector(addFocusPreset)
        view.addSubview(addFocusPresetButton)

        // Reset button for this tab (clears all focus presets since there are no defaults)
        let resetButton = NSButton(frame: NSRect(x: 450, y: 25, width: 130, height: 24))
        resetButton.title = "Clear All"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetFocusSettings)
        view.addSubview(resetButton)

        return view
    }

    @objc private func resetFocusSettings() {
        // Clear all focus presets (default is empty)
        for row in focusPresetRows {
            row.removeFromSuperview()
        }
        focusPresetRows.removeAll()
        updateFocusPresetsContainerHeight()
    }

    @objc private func addFocusPreset() {
        // Create a default focus preset
        let preset = FocusPreset(
            keyCode: 0,
            keyString: "",
            modifiers: 0,
            appBundleID: "",
            appName: "Select App...",
            worksWithoutOverlay: true,
            worksWithOverlay: true
        )
        addFocusPresetRow(preset)
        updateFocusPresetsContainerHeight()
    }

    private func addFocusPresetRow(_ preset: FocusPreset) {
        let rowHeight: CGFloat = 35
        let y = CGFloat(focusPresetRows.count) * rowHeight

        let row = FocusPresetRowView(frame: NSRect(x: 0, y: y, width: 560, height: rowHeight), preset: preset)
        row.onDelete = { [weak self, weak row] in
            guard let self = self, let row = row else { return }
            if let index = self.focusPresetRows.firstIndex(where: { $0 === row }) {
                self.focusPresetRows.remove(at: index)
                row.removeFromSuperview()
                self.updateFocusPresetsContainerHeight()
            }
        }
        focusPresetsContainer.addSubview(row)
        focusPresetRows.append(row)
    }

    private func loadFocusPresets() {
        let settings = SettingsManager.shared.settings

        // Clear existing rows
        for row in focusPresetRows {
            row.removeFromSuperview()
        }
        focusPresetRows.removeAll()

        // Add rows for existing presets
        for preset in settings.focusPresets {
            addFocusPresetRow(preset)
        }
        updateFocusPresetsContainerHeight()
    }

    private func updateFocusPresetsContainerHeight() {
        let rowHeight: CGFloat = 35
        let height = max(300, CGFloat(focusPresetRows.count) * rowHeight + 10)
        focusPresetsContainer.frame.size.height = height

        // Flip y coordinates since we want newest at top
        for (i, row) in focusPresetRows.enumerated() {
            row.frame.origin.y = height - CGFloat(i + 1) * rowHeight
        }

        focusPresetsContainer.needsLayout = true
    }

    private func createVirtualSpacesContent() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 460))

        var y: CGFloat = 420

        // Header
        let headerLabel = createLabel("Virtual Spaces", frame: NSRect(x: 20, y: y, width: 300, height: 20))
        headerLabel.font = NSFont.boldSystemFont(ofSize: 14)
        view.addSubview(headerLabel)
        y -= 18

        let descLabel = createLabel("Save and restore window arrangements with keyboard shortcuts (10 spaces per monitor)", frame: NSRect(x: 20, y: y, width: 560, height: 16))
        descLabel.font = NSFont.systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor
        view.addSubview(descLabel)
        y -= 28

        // Enable/Disable checkbox
        virtualSpacesEnabledCheckbox = NSButton(checkboxWithTitle: "Enable Virtual Spaces", target: nil, action: nil)
        virtualSpacesEnabledCheckbox.frame = NSRect(x: 20, y: y, width: 250, height: 20)
        view.addSubview(virtualSpacesEnabledCheckbox)
        y -= 24

        // Sketchybar integration checkbox
        sketchybarIntegrationCheckbox = NSButton(checkboxWithTitle: "Enable Sketchybar Integration", target: self, action: #selector(toggleSketchybarIntegration))
        sketchybarIntegrationCheckbox.frame = NSRect(x: 20, y: y, width: 250, height: 20)
        view.addSubview(sketchybarIntegrationCheckbox)

        let sketchybarHint = createLabel("Show virtual space indicators in sketchybar", frame: NSRect(x: 270, y: y, width: 300, height: 20))
        sketchybarHint.font = NSFont.systemFont(ofSize: 11)
        sketchybarHint.textColor = .secondaryLabelColor
        view.addSubview(sketchybarHint)
        y -= 32

        // Save Modifiers Section
        let saveModifiersLabel = createLabel("Save Modifiers:", frame: NSRect(x: 20, y: y, width: 120, height: 20))
        saveModifiersLabel.font = NSFont.boldSystemFont(ofSize: 13)
        view.addSubview(saveModifiersLabel)

        saveModifiersField = NSTextField(frame: NSRect(x: 140, y: y - 2, width: 100, height: 24))
        saveModifiersField.isEditable = false
        saveModifiersField.isSelectable = false
        saveModifiersField.alignment = .center
        saveModifiersField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        view.addSubview(saveModifiersField)

        saveModifiersRecordButton = NSButton(frame: NSRect(x: 250, y: y - 2, width: 80, height: 24))
        saveModifiersRecordButton.title = "Record"
        saveModifiersRecordButton.bezelStyle = .rounded
        saveModifiersRecordButton.target = self
        saveModifiersRecordButton.action = #selector(toggleRecordSaveModifiers)
        view.addSubview(saveModifiersRecordButton)

        let saveShortcutHint = createLabel("+ 0-9 to save", frame: NSRect(x: 340, y: y, width: 100, height: 20))
        saveShortcutHint.font = NSFont.systemFont(ofSize: 11)
        saveShortcutHint.textColor = .secondaryLabelColor
        view.addSubview(saveShortcutHint)
        y -= 28

        // Restore Modifiers Section
        let restoreModifiersLabel = createLabel("Restore Modifiers:", frame: NSRect(x: 20, y: y, width: 120, height: 20))
        restoreModifiersLabel.font = NSFont.boldSystemFont(ofSize: 13)
        view.addSubview(restoreModifiersLabel)

        restoreModifiersField = NSTextField(frame: NSRect(x: 140, y: y - 2, width: 100, height: 24))
        restoreModifiersField.isEditable = false
        restoreModifiersField.isSelectable = false
        restoreModifiersField.alignment = .center
        restoreModifiersField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        view.addSubview(restoreModifiersField)

        restoreModifiersRecordButton = NSButton(frame: NSRect(x: 250, y: y - 2, width: 80, height: 24))
        restoreModifiersRecordButton.title = "Record"
        restoreModifiersRecordButton.bezelStyle = .rounded
        restoreModifiersRecordButton.target = self
        restoreModifiersRecordButton.action = #selector(toggleRecordRestoreModifiers)
        view.addSubview(restoreModifiersRecordButton)

        let restoreShortcutHint = createLabel("+ 0-9 to restore", frame: NSRect(x: 340, y: y, width: 120, height: 20))
        restoreShortcutHint.font = NSFont.systemFont(ofSize: 11)
        restoreShortcutHint.textColor = .secondaryLabelColor
        view.addSubview(restoreShortcutHint)
        y -= 28

        // Clear Modifiers Section
        let clearModifiersLabel = createLabel("Clear Modifiers:", frame: NSRect(x: 20, y: y, width: 120, height: 20))
        clearModifiersLabel.font = NSFont.boldSystemFont(ofSize: 13)
        view.addSubview(clearModifiersLabel)

        clearModifiersField = NSTextField(frame: NSRect(x: 140, y: y - 2, width: 100, height: 24))
        clearModifiersField.isEditable = false
        clearModifiersField.isSelectable = false
        clearModifiersField.alignment = .center
        clearModifiersField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        view.addSubview(clearModifiersField)

        clearModifiersRecordButton = NSButton(frame: NSRect(x: 250, y: y - 2, width: 80, height: 24))
        clearModifiersRecordButton.title = "Record"
        clearModifiersRecordButton.bezelStyle = .rounded
        clearModifiersRecordButton.target = self
        clearModifiersRecordButton.action = #selector(toggleRecordClearModifiers)
        view.addSubview(clearModifiersRecordButton)

        let clearShortcutHint = createLabel("+ 0-9 to clear/unset", frame: NSRect(x: 340, y: y, width: 140, height: 20))
        clearShortcutHint.font = NSFont.systemFont(ofSize: 11)
        clearShortcutHint.textColor = .secondaryLabelColor
        view.addSubview(clearShortcutHint)
        y -= 20

        let recordHint = createLabel("Press modifier keys + Space to record new modifiers", frame: NSRect(x: 20, y: y, width: 400, height: 16))
        recordHint.font = NSFont.systemFont(ofSize: 11)
        recordHint.textColor = .tertiaryLabelColor
        view.addSubview(recordHint)
        y -= 28

        // Overlay Modifiers Section (when overlay is active)
        let overlayModifiersHeader = createLabel("Overlay Mode Modifiers:", frame: NSRect(x: 20, y: y, width: 200, height: 20))
        overlayModifiersHeader.font = NSFont.boldSystemFont(ofSize: 13)
        view.addSubview(overlayModifiersHeader)

        let overlayModifiersHint = createLabel("(while overlay is visible)", frame: NSRect(x: 220, y: y, width: 200, height: 20))
        overlayModifiersHint.font = NSFont.systemFont(ofSize: 11)
        overlayModifiersHint.textColor = .secondaryLabelColor
        view.addSubview(overlayModifiersHint)
        y -= 28

        // Overlay Save Modifiers
        let overlaySaveLabel = createLabel("Save:", frame: NSRect(x: 40, y: y, width: 80, height: 20))
        overlaySaveLabel.font = NSFont.systemFont(ofSize: 13)
        view.addSubview(overlaySaveLabel)

        overlaySaveModifiersField = NSTextField(frame: NSRect(x: 120, y: y - 2, width: 100, height: 24))
        overlaySaveModifiersField.isEditable = false
        overlaySaveModifiersField.isSelectable = false
        overlaySaveModifiersField.alignment = .center
        overlaySaveModifiersField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        view.addSubview(overlaySaveModifiersField)

        overlaySaveModifiersRecordButton = NSButton(frame: NSRect(x: 230, y: y - 2, width: 80, height: 24))
        overlaySaveModifiersRecordButton.title = "Record"
        overlaySaveModifiersRecordButton.bezelStyle = .rounded
        overlaySaveModifiersRecordButton.target = self
        overlaySaveModifiersRecordButton.action = #selector(toggleRecordOverlaySaveModifiers)
        view.addSubview(overlaySaveModifiersRecordButton)

        let overlaySaveHint = createLabel("+ 0-9 in overlay", frame: NSRect(x: 320, y: y, width: 120, height: 20))
        overlaySaveHint.font = NSFont.systemFont(ofSize: 11)
        overlaySaveHint.textColor = .secondaryLabelColor
        view.addSubview(overlaySaveHint)
        y -= 28

        // Overlay Clear Modifiers
        let overlayClearLabel = createLabel("Clear:", frame: NSRect(x: 40, y: y, width: 80, height: 20))
        overlayClearLabel.font = NSFont.systemFont(ofSize: 13)
        view.addSubview(overlayClearLabel)

        overlayClearModifiersField = NSTextField(frame: NSRect(x: 120, y: y - 2, width: 100, height: 24))
        overlayClearModifiersField.isEditable = false
        overlayClearModifiersField.isSelectable = false
        overlayClearModifiersField.alignment = .center
        overlayClearModifiersField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        view.addSubview(overlayClearModifiersField)

        overlayClearModifiersRecordButton = NSButton(frame: NSRect(x: 230, y: y - 2, width: 80, height: 24))
        overlayClearModifiersRecordButton.title = "Record"
        overlayClearModifiersRecordButton.bezelStyle = .rounded
        overlayClearModifiersRecordButton.target = self
        overlayClearModifiersRecordButton.action = #selector(toggleRecordOverlayClearModifiers)
        view.addSubview(overlayClearModifiersRecordButton)

        let overlayClearHint = createLabel("+ 0-9 in overlay", frame: NSRect(x: 320, y: y, width: 120, height: 20))
        overlayClearHint.font = NSFont.systemFont(ofSize: 11)
        overlayClearHint.textColor = .secondaryLabelColor
        view.addSubview(overlayClearHint)
        y -= 28

        // Additional shortcuts info
        let additionalLabel = createLabel("Rename Shortcut:", frame: NSRect(x: 20, y: y, width: 130, height: 20))
        additionalLabel.font = NSFont.boldSystemFont(ofSize: 13)
        view.addSubview(additionalLabel)

        let renameHint = createLabel("Restore modifiers + Comma (,) to rename active space", frame: NSRect(x: 150, y: y, width: 400, height: 20))
        renameHint.font = NSFont.systemFont(ofSize: 11)
        renameHint.textColor = .secondaryLabelColor
        view.addSubview(renameHint)
        y -= 32

        // Usage instructions
        let usageLabel = createLabel("How It Works:", frame: NSRect(x: 20, y: y, width: 200, height: 20))
        usageLabel.font = NSFont.boldSystemFont(ofSize: 13)
        view.addSubview(usageLabel)
        y -= 20

        let usageTexts = [
            "• Arrange windows, then press Save modifiers + number (0-9) to save",
            "• Press Restore modifiers + number to restore saved positions",
            "• Press Clear modifiers + number to unset/clear a saved space",
            "• Each monitor has its own 10 spaces; only ≥40% visible windows are saved"
        ]

        for text in usageTexts {
            let label = createLabel(text, frame: NSRect(x: 20, y: y, width: 550, height: 16))
            label.font = NSFont.systemFont(ofSize: 11)
            label.textColor = .secondaryLabelColor
            view.addSubview(label)
            y -= 16
        }

        // Reset button for this tab
        let resetButton = NSButton(frame: NSRect(x: 20, y: 15, width: 180, height: 24))
        resetButton.title = "Reset Spaces Settings"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetVirtualSpacesSettings)
        view.addSubview(resetButton)

        // Card backgrounds
        addCardBackground(to: view, frame: NSRect(x: 8, y: 270, width: 584, height: 170))
        addCardBackground(to: view, frame: NSRect(x: 8, y: 60, width: 584, height: 203))

        return view
    }

    @objc private func resetVirtualSpacesSettings() {
        let defaults = MacTileSettings.default

        virtualSpacesEnabledCheckbox.state = defaults.virtualSpacesEnabled ? .on : .off
        sketchybarIntegrationCheckbox.state = defaults.sketchybarIntegrationEnabled ? .on : .off
        recordedSaveModifiers = defaults.virtualSpaceSaveModifiers
        recordedRestoreModifiers = defaults.virtualSpaceRestoreModifiers
        recordedClearModifiers = defaults.virtualSpaceClearModifiers
        saveModifiersField.stringValue = OverlayKeyboardSettings.modifierDisplayString(defaults.virtualSpaceSaveModifiers)
        restoreModifiersField.stringValue = OverlayKeyboardSettings.modifierDisplayString(defaults.virtualSpaceRestoreModifiers)
        clearModifiersField.stringValue = OverlayKeyboardSettings.modifierDisplayString(defaults.virtualSpaceClearModifiers)

        // Overlay modifiers
        recordedOverlaySaveModifiers = defaults.overlayVirtualSpaceSaveModifiers
        recordedOverlayClearModifiers = defaults.overlayVirtualSpaceClearModifiers
        overlaySaveModifiersField.stringValue = OverlayKeyboardSettings.modifierDisplayString(defaults.overlayVirtualSpaceSaveModifiers)
        overlayClearModifiersField.stringValue = OverlayKeyboardSettings.modifierDisplayString(defaults.overlayVirtualSpaceClearModifiers)
    }

    @objc private func toggleSketchybarIntegration() {
        let isEnabled = sketchybarIntegrationCheckbox.state == .on

        // Update settings immediately
        SettingsManager.shared.updateSketchybarIntegration(isEnabled)

        if isEnabled {
            // Enable integration - deploy files and restart sketchybar
            let result = SketchybarIntegration.shared.enableIntegration()

            switch result {
            case .success:
                print("[Settings] Sketchybar integration enabled successfully")
            case .failure(let error):
                if case .sketchybarrcNotConfigured = error {
                    // sketchybarrc exists but not configured - show modal
                    SketchybarIntegration.shared.deployExampleSketchybarrc()
                    SketchybarIntegration.shared.showConfigurationRequiredAlert()
                } else {
                    // Other error - show alert
                    let alert = NSAlert()
                    alert.messageText = "Sketchybar Integration Error"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        } else {
            // Disable integration - just restart sketchybar
            SketchybarIntegration.shared.disableIntegration()
            print("[Settings] Sketchybar integration disabled")
        }
    }

    @objc private func toggleRecordSaveModifiers() {
        isRecordingSaveModifiers.toggle()

        if isRecordingSaveModifiers {
            saveModifiersRecordButton.title = "Press Keys..."
            saveModifiersField.stringValue = "..."
            window?.makeFirstResponder(window?.contentView)

            // Remove any existing monitor first
            if let monitor = saveModifiersMonitor {
                NSEvent.removeMonitor(monitor)
                saveModifiersMonitor = nil
            }

            // Set up local event monitor to capture modifier keys + space
            saveModifiersMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, self.isRecordingSaveModifiers else { return event }

                // Handle Escape to cancel
                if event.keyCode == 53 {
                    self.isRecordingSaveModifiers = false
                    self.saveModifiersRecordButton.title = "Record"
                    if let monitor = self.saveModifiersMonitor {
                        NSEvent.removeMonitor(monitor)
                        self.saveModifiersMonitor = nil
                    }
                    self.loadVirtualSpacesSettings()
                    return nil
                }

                // Only accept Space to confirm (keyCode 49)
                if event.keyCode == 49 {
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

                    // Need at least one modifier
                    if modifiers == 0 {
                        return nil
                    }

                    self.recordedSaveModifiers = modifiers
                    self.saveModifiersField.stringValue = OverlayKeyboardSettings.modifierDisplayString(modifiers)
                    self.isRecordingSaveModifiers = false
                    self.saveModifiersRecordButton.title = "Record"

                    if let monitor = self.saveModifiersMonitor {
                        NSEvent.removeMonitor(monitor)
                        self.saveModifiersMonitor = nil
                    }
                    return nil
                }

                return nil  // Consume other keys while recording
            }
        } else {
            saveModifiersRecordButton.title = "Record"
            if let monitor = saveModifiersMonitor {
                NSEvent.removeMonitor(monitor)
                saveModifiersMonitor = nil
            }
        }
    }

    @objc private func toggleRecordRestoreModifiers() {
        isRecordingRestoreModifiers.toggle()

        if isRecordingRestoreModifiers {
            restoreModifiersRecordButton.title = "Press Keys..."
            restoreModifiersField.stringValue = "..."
            window?.makeFirstResponder(window?.contentView)

            // Remove any existing monitor first
            if let monitor = restoreModifiersMonitor {
                NSEvent.removeMonitor(monitor)
                restoreModifiersMonitor = nil
            }

            // Set up local event monitor to capture modifier keys + space
            restoreModifiersMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, self.isRecordingRestoreModifiers else { return event }

                // Handle Escape to cancel
                if event.keyCode == 53 {
                    self.isRecordingRestoreModifiers = false
                    self.restoreModifiersRecordButton.title = "Record"
                    if let monitor = self.restoreModifiersMonitor {
                        NSEvent.removeMonitor(monitor)
                        self.restoreModifiersMonitor = nil
                    }
                    self.loadVirtualSpacesSettings()
                    return nil
                }

                // Only accept Space to confirm (keyCode 49)
                if event.keyCode == 49 {
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

                    // Need at least one modifier
                    if modifiers == 0 {
                        return nil
                    }

                    self.recordedRestoreModifiers = modifiers
                    self.restoreModifiersField.stringValue = OverlayKeyboardSettings.modifierDisplayString(modifiers)
                    self.isRecordingRestoreModifiers = false
                    self.restoreModifiersRecordButton.title = "Record"

                    if let monitor = self.restoreModifiersMonitor {
                        NSEvent.removeMonitor(monitor)
                        self.restoreModifiersMonitor = nil
                    }
                    return nil
                }

                return nil  // Consume other keys while recording
            }
        } else {
            restoreModifiersRecordButton.title = "Record"
            if let monitor = restoreModifiersMonitor {
                NSEvent.removeMonitor(monitor)
                restoreModifiersMonitor = nil
            }
        }
    }

    @objc private func toggleRecordClearModifiers() {
        isRecordingClearModifiers.toggle()

        if isRecordingClearModifiers {
            clearModifiersRecordButton.title = "Press Keys..."
            clearModifiersField.stringValue = "..."
            window?.makeFirstResponder(window?.contentView)

            // Remove any existing monitor first
            if let monitor = clearModifiersMonitor {
                NSEvent.removeMonitor(monitor)
                clearModifiersMonitor = nil
            }

            // Set up local event monitor to capture modifier keys + space
            clearModifiersMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, self.isRecordingClearModifiers else { return event }

                // Handle Escape to cancel
                if event.keyCode == 53 {
                    self.isRecordingClearModifiers = false
                    self.clearModifiersRecordButton.title = "Record"
                    if let monitor = self.clearModifiersMonitor {
                        NSEvent.removeMonitor(monitor)
                        self.clearModifiersMonitor = nil
                    }
                    self.loadVirtualSpacesSettings()
                    return nil
                }

                // Only accept Space to confirm (keyCode 49)
                if event.keyCode == 49 {
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

                    // Need at least one modifier
                    if modifiers == 0 {
                        return nil
                    }

                    self.recordedClearModifiers = modifiers
                    self.clearModifiersField.stringValue = OverlayKeyboardSettings.modifierDisplayString(modifiers)
                    self.isRecordingClearModifiers = false
                    self.clearModifiersRecordButton.title = "Record"

                    if let monitor = self.clearModifiersMonitor {
                        NSEvent.removeMonitor(monitor)
                        self.clearModifiersMonitor = nil
                    }
                    return nil
                }

                return nil  // Consume other keys while recording
            }
        } else {
            clearModifiersRecordButton.title = "Record"
            if let monitor = clearModifiersMonitor {
                NSEvent.removeMonitor(monitor)
                clearModifiersMonitor = nil
            }
        }
    }

    @objc private func toggleRecordOverlaySaveModifiers() {
        isRecordingOverlaySaveModifiers.toggle()

        if isRecordingOverlaySaveModifiers {
            overlaySaveModifiersRecordButton.title = "Press Keys..."
            overlaySaveModifiersField.stringValue = "..."
            window?.makeFirstResponder(window?.contentView)

            if let monitor = overlaySaveModifiersMonitor {
                NSEvent.removeMonitor(monitor)
                overlaySaveModifiersMonitor = nil
            }

            overlaySaveModifiersMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, self.isRecordingOverlaySaveModifiers else { return event }

                if event.keyCode == 53 {
                    self.isRecordingOverlaySaveModifiers = false
                    self.overlaySaveModifiersRecordButton.title = "Record"
                    if let monitor = self.overlaySaveModifiersMonitor {
                        NSEvent.removeMonitor(monitor)
                        self.overlaySaveModifiersMonitor = nil
                    }
                    self.loadVirtualSpacesSettings()
                    return nil
                }

                if event.keyCode == 49 {
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

                    // Allow no modifiers for overlay (just number keys)
                    self.recordedOverlaySaveModifiers = modifiers
                    self.overlaySaveModifiersField.stringValue = modifiers == 0 ? "None" : OverlayKeyboardSettings.modifierDisplayString(modifiers)
                    self.isRecordingOverlaySaveModifiers = false
                    self.overlaySaveModifiersRecordButton.title = "Record"

                    if let monitor = self.overlaySaveModifiersMonitor {
                        NSEvent.removeMonitor(monitor)
                        self.overlaySaveModifiersMonitor = nil
                    }

                    // Save immediately
                    SettingsManager.shared.updateOverlayVirtualSpaceModifiers(
                        save: self.recordedOverlaySaveModifiers,
                        clear: self.recordedOverlayClearModifiers
                    )
                    return nil
                }

                return nil
            }
        } else {
            overlaySaveModifiersRecordButton.title = "Record"
            if let monitor = overlaySaveModifiersMonitor {
                NSEvent.removeMonitor(monitor)
                overlaySaveModifiersMonitor = nil
            }
        }
    }

    @objc private func toggleRecordOverlayClearModifiers() {
        isRecordingOverlayClearModifiers.toggle()

        if isRecordingOverlayClearModifiers {
            overlayClearModifiersRecordButton.title = "Press Keys..."
            overlayClearModifiersField.stringValue = "..."
            window?.makeFirstResponder(window?.contentView)

            if let monitor = overlayClearModifiersMonitor {
                NSEvent.removeMonitor(monitor)
                overlayClearModifiersMonitor = nil
            }

            overlayClearModifiersMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, self.isRecordingOverlayClearModifiers else { return event }

                if event.keyCode == 53 {
                    self.isRecordingOverlayClearModifiers = false
                    self.overlayClearModifiersRecordButton.title = "Record"
                    if let monitor = self.overlayClearModifiersMonitor {
                        NSEvent.removeMonitor(monitor)
                        self.overlayClearModifiersMonitor = nil
                    }
                    self.loadVirtualSpacesSettings()
                    return nil
                }

                if event.keyCode == 49 {
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

                    // Need at least one modifier for clear (to avoid accidental clears)
                    if modifiers == 0 {
                        return nil
                    }

                    self.recordedOverlayClearModifiers = modifiers
                    self.overlayClearModifiersField.stringValue = OverlayKeyboardSettings.modifierDisplayString(modifiers)
                    self.isRecordingOverlayClearModifiers = false
                    self.overlayClearModifiersRecordButton.title = "Record"

                    if let monitor = self.overlayClearModifiersMonitor {
                        NSEvent.removeMonitor(monitor)
                        self.overlayClearModifiersMonitor = nil
                    }

                    // Save immediately
                    SettingsManager.shared.updateOverlayVirtualSpaceModifiers(
                        save: self.recordedOverlaySaveModifiers,
                        clear: self.recordedOverlayClearModifiers
                    )
                    return nil
                }

                return nil
            }
        } else {
            overlayClearModifiersRecordButton.title = "Record"
            if let monitor = overlayClearModifiersMonitor {
                NSEvent.removeMonitor(monitor)
                overlayClearModifiersMonitor = nil
            }
        }
    }

    private func loadVirtualSpacesSettings() {
        let settings = SettingsManager.shared.settings

        virtualSpacesEnabledCheckbox.state = settings.virtualSpacesEnabled ? .on : .off
        sketchybarIntegrationCheckbox.state = settings.sketchybarIntegrationEnabled ? .on : .off
        recordedSaveModifiers = settings.virtualSpaceSaveModifiers
        recordedRestoreModifiers = settings.virtualSpaceRestoreModifiers
        recordedClearModifiers = settings.virtualSpaceClearModifiers
        saveModifiersField.stringValue = OverlayKeyboardSettings.modifierDisplayString(settings.virtualSpaceSaveModifiers)
        restoreModifiersField.stringValue = OverlayKeyboardSettings.modifierDisplayString(settings.virtualSpaceRestoreModifiers)
        clearModifiersField.stringValue = OverlayKeyboardSettings.modifierDisplayString(settings.virtualSpaceClearModifiers)

        // Overlay modifiers
        recordedOverlaySaveModifiers = settings.overlayVirtualSpaceSaveModifiers
        recordedOverlayClearModifiers = settings.overlayVirtualSpaceClearModifiers
        overlaySaveModifiersField.stringValue = settings.overlayVirtualSpaceSaveModifiers == 0 ? "None" : OverlayKeyboardSettings.modifierDisplayString(settings.overlayVirtualSpaceSaveModifiers)
        overlayClearModifiersField.stringValue = OverlayKeyboardSettings.modifierDisplayString(settings.overlayVirtualSpaceClearModifiers)
    }

    private func createAboutContent() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 460))

        let centerX = view.bounds.width / 2

        // App icon
        let iconSize: CGFloat = 128
        let iconView = NSImageView(frame: NSRect(
            x: centerX - iconSize / 2,
            y: 280,
            width: iconSize,
            height: iconSize
        ))

        // Try to load the app icon from multiple sources
        iconView.image = loadAppIcon()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        view.addSubview(iconView)

        // App name
        let nameLabel = NSTextField(frame: NSRect(x: 0, y: 240, width: view.bounds.width, height: 30))
        nameLabel.stringValue = "MacTile"
        nameLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        nameLabel.alignment = .center
        nameLabel.isBordered = false
        nameLabel.isEditable = false
        nameLabel.isSelectable = false
        nameLabel.backgroundColor = .clear
        view.addSubview(nameLabel)

        // Version
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.5"
        let versionLabel = NSTextField(frame: NSRect(x: 0, y: 215, width: view.bounds.width, height: 20))
        versionLabel.stringValue = "Version \(version)"
        versionLabel.font = NSFont.systemFont(ofSize: 13)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center
        versionLabel.isBordered = false
        versionLabel.isEditable = false
        versionLabel.isSelectable = false
        versionLabel.backgroundColor = .clear
        view.addSubview(versionLabel)

        // Description
        let descLabel = NSTextField(frame: NSRect(x: 40, y: 175, width: view.bounds.width - 80, height: 30))
        descLabel.stringValue = "A macOS window tiling app inspired by gTile"
        descLabel.font = NSFont.systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabelColor
        descLabel.alignment = .center
        descLabel.isBordered = false
        descLabel.isEditable = false
        descLabel.isSelectable = false
        descLabel.backgroundColor = .clear
        view.addSubview(descLabel)

        // GitHub link button
        let githubButton = NSButton(frame: NSRect(x: centerX - 100, y: 130, width: 200, height: 30))
        githubButton.title = "GitHub Repository"
        githubButton.bezelStyle = .rounded
        githubButton.target = self
        githubButton.action = #selector(openGitHubRepo)
        view.addSubview(githubButton)

        // GitHub URL label
        let urlLabel = NSTextField(frame: NSRect(x: 0, y: 105, width: view.bounds.width, height: 20))
        urlLabel.stringValue = "github.com/yashas-salankimatt/MacTile"
        urlLabel.font = NSFont.systemFont(ofSize: 11)
        urlLabel.textColor = .tertiaryLabelColor
        urlLabel.alignment = .center
        urlLabel.isBordered = false
        urlLabel.isEditable = false
        urlLabel.isSelectable = true
        urlLabel.backgroundColor = .clear
        view.addSubview(urlLabel)

        return view
    }

    @objc private func openGitHubRepo() {
        if let url = URL(string: "https://github.com/yashas-salankimatt/MacTile") {
            NSWorkspace.shared.open(url)
        }
    }

    private func loadAppIcon() -> NSImage? {
        // 1. Try loading from bundle resources (when running as .app)
        if let bundleIcon = Bundle.main.image(forResource: "AppIcon") {
            return bundleIcon
        }

        // 2. Try the application icon name (when running as .app)
        if let appIcon = NSImage(named: NSImage.applicationIconName),
           appIcon.size.width > 0 {
            return appIcon
        }

        // 3. Try loading from Resources directory relative to executable (development)
        let executableURL = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])

        // When running via swift run, executable is in .build/debug/
        // Resources are in project root /Resources/
        var resourcesURL = executableURL
            .deletingLastPathComponent() // Remove executable name
            .deletingLastPathComponent() // Remove 'debug'
            .deletingLastPathComponent() // Remove '.build'
            .appendingPathComponent("Resources")
            .appendingPathComponent("AppIcon.icns")

        if let icon = NSImage(contentsOf: resourcesURL) {
            return icon
        }

        // 4. Also try going up from .build/arm64-apple-macosx/debug/ structure
        resourcesURL = executableURL
            .deletingLastPathComponent() // Remove executable name
            .deletingLastPathComponent() // Remove 'debug'
            .deletingLastPathComponent() // Remove 'arm64-apple-macosx'
            .deletingLastPathComponent() // Remove '.build'
            .appendingPathComponent("Resources")
            .appendingPathComponent("AppIcon.icns")

        if let icon = NSImage(contentsOf: resourcesURL) {
            return icon
        }

        // 5. Fall back to system grid icon
        if let gridIcon = NSImage(systemSymbolName: "square.grid.3x3", accessibilityDescription: "MacTile") {
            // Make it larger and more visible
            let config = NSImage.SymbolConfiguration(pointSize: 64, weight: .regular)
            return gridIcon.withSymbolConfiguration(config)
        }

        return nil
    }

    // MARK: - Appearance Slider Actions

    @objc private func overlayOpacityChanged() {
        overlayOpacityLabel.stringValue = "\(Int(overlayOpacitySlider.doubleValue * 100))%"
    }

    @objc private func gridLineOpacityChanged() {
        gridLineOpacityLabel.stringValue = "\(Int(gridLineOpacitySlider.doubleValue * 100))%"
    }

    @objc private func gridLineWidthChanged() {
        gridLineWidthLabel.stringValue = String(format: "%.1f px", gridLineWidthSlider.doubleValue)
    }

    @objc private func selectionFillOpacityChanged() {
        selectionFillOpacityLabel.stringValue = "\(Int(selectionFillOpacitySlider.doubleValue * 100))%"
    }

    @objc private func selectionBorderWidthChanged() {
        selectionBorderWidthLabel.stringValue = String(format: "%.1f px", selectionBorderWidthSlider.doubleValue)
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
        launchAtLoginCheckbox.state = settings.launchAtLogin ? .on : .off
        confirmOnClickCheckbox.state = settings.confirmOnClickWithoutDrag ? .on : .off

        // Overlay Display
        showHelpTextCheckbox.state = settings.showHelpText ? .on : .off
        showMonitorIndicatorCheckbox.state = settings.showMonitorIndicator ? .on : .off

        // Primary shortcut
        shortcutField.stringValue = settings.toggleOverlayShortcut.displayString
        recordedShortcut = settings.toggleOverlayShortcut

        // Secondary shortcut
        if let secondary = settings.secondaryToggleOverlayShortcut {
            secondaryShortcutField.stringValue = secondary.displayString
            recordedSecondaryShortcut = secondary
            hasSecondaryShortcut = true
            secondaryShortcutClearButton.isEnabled = true
        } else {
            secondaryShortcutField.stringValue = "Not set"
            secondaryShortcutField.textColor = .secondaryLabelColor
            recordedSecondaryShortcut = nil
            hasSecondaryShortcut = false
            secondaryShortcutClearButton.isEnabled = false
        }

        // Overlay keyboard settings
        let keyboard = settings.overlayKeyboard
        panModifierPopup.selectItem(at: modifierToIndex(keyboard.panModifier))
        anchorModifierPopup.selectItem(at: modifierToIndex(keyboard.anchorModifier))
        targetModifierPopup.selectItem(at: modifierToIndex(keyboard.targetModifier))
        applyKeyPopup.selectItem(at: keyCodeToApplyIndex(keyboard.applyKeyCode))
        cancelKeyPopup.selectItem(at: keyCodeToCancelIndex(keyboard.cancelKeyCode))
        cycleGridKeyPopup.selectItem(at: keyCodeToCycleIndex(keyboard.cycleGridKeyCode))

        // Appearance settings
        let appearance = settings.appearance
        overlayColorWell.color = appearance.overlayBackgroundColor.nsColor
        overlayOpacitySlider.doubleValue = Double(appearance.overlayOpacity)
        overlayOpacityLabel.stringValue = "\(Int(appearance.overlayOpacity * 100))%"

        gridLineColorWell.color = appearance.gridLineColor.nsColor
        gridLineOpacitySlider.doubleValue = Double(appearance.gridLineOpacity)
        gridLineOpacityLabel.stringValue = "\(Int(appearance.gridLineOpacity * 100))%"
        gridLineWidthSlider.doubleValue = Double(appearance.gridLineWidth)
        gridLineWidthLabel.stringValue = String(format: "%.1f px", appearance.gridLineWidth)

        selectionFillColorWell.color = appearance.selectionFillColor.nsColor
        selectionFillOpacitySlider.doubleValue = Double(appearance.selectionFillOpacity)
        selectionFillOpacityLabel.stringValue = "\(Int(appearance.selectionFillOpacity * 100))%"

        selectionBorderColorWell.color = appearance.selectionBorderColor.nsColor
        selectionBorderWidthSlider.doubleValue = Double(appearance.selectionBorderWidth)
        selectionBorderWidthLabel.stringValue = String(format: "%.1f px", appearance.selectionBorderWidth)

        anchorMarkerColorWell.color = appearance.anchorMarkerColor.nsColor
        targetMarkerColorWell.color = appearance.targetMarkerColor.nsColor

        // Load presets
        // Clear existing preset rows
        for row in presetRows {
            row.removeFromSuperview()
        }
        presetRows.removeAll()

        // Add rows for existing presets
        for preset in settings.tilingPresets {
            addPresetRow(preset)
        }
        updatePresetsContainerHeight()

        // Load focus presets
        loadFocusPresets()

        // Load virtual spaces settings
        loadVirtualSpacesSettings()
    }

    // MARK: - Modifier/Key Conversion Helpers

    // Popup order: ["None", "Shift", "Option", "Control", "Command"]
    private func modifierToIndex(_ modifier: UInt) -> Int {
        switch modifier {
        case KeyboardShortcut.Modifiers.none: return 0
        case KeyboardShortcut.Modifiers.shift: return 1
        case KeyboardShortcut.Modifiers.option: return 2
        case KeyboardShortcut.Modifiers.control: return 3
        case KeyboardShortcut.Modifiers.command: return 4
        default: return 0  // Default to "None"
        }
    }

    private func indexToModifier(_ index: Int) -> UInt {
        switch index {
        case 0: return KeyboardShortcut.Modifiers.none
        case 1: return KeyboardShortcut.Modifiers.shift
        case 2: return KeyboardShortcut.Modifiers.option
        case 3: return KeyboardShortcut.Modifiers.control
        case 4: return KeyboardShortcut.Modifiers.command
        default: return KeyboardShortcut.Modifiers.none
        }
    }

    private func keyCodeToApplyIndex(_ keyCode: UInt16) -> Int {
        switch keyCode {
        case 36: return 0  // Enter
        case 49: return 1  // Space
        case 48: return 2  // Tab
        default: return 0
        }
    }

    private func applyIndexToKeyCode(_ index: Int) -> UInt16 {
        switch index {
        case 0: return 36  // Enter
        case 1: return 49  // Space
        case 2: return 48  // Tab
        default: return 36
        }
    }

    private func keyCodeToCancelIndex(_ keyCode: UInt16) -> Int {
        switch keyCode {
        case 53: return 0  // Escape
        case 12: return 1  // Q
        default: return 0
        }
    }

    private func cancelIndexToKeyCode(_ index: Int) -> UInt16 {
        switch index {
        case 0: return 53  // Escape
        case 1: return 12  // Q
        default: return 53
        }
    }

    private func keyCodeToCycleIndex(_ keyCode: UInt16) -> Int {
        switch keyCode {
        case 49: return 0  // Space
        case 48: return 1  // Tab
        case 5: return 2   // G
        default: return 0
        }
    }

    private func cycleIndexToKeyCode(_ index: Int) -> UInt16 {
        switch index {
        case 0: return 49  // Space
        case 1: return 48  // Tab
        case 2: return 5   // G
        default: return 49
        }
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

            // Remove any existing monitor first
            if let monitor = shortcutMonitor {
                NSEvent.removeMonitor(monitor)
                shortcutMonitor = nil
            }

            // Set up local event monitor and store it
            shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, self.isRecordingShortcut else { return event }

                // Get modifiers (mask to only the ones we care about)
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
                    if let monitor = self.shortcutMonitor {
                        NSEvent.removeMonitor(monitor)
                        self.shortcutMonitor = nil
                    }
                    self.loadCurrentSettings()
                    return nil
                }

                let keyString = self.keyCodeToString(event.keyCode)
                self.recordedShortcut = KeyboardShortcut(
                    keyCode: event.keyCode,
                    modifiers: modifiers,
                    keyString: keyString
                )

                print("Recorded shortcut: keyCode=\(event.keyCode), modifiers=\(modifiers), display=\(self.recordedShortcut?.displayString ?? "")")

                self.shortcutField.stringValue = self.recordedShortcut?.displayString ?? ""
                self.isRecordingShortcut = false
                self.shortcutRecordButton.title = "Record"

                // Remove the monitor
                if let monitor = self.shortcutMonitor {
                    NSEvent.removeMonitor(monitor)
                    self.shortcutMonitor = nil
                }

                return nil
            }
        } else {
            shortcutRecordButton.title = "Record"
            if let monitor = shortcutMonitor {
                NSEvent.removeMonitor(monitor)
                shortcutMonitor = nil
            }
            if recordedShortcut == nil {
                loadCurrentSettings()
            }
        }
    }

    @objc private func toggleRecordSecondaryShortcut() {
        isRecordingSecondaryShortcut.toggle()

        if isRecordingSecondaryShortcut {
            secondaryShortcutRecordButton.title = "Press Keys..."
            secondaryShortcutField.stringValue = "..."
            secondaryShortcutField.textColor = .labelColor
            window?.makeFirstResponder(window?.contentView)

            // Remove any existing monitor first
            if let monitor = secondaryShortcutMonitor {
                NSEvent.removeMonitor(monitor)
                secondaryShortcutMonitor = nil
            }

            // Set up local event monitor and store it
            secondaryShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, self.isRecordingSecondaryShortcut else { return event }

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
                    self.isRecordingSecondaryShortcut = false
                    self.secondaryShortcutRecordButton.title = "Record"
                    if let monitor = self.secondaryShortcutMonitor {
                        NSEvent.removeMonitor(monitor)
                        self.secondaryShortcutMonitor = nil
                    }
                    self.loadCurrentSettings()
                    return nil
                }

                let keyString = self.keyCodeToString(event.keyCode)
                self.recordedSecondaryShortcut = KeyboardShortcut(
                    keyCode: event.keyCode,
                    modifiers: modifiers,
                    keyString: keyString
                )

                print("Recorded secondary shortcut: keyCode=\(event.keyCode), modifiers=\(modifiers), display=\(self.recordedSecondaryShortcut?.displayString ?? "")")

                self.secondaryShortcutField.stringValue = self.recordedSecondaryShortcut?.displayString ?? ""
                self.secondaryShortcutField.textColor = .labelColor
                self.hasSecondaryShortcut = true
                self.secondaryShortcutClearButton.isEnabled = true
                self.isRecordingSecondaryShortcut = false
                self.secondaryShortcutRecordButton.title = "Record"

                // Remove the monitor
                if let monitor = self.secondaryShortcutMonitor {
                    NSEvent.removeMonitor(monitor)
                    self.secondaryShortcutMonitor = nil
                }

                return nil
            }
        } else {
            secondaryShortcutRecordButton.title = "Record"
            if let monitor = secondaryShortcutMonitor {
                NSEvent.removeMonitor(monitor)
                secondaryShortcutMonitor = nil
            }
            if !hasSecondaryShortcut {
                secondaryShortcutField.stringValue = "Not set"
                secondaryShortcutField.textColor = .secondaryLabelColor
            }
        }
    }

    @objc private func clearSecondaryShortcut() {
        recordedSecondaryShortcut = nil
        hasSecondaryShortcut = false
        secondaryShortcutField.stringValue = "Not set"
        secondaryShortcutField.textColor = .secondaryLabelColor
        secondaryShortcutClearButton.isEnabled = false
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
        SettingsManager.shared.updateLaunchAtLogin(launchAtLoginCheckbox.state == .on)
        SettingsManager.shared.updateConfirmOnClickWithoutDrag(confirmOnClickCheckbox.state == .on)

        // Update overlay display
        SettingsManager.shared.updateShowHelpText(showHelpTextCheckbox.state == .on)
        SettingsManager.shared.updateShowMonitorIndicator(showMonitorIndicatorCheckbox.state == .on)

        // Update primary shortcut
        if let shortcut = recordedShortcut {
            SettingsManager.shared.updateToggleOverlayShortcut(shortcut)
        }

        // Update secondary shortcut (can be nil to clear it)
        SettingsManager.shared.updateSecondaryToggleOverlayShortcut(
            hasSecondaryShortcut ? recordedSecondaryShortcut : nil
        )

        // Update overlay keyboard settings
        let keyboardSettings = OverlayKeyboardSettings(
            panModifier: indexToModifier(panModifierPopup.indexOfSelectedItem),
            anchorModifier: indexToModifier(anchorModifierPopup.indexOfSelectedItem),
            targetModifier: indexToModifier(targetModifierPopup.indexOfSelectedItem),
            applyKeyCode: applyIndexToKeyCode(applyKeyPopup.indexOfSelectedItem),
            cancelKeyCode: cancelIndexToKeyCode(cancelKeyPopup.indexOfSelectedItem),
            cycleGridKeyCode: cycleIndexToKeyCode(cycleGridKeyPopup.indexOfSelectedItem)
        )
        SettingsManager.shared.updateOverlayKeyboard(keyboardSettings)

        // Update appearance settings
        let appearanceSettings = AppearanceSettings(
            overlayBackgroundColor: SettingsColor(nsColor: overlayColorWell.color),
            overlayOpacity: CGFloat(overlayOpacitySlider.doubleValue),
            gridLineColor: SettingsColor(nsColor: gridLineColorWell.color),
            gridLineOpacity: CGFloat(gridLineOpacitySlider.doubleValue),
            gridLineWidth: CGFloat(gridLineWidthSlider.doubleValue),
            selectionFillColor: SettingsColor(nsColor: selectionFillColorWell.color),
            selectionFillOpacity: CGFloat(selectionFillOpacitySlider.doubleValue),
            selectionBorderColor: SettingsColor(nsColor: selectionBorderColorWell.color),
            selectionBorderWidth: CGFloat(selectionBorderWidthSlider.doubleValue),
            anchorMarkerColor: SettingsColor(nsColor: anchorMarkerColorWell.color),
            targetMarkerColor: SettingsColor(nsColor: targetMarkerColorWell.color)
        )
        SettingsManager.shared.updateAppearance(appearanceSettings)

        // Update tiling presets
        let presets = presetRows.compactMap { row -> TilingPreset? in
            let preset = row.getPreset()
            // Only include presets with a valid key binding
            if preset.keyCode > 0 && !preset.keyString.isEmpty {
                return preset
            }
            return nil
        }
        SettingsManager.shared.updateTilingPresets(presets)

        // Update focus presets
        let focusPresets = focusPresetRows.compactMap { row -> FocusPreset? in
            let preset = row.getPreset()
            // Only include presets with a valid key binding and app
            if preset.keyCode > 0 && !preset.keyString.isEmpty && !preset.appBundleID.isEmpty {
                return preset
            }
            return nil
        }
        SettingsManager.shared.updateFocusPresets(focusPresets)

        // Update virtual spaces settings
        SettingsManager.shared.updateVirtualSpacesEnabled(virtualSpacesEnabledCheckbox.state == .on)
        SettingsManager.shared.updateSketchybarIntegration(sketchybarIntegrationCheckbox.state == .on)
        SettingsManager.shared.updateVirtualSpaceModifiers(
            save: recordedSaveModifiers,
            restore: recordedRestoreModifiers,
            clear: recordedClearModifiers
        )

        window?.close()
    }
}

// Type alias for NSTextField used as label
typealias NSLabel = NSTextField

// MARK: - SettingsColor NSColor Extension

extension SettingsColor {
    /// Initialize from NSColor
    init(nsColor: NSColor) {
        let color = nsColor.usingColorSpace(.sRGB) ?? nsColor
        self.init(
            red: color.redComponent,
            green: color.greenComponent,
            blue: color.blueComponent,
            alpha: color.alphaComponent
        )
    }

    /// Convert to NSColor
    var nsColor: NSColor {
        return NSColor(
            srgbRed: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
    }
}

// MARK: - PresetRowView

/// A row view for editing a single tiling preset with single-button shortcut recording
class PresetRowView: NSView {
    private var recordButton: NSButton!
    private var coordinatesField: NSTextField!
    private var timeoutField: NSTextField!
    private var autoConfirmCheckbox: NSButton!
    private var deleteButton: NSButton!

    private var isRecording = false
    private var localMonitor: Any?

    var preset: TilingPreset {
        didSet {
            updateUI()
        }
    }

    var onDelete: (() -> Void)?

    init(frame: NSRect, preset: TilingPreset) {
        self.preset = preset
        super.init(frame: frame)
        setupUI()
        updateUI()
    }

    override init(frame: NSRect) {
        self.preset = TilingPreset(
            keyCode: 0,
            keyString: "",
            modifiers: 0,
            positions: [PresetPosition(startX: 0, startY: 0, endX: 0.5, endY: 1)],
            autoConfirm: true,
            cycleTimeout: 2000
        )
        super.init(frame: frame)
        setupUI()
        updateUI()
    }

    required init?(coder: NSCoder) {
        self.preset = TilingPreset(
            keyCode: 0,
            keyString: "",
            modifiers: 0,
            positions: [PresetPosition(startX: 0, startY: 0, endX: 0.5, endY: 1)],
            autoConfirm: true,
            cycleTimeout: 2000
        )
        super.init(coder: coder)
        setupUI()
        updateUI()
    }

    private func setupUI() {
        let y: CGFloat = 5
        var x: CGFloat = 5

        // Single record button that captures modifiers + key
        recordButton = NSButton(frame: NSRect(x: x, y: y, width: 100, height: 22))
        recordButton.title = "Record"
        recordButton.bezelStyle = .rounded
        recordButton.font = NSFont.systemFont(ofSize: 11)
        recordButton.target = self
        recordButton.action = #selector(toggleRecord)
        addSubview(recordButton)
        x += 105

        // Coordinates field (supports multiple positions with | separator)
        coordinatesField = NSTextField(frame: NSRect(x: x, y: y, width: 230, height: 22))
        coordinatesField.placeholderString = "(0,0);(0.5,1) | (0,0);(0.67,1)"
        coordinatesField.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        coordinatesField.target = self
        coordinatesField.action = #selector(coordinatesChanged)
        addSubview(coordinatesField)
        x += 235

        // Timeout field with ms label
        timeoutField = NSTextField(frame: NSRect(x: x, y: y, width: 55, height: 22))
        timeoutField.font = NSFont.systemFont(ofSize: 11)
        timeoutField.alignment = .right
        timeoutField.target = self
        timeoutField.action = #selector(timeoutChanged)
        addSubview(timeoutField)
        x += 55

        let msLabel = NSTextField(frame: NSRect(x: x, y: y + 3, width: 25, height: 16))
        msLabel.stringValue = "ms"
        msLabel.font = NSFont.systemFont(ofSize: 10)
        msLabel.isBordered = false
        msLabel.isEditable = false
        msLabel.backgroundColor = .clear
        addSubview(msLabel)
        x += 30

        // Auto-confirm checkbox
        autoConfirmCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(autoConfirmChanged))
        autoConfirmCheckbox.frame = NSRect(x: x, y: y, width: 22, height: 22)
        addSubview(autoConfirmCheckbox)
        x += 30

        // Delete button
        deleteButton = NSButton(frame: NSRect(x: x, y: y, width: 65, height: 22))
        deleteButton.title = "Delete"
        deleteButton.bezelStyle = .rounded
        deleteButton.font = NSFont.systemFont(ofSize: 11)
        deleteButton.target = self
        deleteButton.action = #selector(deletePressed)
        addSubview(deleteButton)
    }

    private func updateUI() {
        // Update record button with full shortcut display
        if preset.keyString.isEmpty {
            recordButton.title = "Record"
        } else {
            recordButton.title = preset.shortcutDisplayString
        }

        // Update coordinates
        coordinatesField.stringValue = preset.coordinateString

        // Update timeout
        timeoutField.stringValue = "\(preset.cycleTimeout)"

        // Update auto-confirm
        autoConfirmCheckbox.state = preset.autoConfirm ? .on : .off
    }

    @objc private func toggleRecord() {
        isRecording.toggle()

        if isRecording {
            recordButton.title = "Press key..."
            window?.makeFirstResponder(nil)

            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, self.isRecording else { return event }

                // Escape cancels recording
                if event.keyCode == 53 && !event.modifierFlags.contains(.shift) {
                    self.isRecording = false
                    self.updateUI()
                    if let monitor = self.localMonitor {
                        NSEvent.removeMonitor(monitor)
                        self.localMonitor = nil
                    }
                    return nil
                }

                // Don't allow Tab (reserved for monitor switching)
                if event.keyCode == 48 {
                    return nil
                }

                let keyString = self.keyCodeToString(event.keyCode)

                // Capture modifiers from the key event
                var modifiers: UInt = 0
                if event.modifierFlags.contains(.control) { modifiers |= KeyboardShortcut.Modifiers.control }
                if event.modifierFlags.contains(.option) { modifiers |= KeyboardShortcut.Modifiers.option }
                if event.modifierFlags.contains(.shift) { modifiers |= KeyboardShortcut.Modifiers.shift }
                if event.modifierFlags.contains(.command) { modifiers |= KeyboardShortcut.Modifiers.command }

                self.preset = TilingPreset(
                    keyCode: event.keyCode,
                    keyString: keyString,
                    modifiers: modifiers,
                    positions: self.preset.positions,
                    autoConfirm: self.preset.autoConfirm,
                    cycleTimeout: self.preset.cycleTimeout
                )

                self.isRecording = false
                if let monitor = self.localMonitor {
                    NSEvent.removeMonitor(monitor)
                    self.localMonitor = nil
                }
                return nil
            }
        } else {
            updateUI()
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
                localMonitor = nil
            }
        }
    }

    @objc private func coordinatesChanged() {
        let positions = TilingPreset.parsePositions(coordinatesField.stringValue)
        if !positions.isEmpty {
            preset = TilingPreset(
                keyCode: preset.keyCode,
                keyString: preset.keyString,
                modifiers: preset.modifiers,
                positions: positions,
                autoConfirm: preset.autoConfirm,
                cycleTimeout: preset.cycleTimeout
            )
        }
    }

    @objc private func timeoutChanged() {
        let timeout = Int(timeoutField.stringValue) ?? 2000
        preset = TilingPreset(
            keyCode: preset.keyCode,
            keyString: preset.keyString,
            modifiers: preset.modifiers,
            positions: preset.positions,
            autoConfirm: preset.autoConfirm,
            cycleTimeout: timeout
        )
    }

    @objc private func autoConfirmChanged() {
        preset = TilingPreset(
            keyCode: preset.keyCode,
            keyString: preset.keyString,
            modifiers: preset.modifiers,
            positions: preset.positions,
            autoConfirm: autoConfirmCheckbox.state == .on,
            cycleTimeout: preset.cycleTimeout
        )
    }

    @objc private func deletePressed() {
        onDelete?()
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String {
        let keyMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 49: "Space",
            50: "`", 51: "Delete", 53: "Escape",
            123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return keyMap[keyCode] ?? "Key\(keyCode)"
    }

    /// Get the current preset from UI state
    func getPreset() -> TilingPreset {
        // Parse positions from field in case user edited it
        let positions = TilingPreset.parsePositions(coordinatesField.stringValue)
        let timeout = Int(timeoutField.stringValue) ?? preset.cycleTimeout

        return TilingPreset(
            keyCode: preset.keyCode,
            keyString: preset.keyString,
            modifiers: preset.modifiers,
            positions: positions.isEmpty ? preset.positions : positions,
            autoConfirm: autoConfirmCheckbox.state == .on,
            cycleTimeout: timeout
        )
    }
}

// MARK: - FocusPresetRowView

/// A row view for editing a single focus preset
class FocusPresetRowView: NSView, NSMenuDelegate {
    private var recordButton: NSButton!
    private var appPopup: NSPopUpButton!
    private var globalCheckbox: NSButton!
    private var overlayCheckbox: NSButton!
    private var openCheckbox: NSButton!
    private var deleteButton: NSButton!

    private var isRecording = false
    private var localMonitor: Any?

    var preset: FocusPreset {
        didSet {
            updateUI()
        }
    }

    var onDelete: (() -> Void)?

    init(frame: NSRect, preset: FocusPreset) {
        self.preset = preset
        super.init(frame: frame)
        setupUI()
        updateUI()
    }

    override init(frame: NSRect) {
        self.preset = FocusPreset(
            keyCode: 0,
            keyString: "",
            modifiers: 0,
            appBundleID: "",
            appName: "Select App...",
            worksWithoutOverlay: true,
            worksWithOverlay: true
        )
        super.init(frame: frame)
        setupUI()
        updateUI()
    }

    required init?(coder: NSCoder) {
        self.preset = FocusPreset(
            keyCode: 0,
            keyString: "",
            modifiers: 0,
            appBundleID: "",
            appName: "Select App...",
            worksWithoutOverlay: true,
            worksWithOverlay: true
        )
        super.init(coder: coder)
        setupUI()
        updateUI()
    }

    private func setupUI() {
        let y: CGFloat = 5
        var x: CGFloat = 5

        // Record button for shortcut
        recordButton = NSButton(frame: NSRect(x: x, y: y, width: 100, height: 22))
        recordButton.title = "Record"
        recordButton.bezelStyle = .rounded
        recordButton.font = NSFont.systemFont(ofSize: 11)
        recordButton.target = self
        recordButton.action = #selector(toggleRecord)
        addSubview(recordButton)
        x += 105

        // App selection popup
        appPopup = NSPopUpButton(frame: NSRect(x: x, y: y, width: 220, height: 22))
        appPopup.font = NSFont.systemFont(ofSize: 11)
        appPopup.target = self
        appPopup.action = #selector(appSelected)
        populateAppPopup()
        appPopup.menu?.delegate = self
        addSubview(appPopup)
        x += 225

        // Global checkbox (works without overlay)
        globalCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(globalChanged))
        globalCheckbox.frame = NSRect(x: x, y: y, width: 22, height: 22)
        addSubview(globalCheckbox)
        x += 60

        // Overlay checkbox (works with overlay)
        overlayCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(overlayChanged))
        overlayCheckbox.frame = NSRect(x: x, y: y, width: 22, height: 22)
        addSubview(overlayCheckbox)
        x += 50

        // Open checkbox (open if not running)
        openCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(openChanged))
        openCheckbox.frame = NSRect(x: x, y: y, width: 22, height: 22)
        addSubview(openCheckbox)
        x += 40

        // Delete button
        deleteButton = NSButton(frame: NSRect(x: x, y: y, width: 65, height: 22))
        deleteButton.title = "Delete"
        deleteButton.bezelStyle = .rounded
        deleteButton.font = NSFont.systemFont(ofSize: 11)
        deleteButton.target = self
        deleteButton.action = #selector(deletePressed)
        addSubview(deleteButton)
    }

    private func populateAppPopup() {
        appPopup.removeAllItems()
        appPopup.addItem(withTitle: "Select App...")

        let runningApps = FocusManager.shared.getRunningApps()
        for app in runningApps {
            let item = NSMenuItem(title: app.name, action: nil, keyEquivalent: "")
            item.representedObject = app.bundleID
            appPopup.menu?.addItem(item)
        }
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === appPopup.menu else { return }

        // Remember current selection
        let currentBundleID = preset.appBundleID
        let currentAppName = preset.appName

        // Refresh the list with current running apps
        populateAppPopup()

        // Restore selection
        if !currentBundleID.isEmpty {
            var found = false
            for i in 0..<appPopup.numberOfItems {
                if let item = appPopup.item(at: i),
                   let bundleID = item.representedObject as? String,
                   bundleID == currentBundleID {
                    appPopup.selectItem(at: i)
                    found = true
                    break
                }
            }
            // If app not in running list, add it manually
            if !found && !currentAppName.isEmpty {
                let item = NSMenuItem(title: currentAppName, action: nil, keyEquivalent: "")
                item.representedObject = currentBundleID
                appPopup.menu?.addItem(item)
                appPopup.select(item)
            }
        }
    }

    private func updateUI() {
        // Update record button with full shortcut display
        if preset.keyString.isEmpty {
            recordButton.title = "Record"
        } else {
            recordButton.title = preset.shortcutDisplayString
        }

        // Update app popup selection
        if preset.appBundleID.isEmpty {
            appPopup.selectItem(at: 0)
        } else {
            // Find and select the matching app
            var found = false
            for i in 0..<appPopup.numberOfItems {
                if let item = appPopup.item(at: i),
                   let bundleID = item.representedObject as? String,
                   bundleID == preset.appBundleID {
                    appPopup.selectItem(at: i)
                    found = true
                    break
                }
            }
            // If app not found in running apps, add it manually
            if !found && !preset.appName.isEmpty {
                let item = NSMenuItem(title: preset.appName, action: nil, keyEquivalent: "")
                item.representedObject = preset.appBundleID
                appPopup.menu?.addItem(item)
                appPopup.select(item)
            }
        }

        // Update checkboxes
        globalCheckbox.state = preset.worksWithoutOverlay ? .on : .off
        overlayCheckbox.state = preset.worksWithOverlay ? .on : .off
        openCheckbox.state = preset.openIfNotRunning ? .on : .off
    }

    @objc private func toggleRecord() {
        isRecording.toggle()

        if isRecording {
            recordButton.title = "Press key..."
            window?.makeFirstResponder(nil)

            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, self.isRecording else { return event }

                // Escape cancels recording
                if event.keyCode == 53 && !event.modifierFlags.contains(.shift) {
                    self.isRecording = false
                    self.updateUI()
                    if let monitor = self.localMonitor {
                        NSEvent.removeMonitor(monitor)
                        self.localMonitor = nil
                    }
                    return nil
                }

                // Don't allow Tab
                if event.keyCode == 48 {
                    return nil
                }

                let keyString = self.keyCodeToString(event.keyCode)

                // Capture modifiers from the key event
                var modifiers: UInt = 0
                if event.modifierFlags.contains(.control) { modifiers |= KeyboardShortcut.Modifiers.control }
                if event.modifierFlags.contains(.option) { modifiers |= KeyboardShortcut.Modifiers.option }
                if event.modifierFlags.contains(.shift) { modifiers |= KeyboardShortcut.Modifiers.shift }
                if event.modifierFlags.contains(.command) { modifiers |= KeyboardShortcut.Modifiers.command }

                self.preset = FocusPreset(
                    keyCode: event.keyCode,
                    keyString: keyString,
                    modifiers: modifiers,
                    appBundleID: self.preset.appBundleID,
                    appName: self.preset.appName,
                    worksWithoutOverlay: self.preset.worksWithoutOverlay,
                    worksWithOverlay: self.preset.worksWithOverlay,
                    openIfNotRunning: self.preset.openIfNotRunning
                )

                self.isRecording = false
                if let monitor = self.localMonitor {
                    NSEvent.removeMonitor(monitor)
                    self.localMonitor = nil
                }
                return nil
            }
        } else {
            updateUI()
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
                localMonitor = nil
            }
        }
    }

    @objc private func appSelected() {
        guard let selectedItem = appPopup.selectedItem else { return }

        if let bundleID = selectedItem.representedObject as? String {
            preset = FocusPreset(
                keyCode: preset.keyCode,
                keyString: preset.keyString,
                modifiers: preset.modifiers,
                appBundleID: bundleID,
                appName: selectedItem.title,
                worksWithoutOverlay: preset.worksWithoutOverlay,
                worksWithOverlay: preset.worksWithOverlay,
                openIfNotRunning: preset.openIfNotRunning
            )
        }
    }

    @objc private func globalChanged() {
        preset = FocusPreset(
            keyCode: preset.keyCode,
            keyString: preset.keyString,
            modifiers: preset.modifiers,
            appBundleID: preset.appBundleID,
            appName: preset.appName,
            worksWithoutOverlay: globalCheckbox.state == .on,
            worksWithOverlay: preset.worksWithOverlay,
            openIfNotRunning: preset.openIfNotRunning
        )
    }

    @objc private func overlayChanged() {
        preset = FocusPreset(
            keyCode: preset.keyCode,
            keyString: preset.keyString,
            modifiers: preset.modifiers,
            appBundleID: preset.appBundleID,
            appName: preset.appName,
            worksWithoutOverlay: preset.worksWithoutOverlay,
            worksWithOverlay: overlayCheckbox.state == .on,
            openIfNotRunning: preset.openIfNotRunning
        )
    }

    @objc private func openChanged() {
        preset = FocusPreset(
            keyCode: preset.keyCode,
            keyString: preset.keyString,
            modifiers: preset.modifiers,
            appBundleID: preset.appBundleID,
            appName: preset.appName,
            worksWithoutOverlay: preset.worksWithoutOverlay,
            worksWithOverlay: preset.worksWithOverlay,
            openIfNotRunning: openCheckbox.state == .on
        )
    }

    @objc private func deletePressed() {
        onDelete?()
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String {
        let keyMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 49: "Space",
            50: "`", 51: "Delete", 53: "Escape",
            123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return keyMap[keyCode] ?? "Key\(keyCode)"
    }

    /// Get the current preset from UI state
    func getPreset() -> FocusPreset {
        return preset
    }
}
