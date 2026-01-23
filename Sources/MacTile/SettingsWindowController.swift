import AppKit
import MacTileCore
import HotKey

/// Window controller for MacTile settings
class SettingsWindowController: NSWindowController {
    private var tabView: NSTabView!

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
    private var showHelpTextCheckbox: NSButton!
    private var showMonitorIndicatorCheckbox: NSButton!

    // Shortcuts tab - Primary
    private var shortcutField: NSTextField!
    private var shortcutRecordButton: NSButton!
    private var isRecordingShortcut = false
    private var recordedShortcut: KeyboardShortcut?

    // Shortcuts tab - Secondary
    private var secondaryShortcutField: NSTextField!
    private var secondaryShortcutRecordButton: NSButton!
    private var secondaryShortcutClearButton: NSButton!
    private var isRecordingSecondaryShortcut = false
    private var recordedSecondaryShortcut: KeyboardShortcut?
    private var hasSecondaryShortcut = true

    private var panModifierPopup: NSPopUpButton!
    private var anchorModifierPopup: NSPopUpButton!
    private var targetModifierPopup: NSPopUpButton!
    private var applyKeyPopup: NSPopUpButton!
    private var cancelKeyPopup: NSPopUpButton!
    private var cycleGridKeyPopup: NSPopUpButton!

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
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 580),
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
        tabView = NSTabView(frame: NSRect(x: 20, y: 60, width: 540, height: 500))
        tabView.autoresizingMask = [.width, .height]

        // Add tabs
        let generalTab = createGeneralTab()
        generalTab.label = "General"
        tabView.addTabViewItem(generalTab)

        let shortcutsTab = createShortcutsTab()
        shortcutsTab.label = "Shortcuts"
        tabView.addTabViewItem(shortcutsTab)

        let appearanceTab = createAppearanceTab()
        appearanceTab.label = "Appearance"
        tabView.addTabViewItem(appearanceTab)

        let aboutTab = createAboutTab()
        aboutTab.label = "About"
        tabView.addTabViewItem(aboutTab)

        window.contentView?.addSubview(tabView)

        // Add buttons at the bottom
        let buttonY: CGFloat = 20

        let resetButton = NSButton(frame: NSRect(x: 20, y: buttonY, width: 150, height: 24))
        resetButton.title = "Reset to Defaults"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetToDefaults)
        window.contentView?.addSubview(resetButton)

        let applyButton = NSButton(frame: NSRect(x: 460, y: buttonY, width: 80, height: 24))
        applyButton.title = "Apply"
        applyButton.bezelStyle = .rounded
        applyButton.target = self
        applyButton.action = #selector(applySettings)
        applyButton.keyEquivalent = "\r"
        window.contentView?.addSubview(applyButton)
    }

    private func createGeneralTab() -> NSTabViewItem {
        let item = NSTabViewItem()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 460))

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
        y -= 25

        launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch MacTile at login", target: nil, action: nil)
        launchAtLoginCheckbox.frame = NSRect(x: 20, y: y, width: 350, height: 20)
        view.addSubview(launchAtLoginCheckbox)
        y -= 30

        // Overlay Display Section
        let overlayDisplayLabel = createLabel("Overlay Display:", frame: NSRect(x: 20, y: y, width: 100, height: 20))
        overlayDisplayLabel.font = NSFont.boldSystemFont(ofSize: 13)
        view.addSubview(overlayDisplayLabel)
        y -= 25

        showHelpTextCheckbox = NSButton(checkboxWithTitle: "Show help text at top of overlay", target: nil, action: nil)
        showHelpTextCheckbox.frame = NSRect(x: 20, y: y, width: 350, height: 20)
        view.addSubview(showHelpTextCheckbox)
        y -= 25

        showMonitorIndicatorCheckbox = NSButton(checkboxWithTitle: "Show monitor indicator (when multiple monitors)", target: nil, action: nil)
        showMonitorIndicatorCheckbox.frame = NSRect(x: 20, y: y, width: 400, height: 20)
        view.addSubview(showMonitorIndicatorCheckbox)

        item.view = view
        return item
    }

    private func createShortcutsTab() -> NSTabViewItem {
        let item = NSTabViewItem()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 460))

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

        item.view = view
        return item
    }

    private func createAppearanceTab() -> NSTabViewItem {
        let item = NSTabViewItem()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 460))

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

        item.view = view
        return item
    }

    private func createAboutTab() -> NSTabViewItem {
        let item = NSTabViewItem()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 460))

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
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
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

        item.view = view
        return item
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

    @objc private func toggleRecordSecondaryShortcut() {
        isRecordingSecondaryShortcut.toggle()

        if isRecordingSecondaryShortcut {
            secondaryShortcutRecordButton.title = "Press Keys..."
            secondaryShortcutField.stringValue = "..."
            secondaryShortcutField.textColor = .labelColor
            window?.makeFirstResponder(window?.contentView)

            // Set up local event monitor
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
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
                    self.loadCurrentSettings()
                    return nil
                }

                let keyString = self.keyCodeToString(event.keyCode)
                self.recordedSecondaryShortcut = KeyboardShortcut(
                    keyCode: event.keyCode,
                    modifiers: modifiers,
                    keyString: keyString
                )

                self.secondaryShortcutField.stringValue = self.recordedSecondaryShortcut?.displayString ?? ""
                self.secondaryShortcutField.textColor = .labelColor
                self.hasSecondaryShortcut = true
                self.secondaryShortcutClearButton.isEnabled = true
                self.isRecordingSecondaryShortcut = false
                self.secondaryShortcutRecordButton.title = "Record"

                return nil
            }
        } else {
            secondaryShortcutRecordButton.title = "Record"
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

        window?.close()
    }

    @objc private func resetToDefaults() {
        SettingsManager.shared.resetToDefaults()
        loadCurrentSettings()
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
