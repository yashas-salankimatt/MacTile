import AppKit
import MacTileCore

/// A panel that can become key even when the app is not active
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Controls the overlay window that displays the grid
class OverlayWindowController: NSWindowController {
    private var gridSize: GridSize
    private var currentSelection: GridSelection?
    private var gridView: GridOverlayView?
    private let windowTiler: WindowTiler

    // Store reference to the window we want to tile (before overlay appears)
    private var targetWindow: WindowInfo?

    // Multi-monitor support
    private var currentMonitorIndex: Int = 0

    // Computed properties for multi-monitor
    private var allScreens: [NSScreen] {
        return NSScreen.screens
    }

    private var currentScreen: NSScreen? {
        guard currentMonitorIndex >= 0 && currentMonitorIndex < allScreens.count else {
            return NSScreen.main
        }
        return allScreens[currentMonitorIndex]
    }

    private var monitorCount: Int {
        return allScreens.count
    }

    // Settings observer
    private var settingsObserver: NSObjectProtocol?

    init() {
        // Initialize from settings
        let settings = SettingsManager.shared.settings
        self.gridSize = settings.defaultGridSize

        // Initialize window tiler with real window manager
        self.windowTiler = WindowTiler(windowManager: RealWindowManager.shared)
        windowTiler.spacing = settings.windowSpacing
        windowTiler.insets = settings.insets

        // Create a panel instead of window - panels can receive keyboard input as floating windows
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let panel = KeyablePanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Panel configuration for floating keyboard-interactive overlay
        panel.level = .floating
        panel.isOpaque = false

        // Apply appearance settings for background
        let appearance = settings.appearance
        let bgColor = NSColor(
            red: appearance.overlayBackgroundColor.red,
            green: appearance.overlayBackgroundColor.green,
            blue: appearance.overlayBackgroundColor.blue,
            alpha: appearance.overlayOpacity
        )
        panel.backgroundColor = bgColor

        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hasShadow = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true

        super.init(window: panel)

        setupGridView()
        observeSettings()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func observeSettings() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .settingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadSettings()
        }
    }

    private func reloadSettings() {
        let settings = SettingsManager.shared.settings
        windowTiler.spacing = settings.windowSpacing
        windowTiler.insets = settings.insets
        gridView?.gridPresets = settings.gridSizes
        gridView?.keyboardSettings = settings.overlayKeyboard
        gridView?.appearanceSettings = settings.appearance
        gridView?.showHelpText = settings.showHelpText
        gridView?.showMonitorIndicator = settings.showMonitorIndicator

        // Update panel background
        let appearance = settings.appearance
        let bgColor = NSColor(
            red: appearance.overlayBackgroundColor.red,
            green: appearance.overlayBackgroundColor.green,
            blue: appearance.overlayBackgroundColor.blue,
            alpha: appearance.overlayOpacity
        )
        window?.backgroundColor = bgColor
    }

    private func setupGridView() {
        guard let window = window, let contentView = window.contentView else { return }

        let settings = SettingsManager.shared.settings
        let gridView = GridOverlayView(
            gridSize: gridSize,
            gridPresets: settings.gridSizes,
            keyboardSettings: settings.overlayKeyboard,
            appearanceSettings: settings.appearance
        )
        gridView.frame = contentView.bounds
        gridView.autoresizingMask = [.width, .height]
        gridView.showHelpText = settings.showHelpText
        gridView.showMonitorIndicator = settings.showMonitorIndicator
        gridView.onSelectionConfirmed = { [weak self] selection in
            self?.applySelection(selection)
        }
        gridView.onCancel = { [weak self] in
            self?.hideOverlay(cancelled: true)
        }
        gridView.onGridSizeChanged = { [weak self] newSize in
            self?.gridSize = newSize
        }
        gridView.onNextMonitor = { [weak self] in
            self?.moveToNextMonitor()
        }
        gridView.onPreviousMonitor = { [weak self] in
            self?.moveToPreviousMonitor()
        }
        contentView.addSubview(gridView)
        self.gridView = gridView

        // Set initial selection to top-left cell
        currentSelection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 0, row: 0)
        )
        gridView.selection = currentSelection
    }

    func setGridSize(_ size: GridSize) {
        gridSize = size
        gridView?.gridSize = size
        gridView?.selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 0, row: 0)
        )
        gridView?.needsDisplay = true
    }

    func showOverlay() {
        // Reload settings when showing overlay
        reloadSettings()

        // IMPORTANT: Capture window BEFORE any UI changes
        targetWindow = RealWindowManager.shared.getFocusedWindow()
        print("Captured target window: \(targetWindow?.title ?? "none")")

        // Determine which monitor to show the overlay on
        if let targetWindow = targetWindow {
            currentMonitorIndex = monitorIndexForWindow(targetWindow)
            print("[Monitor] Target window is on monitor \(currentMonitorIndex + 1)/\(monitorCount)")
        } else {
            currentMonitorIndex = 0
        }

        guard let screen = currentScreen else { return }

        // Calculate initial selection based on current window position on that monitor
        let initialSelection: GridSelection
        if let targetWindow = targetWindow {
            initialSelection = GridOperations.rectToSelection(
                rect: targetWindow.frame,
                gridSize: gridSize,
                screenFrame: screen.visibleFrame,
                insets: windowTiler.insets
            )
            print("Initial selection from window: cols \(initialSelection.anchor.col)-\(initialSelection.target.col)")
        } else {
            initialSelection = GridSelection(
                anchor: GridOffset(col: 0, row: 0),
                target: GridOffset(col: 0, row: 0)
            )
        }

        window?.setFrame(screen.frame, display: true)
        window?.makeKeyAndOrderFront(nil)

        // Activate the app so we can receive keyboard events
        NSApp.activate(ignoringOtherApps: true)

        // Ensure grid view frame matches screen size
        let viewFrame = NSRect(origin: .zero, size: screen.frame.size)
        gridView?.frame = viewFrame

        // Calculate top safe area (menu bar height)
        let topInset = screen.frame.maxY - screen.visibleFrame.maxY
        gridView?.topSafeAreaInset = max(0, topInset)

        // Make the grid view first responder for keyboard input
        if let gridView = gridView {
            let success = window?.makeFirstResponder(gridView) ?? false
            print("Made gridView first responder: \(success)")

            // Update monitor info in grid view
            gridView.currentMonitorIndex = currentMonitorIndex
            gridView.totalMonitors = monitorCount
        }

        // Set initial selection to match window position
        currentSelection = initialSelection
        gridView?.selection = currentSelection
        gridView?.needsDisplay = true
    }

    func hideOverlay(cancelled: Bool = false) {
        window?.orderOut(nil)

        // Return focus to target window if we're cancelling
        if cancelled, let targetWindow = targetWindow {
            RealWindowManager.shared.activateWindow(targetWindow)
        }

        targetWindow = nil
    }

    // MARK: - Multi-Monitor Support

    func moveToNextMonitor() {
        guard monitorCount > 1 else { return }
        let nextIndex = (currentMonitorIndex + 1) % monitorCount
        moveToMonitor(index: nextIndex)
    }

    func moveToPreviousMonitor() {
        guard monitorCount > 1 else { return }
        let prevIndex = (currentMonitorIndex - 1 + monitorCount) % monitorCount
        moveToMonitor(index: prevIndex)
    }

    private func moveToMonitor(index: Int) {
        guard index >= 0 && index < allScreens.count else { return }
        currentMonitorIndex = index

        guard let screen = currentScreen else { return }

        print("[Monitor] Switching to monitor \(index + 1)/\(monitorCount)")

        // Move and resize overlay to new monitor
        window?.setFrame(screen.frame, display: true)

        // Force layout update and set grid view frame explicitly
        // Use the screen size directly since contentView.bounds may not have updated yet
        let viewFrame = NSRect(origin: .zero, size: screen.frame.size)
        gridView?.frame = viewFrame

        // Force the content view to layout
        window?.contentView?.layoutSubtreeIfNeeded()

        // Calculate top safe area (menu bar height)
        // Menu bar is at the top, so it's the difference between frame.maxY and visibleFrame.maxY
        let topInset = screen.frame.maxY - screen.visibleFrame.maxY
        gridView?.topSafeAreaInset = max(0, topInset)

        // Update monitor info in grid view
        gridView?.currentMonitorIndex = currentMonitorIndex
        gridView?.totalMonitors = monitorCount
        gridView?.needsDisplay = true
    }

    /// Find which monitor contains the given point (window center)
    private func monitorIndexForPoint(_ point: CGPoint) -> Int {
        for (index, screen) in allScreens.enumerated() {
            if screen.frame.contains(point) {
                return index
            }
        }
        return 0 // Default to first monitor
    }

    /// Find which monitor the window is primarily on
    private func monitorIndexForWindow(_ window: WindowInfo) -> Int {
        // Use window center to determine which monitor it's on
        let centerX = window.frame.origin.x + window.frame.width / 2
        let centerY = window.frame.origin.y + window.frame.height / 2
        return monitorIndexForPoint(CGPoint(x: centerX, y: centerY))
    }

    private func applySelection(_ selection: GridSelection) {
        let settings = SettingsManager.shared.settings

        // Get reference to target window before hiding
        let windowToTile = targetWindow

        // Only hide if auto-close is enabled
        if settings.autoClose {
            hideOverlay()
        }

        // Check accessibility permissions first
        if !RealWindowManager.shared.hasAccessibilityPermissions() {
            print("No accessibility permissions - opening System Settings")
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "MacTile needs accessibility permission to move and resize windows.\n\nPlease:\n1. Open System Settings\n2. Go to Privacy & Security > Accessibility\n3. Enable MacTile (or the terminal you're running it from)\n4. Try again"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            return
        }

        // Use the captured window if available
        if let targetWindow = windowToTile {
            // Use the current monitor (where overlay is displayed) for tiling
            guard let screen = currentScreen else {
                print("No current screen found")
                return
            }

            print("[ApplySelection] ═══════════════════════════════════════════════")
            print("[ApplySelection] Tiling to monitor \(currentMonitorIndex + 1)/\(monitorCount)")
            print("[ApplySelection] Grid size: \(gridSize.cols)x\(gridSize.rows)")
            print("[ApplySelection] Selection: anchor=(\(selection.anchor.col),\(selection.anchor.row)) target=(\(selection.target.col),\(selection.target.row))")
            print("[ApplySelection] Normalized: \(selection.normalized)")
            print("[ApplySelection] Screen visible frame: \(screen.visibleFrame)")
            print("[ApplySelection] Spacing: \(windowTiler.spacing), Insets: \(windowTiler.insets)")

            let targetFrame = GridOperations.selectionToRect(
                selection: selection,
                gridSize: gridSize,
                screenFrame: screen.visibleFrame,
                spacing: windowTiler.spacing,
                insets: windowTiler.insets
            )

            print("[ApplySelection] Calculated target frame: \(targetFrame)")
            print("[ApplySelection] Target window: \(targetWindow.title) (current frame: \(targetWindow.frame))")

            let success = RealWindowManager.shared.setWindowFrame(targetWindow, frame: targetFrame)
            if success {
                print("[ApplySelection] ✓ Successfully tiled window: \(targetWindow.title)")
            } else {
                print("[ApplySelection] ✗ Failed to tile window: \(targetWindow.title)")
            }
            print("[ApplySelection] ═══════════════════════════════════════════════")

            // Return focus to the tiled window
            RealWindowManager.shared.activateWindow(targetWindow)
        } else {
            print("No target window captured - trying to get current focused window")
            let success = windowTiler.tileFocusedWindow(to: selection, gridSize: gridSize)
            if !success {
                print("Failed to tile window - check accessibility permissions")
            }
        }

        // If auto-close is disabled, reset selection for next operation
        if !settings.autoClose {
            gridView?.selection = GridSelection(
                anchor: GridOffset(col: 0, row: 0),
                target: GridOffset(col: 0, row: 0)
            )
        }
    }
}

/// View that displays the grid and handles keyboard input
/// Default: Pan mode (move entire selection)
/// Shift (configurable): Move first corner (anchor)
/// Option (configurable): Move second corner (target)
class GridOverlayView: NSView {
    var gridSize: GridSize {
        didSet {
            needsDisplay = true
        }
    }
    var selection: GridSelection? {
        didSet {
            needsDisplay = true
        }
    }
    var onSelectionConfirmed: ((GridSelection) -> Void)?
    var onCancel: (() -> Void)?
    var onGridSizeChanged: ((GridSize) -> Void)?
    var onNextMonitor: (() -> Void)?
    var onPreviousMonitor: (() -> Void)?

    private var isSelecting = false
    private var selectionAnchor: GridOffset?

    // Multi-monitor info (for display)
    var currentMonitorIndex: Int = 0 {
        didSet { needsDisplay = true }
    }
    var totalMonitors: Int = 1 {
        didSet { needsDisplay = true }
    }

    // Safe area inset from top (for menu bar)
    var topSafeAreaInset: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    // Display options
    var showHelpText: Bool = true {
        didSet { needsDisplay = true }
    }
    var showMonitorIndicator: Bool = true {
        didSet { needsDisplay = true }
    }

    var gridPresets: [GridSize]
    var keyboardSettings: OverlayKeyboardSettings
    var appearanceSettings: AppearanceSettings {
        didSet {
            needsDisplay = true
        }
    }

    init(gridSize: GridSize, gridPresets: [GridSize], keyboardSettings: OverlayKeyboardSettings, appearanceSettings: AppearanceSettings) {
        self.gridSize = gridSize
        self.gridPresets = gridPresets
        self.keyboardSettings = keyboardSettings
        self.appearanceSettings = appearanceSettings
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        print("GridOverlayView became first responder")
        return true
    }

    override func resignFirstResponder() -> Bool {
        print("GridOverlayView resigned first responder")
        return true
    }

    // Helper to convert SettingsColor to NSColor
    private func nsColor(_ color: SettingsColor, opacity: CGFloat? = nil) -> NSColor {
        return NSColor(
            red: color.red,
            green: color.green,
            blue: color.blue,
            alpha: opacity ?? color.alpha
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let cellWidth = bounds.width / CGFloat(gridSize.cols)
        let cellHeight = bounds.height / CGFloat(gridSize.rows)

        // Draw grid cells with alternating colors for visibility
        for row in 0..<gridSize.rows {
            for col in 0..<gridSize.cols {
                let x = CGFloat(col) * cellWidth
                let y = bounds.height - CGFloat(row + 1) * cellHeight

                let isAlternate = (row + col) % 2 == 0
                context.setFillColor(
                    isAlternate
                        ? nsColor(appearanceSettings.gridLineColor, opacity: 0.05).cgColor
                        : nsColor(appearanceSettings.gridLineColor, opacity: 0.1).cgColor
                )
                context.fill(CGRect(x: x, y: y, width: cellWidth, height: cellHeight))
            }
        }

        // Draw grid lines
        context.setStrokeColor(nsColor(appearanceSettings.gridLineColor, opacity: appearanceSettings.gridLineOpacity).cgColor)
        context.setLineWidth(appearanceSettings.gridLineWidth)

        // Vertical lines
        for col in 0...gridSize.cols {
            let x = CGFloat(col) * cellWidth
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: bounds.height))
        }

        // Horizontal lines
        for row in 0...gridSize.rows {
            let y = CGFloat(row) * cellHeight
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: bounds.width, y: y))
        }

        context.strokePath()

        // Draw selection highlight
        if let selection = selection {
            let normalized = selection.normalized
            let x = CGFloat(normalized.anchor.col) * cellWidth
            let y = bounds.height - CGFloat(normalized.target.row + 1) * cellHeight
            let width = CGFloat(selection.width) * cellWidth
            let height = CGFloat(selection.height) * cellHeight

            // Selection fill
            context.setFillColor(nsColor(appearanceSettings.selectionFillColor, opacity: appearanceSettings.selectionFillOpacity).cgColor)
            context.fill(CGRect(x: x, y: y, width: width, height: height))

            // Selection border
            context.setStrokeColor(nsColor(appearanceSettings.selectionBorderColor).cgColor)
            context.setLineWidth(appearanceSettings.selectionBorderWidth)
            context.stroke(CGRect(x: x, y: y, width: width, height: height))

            // Draw anchor marker (first corner - filled circle)
            let anchorX = CGFloat(selection.anchor.col) * cellWidth + cellWidth / 2 - 6
            let anchorY = bounds.height - CGFloat(selection.anchor.row + 1) * cellHeight + cellHeight / 2 - 6
            context.setFillColor(nsColor(appearanceSettings.anchorMarkerColor).cgColor)
            context.fillEllipse(in: CGRect(x: anchorX, y: anchorY, width: 12, height: 12))

            // Draw target marker (second corner - hollow circle)
            let targetX = CGFloat(selection.target.col) * cellWidth + cellWidth / 2 - 6
            let targetY = bounds.height - CGFloat(selection.target.row + 1) * cellHeight + cellHeight / 2 - 6
            context.setStrokeColor(nsColor(appearanceSettings.targetMarkerColor).cgColor)
            context.setLineWidth(2.0)
            context.strokeEllipse(in: CGRect(x: targetX, y: targetY, width: 12, height: 12))
        }

        // Draw grid size indicator
        let gridLabel = "\(gridSize.cols)x\(gridSize.rows)"
        let gridLabelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 24, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let gridLabelSize = gridLabel.size(withAttributes: gridLabelAttrs)
        gridLabel.draw(
            at: CGPoint(x: bounds.width - gridLabelSize.width - 20, y: 20),
            withAttributes: gridLabelAttrs
        )

        // Draw monitor indicator (when multiple monitors and setting enabled)
        if totalMonitors > 1 && showMonitorIndicator {
            let monitorLabel = "Monitor \(currentMonitorIndex + 1)/\(totalMonitors)"
            let monitorLabelAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.9)
            ]
            let monitorLabelSize = monitorLabel.size(withAttributes: monitorLabelAttrs)
            monitorLabel.draw(
                at: CGPoint(x: bounds.width - monitorLabelSize.width - 20, y: 50),
                withAttributes: monitorLabelAttrs
            )
        }

        // Draw instructions at top (if enabled)
        if showHelpText {
            let panMod = OverlayKeyboardSettings.modifierDisplayString(keyboardSettings.panModifier)
            let anchorMod = OverlayKeyboardSettings.modifierDisplayString(keyboardSettings.anchorModifier)
            let targetMod = OverlayKeyboardSettings.modifierDisplayString(keyboardSettings.targetModifier)
            let panStr = panMod == "None" ? "Arrows" : "\(panMod)+Arrows"
            let anchorStr = anchorMod == "None" ? "Arrows" : "\(anchorMod)+Arrows"
            let targetStr = targetMod == "None" ? "Arrows" : "\(targetMod)+Arrows"

            var instructions = "\(panStr): Pan | \(anchorStr): 1st corner | \(targetStr): 2nd corner | Enter: Apply | Esc: Cancel"

            // Add Tab instruction when multiple monitors
            if totalMonitors > 1 {
                instructions += " | Tab: Switch Monitor"
            }

            let instrAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: NSColor.white
            ]
            let instrSize = instructions.size(withAttributes: instrAttrs)
            let instrX = (bounds.width - instrSize.width) / 2
            // Account for menu bar / safe area at top
            let instrY = bounds.height - 40 - topSafeAreaInset
            instructions.draw(at: CGPoint(x: instrX, y: instrY), withAttributes: instrAttrs)
        }

        // Draw selection info with corner indicators
        if let selection = selection {
            let selInfo = "1st: (\(selection.anchor.col),\(selection.anchor.row)) → 2nd: (\(selection.target.col),\(selection.target.row)) | Size: \(selection.width)x\(selection.height)"
            let selAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                .foregroundColor: NSColor.white.withAlphaComponent(0.8)
            ]
            selInfo.draw(at: CGPoint(x: 20, y: 20), withAttributes: selAttrs)
        }
    }

    override func keyDown(with event: NSEvent) {
        print("Key pressed: \(event.keyCode), characters: \(event.characters ?? "nil")")

        guard var currentSelection = selection else {
            print("No selection available")
            return
        }

        // Get current modifier state
        let modifiers = event.modifierFlags
        var currentModifier: UInt = KeyboardShortcut.Modifiers.none
        if modifiers.contains(.shift) {
            currentModifier |= KeyboardShortcut.Modifiers.shift
        }
        if modifiers.contains(.option) {
            currentModifier |= KeyboardShortcut.Modifiers.option
        }
        if modifiers.contains(.control) {
            currentModifier |= KeyboardShortcut.Modifiers.control
        }
        if modifiers.contains(.command) {
            currentModifier |= KeyboardShortcut.Modifiers.command
        }

        // Determine mode based on modifier
        enum SelectionMode {
            case pan       // Move entire selection
            case anchor    // Move first corner
            case target    // Move second corner
        }

        let mode: SelectionMode
        if currentModifier == keyboardSettings.panModifier {
            mode = .pan
        } else if currentModifier == keyboardSettings.anchorModifier {
            mode = .anchor
        } else if currentModifier == keyboardSettings.targetModifier {
            mode = .target
        } else {
            // Unknown modifier combination, default to pan
            mode = .pan
        }

        var direction: Direction?

        // Handle by character for HJKL
        if let chars = event.charactersIgnoringModifiers?.lowercased() {
            switch chars {
            case "h":
                direction = .left
            case "l":
                direction = .right
            case "j":
                direction = .down
            case "k":
                direction = .up
            default:
                break
            }
        }

        // Handle by key code for special keys
        if direction == nil {
            switch event.keyCode {
            case 123: // Left
                direction = .left
            case 124: // Right
                direction = .right
            case 125: // Down
                direction = .down
            case 126: // Up
                direction = .up
            default:
                break
            }
        }

        // Handle action keys
        if event.keyCode == keyboardSettings.applyKeyCode {
            print("Apply key pressed - confirming selection")
            onSelectionConfirmed?(currentSelection)
            return
        }

        if event.keyCode == keyboardSettings.cancelKeyCode {
            print("Cancel key pressed - cancelling")
            onCancel?()
            return
        }

        if event.keyCode == keyboardSettings.cycleGridKeyCode {
            cycleGridSize()
            return
        }

        // Handle Tab for monitor switching (only when multiple monitors)
        if event.keyCode == 48 { // Tab key
            if totalMonitors > 1 {
                if modifiers.contains(.shift) {
                    print("[Monitor] Shift+Tab pressed - previous monitor")
                    onPreviousMonitor?()
                } else {
                    print("[Monitor] Tab pressed - next monitor")
                    onNextMonitor?()
                }
            }
            return
        }

        // Apply direction based on mode
        if let dir = direction {
            switch mode {
            case .pan:
                // Move entire selection
                currentSelection = GridOperations.pan(selection: currentSelection, direction: dir, gridSize: gridSize)

            case .anchor:
                // Move first corner only
                let newCol = max(0, min(gridSize.cols - 1, currentSelection.anchor.col + dir.colDelta))
                let newRow = max(0, min(gridSize.rows - 1, currentSelection.anchor.row + dir.rowDelta))
                currentSelection = GridSelection(
                    anchor: GridOffset(col: newCol, row: newRow),
                    target: currentSelection.target
                )

            case .target:
                // Move second corner only
                let newCol = max(0, min(gridSize.cols - 1, currentSelection.target.col + dir.colDelta))
                let newRow = max(0, min(gridSize.rows - 1, currentSelection.target.row + dir.rowDelta))
                currentSelection = GridSelection(
                    anchor: currentSelection.anchor,
                    target: GridOffset(col: newCol, row: newRow)
                )
            }
            selection = currentSelection
            return
        }

        // Unhandled key
        print("Unhandled key code: \(event.keyCode)")
        super.keyDown(with: event)
    }

    private func cycleGridSize() {
        if let currentIndex = gridPresets.firstIndex(of: gridSize) {
            let nextIndex = (currentIndex + 1) % gridPresets.count
            gridSize = gridPresets[nextIndex]
        } else {
            gridSize = gridPresets.first ?? GridSize(cols: 8, rows: 2)
        }

        // Reset selection to single cell at top-left
        selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 0, row: 0)
        )

        onGridSizeChanged?(gridSize)
        print("Grid size changed to: \(gridSize.cols)x\(gridSize.rows)")
    }

    override func mouseDown(with event: NSEvent) {
        // Make sure we're first responder when clicked
        window?.makeFirstResponder(self)

        let point = convert(event.locationInWindow, from: nil)
        let cellWidth = bounds.width / CGFloat(gridSize.cols)
        let cellHeight = bounds.height / CGFloat(gridSize.rows)

        let col = Int(point.x / cellWidth)
        let row = gridSize.rows - 1 - Int(point.y / cellHeight)

        let clampedCol = max(0, min(col, gridSize.cols - 1))
        let clampedRow = max(0, min(row, gridSize.rows - 1))

        selectionAnchor = GridOffset(col: clampedCol, row: clampedRow)
        selection = GridSelection(anchor: selectionAnchor!, target: selectionAnchor!)
        isSelecting = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isSelecting, let anchor = selectionAnchor else { return }

        let point = convert(event.locationInWindow, from: nil)
        let cellWidth = bounds.width / CGFloat(gridSize.cols)
        let cellHeight = bounds.height / CGFloat(gridSize.rows)

        let col = Int(point.x / cellWidth)
        let row = gridSize.rows - 1 - Int(point.y / cellHeight)

        let clampedCol = max(0, min(col, gridSize.cols - 1))
        let clampedRow = max(0, min(row, gridSize.rows - 1))

        selection = GridSelection(anchor: anchor, target: GridOffset(col: clampedCol, row: clampedRow))
    }

    override func mouseUp(with event: NSEvent) {
        guard isSelecting, let anchor = selectionAnchor else {
            isSelecting = false
            selectionAnchor = nil
            return
        }

        // Calculate final target position from mouse release location
        let point = convert(event.locationInWindow, from: nil)
        let cellWidth = bounds.width / CGFloat(gridSize.cols)
        let cellHeight = bounds.height / CGFloat(gridSize.rows)

        let col = Int(point.x / cellWidth)
        let row = gridSize.rows - 1 - Int(point.y / cellHeight)

        let clampedCol = max(0, min(col, gridSize.cols - 1))
        let clampedRow = max(0, min(row, gridSize.rows - 1))

        // Finalize the selection with anchor from mouseDown and target from mouseUp
        let finalSelection = GridSelection(
            anchor: anchor,
            target: GridOffset(col: clampedCol, row: clampedRow)
        )
        selection = finalSelection

        // Clean up state before confirming (in case callback triggers UI changes)
        isSelecting = false
        selectionAnchor = nil

        // Confirm immediately on mouse release - this triggers the resize
        onSelectionConfirmed?(finalSelection)
    }
}
