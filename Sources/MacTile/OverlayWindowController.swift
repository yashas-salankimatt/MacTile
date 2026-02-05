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

    // Mouse-based monitor switching
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var lastMousePosition: CGPoint?
    private var mouseMovementOnOtherMonitor: CGFloat = 0
    private let mouseMovementThreshold: CGFloat = 50 // pixels of movement required to switch

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
        stopMouseMonitoring()
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
        gridView?.tilingPresets = settings.tilingPresets
        gridView?.appearanceSettings = settings.appearance
        gridView?.showHelpText = settings.showHelpText
        gridView?.showMonitorIndicator = settings.showMonitorIndicator
        gridView?.confirmOnClickWithoutDrag = settings.confirmOnClickWithoutDrag

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
        gridView.confirmOnClickWithoutDrag = settings.confirmOnClickWithoutDrag
        gridView.tilingPresets = settings.tilingPresets
        gridView.focusPresets = settings.focusPresets
        gridView.onSelectionConfirmed = { [weak self] selection in
            self?.applySelection(selection)
        }
        gridView.onFocusPresetActivated = { [weak self] bundleID in
            self?.activateFocusPreset(bundleID: bundleID)
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
        gridView.onVirtualSpaceRestore = { [weak self] spaceNumber in
            guard let self = self,
                  SettingsManager.shared.settings.virtualSpacesEnabled,
                  let screen = self.currentScreen else { return }
            let displayID = VirtualSpaceManager.displayID(for: screen)
            // Hide overlay FIRST, then restore - this ensures focus is set AFTER
            // the overlay is gone, so macOS doesn't override it
            self.hideOverlay(cancelled: false)
            VirtualSpaceManager.shared.restoreFromSpace(number: spaceNumber, forMonitor: displayID)
        }
        gridView.onVirtualSpaceSave = { [weak self] spaceNumber in
            guard let self = self,
                  SettingsManager.shared.settings.virtualSpacesEnabled,
                  let screen = self.currentScreen else { return }
            let displayID = VirtualSpaceManager.displayID(for: screen)
            // Capture target window before hiding (hideOverlay sets it to nil)
            let windowToFocus = self.targetWindow
            VirtualSpaceManager.shared.saveToSpace(number: spaceNumber, forMonitor: displayID)
            self.hideOverlay(cancelled: false)
            // Restore focus to original window since we're just saving, not tiling
            if let windowToFocus = windowToFocus {
                RealWindowManager.shared.activateWindow(windowToFocus)
            }
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

        // Calculate safe area insets (menu bar, dock, etc.)
        updateGridViewSafeAreaInsets(for: screen)

        // Make the grid view first responder for keyboard input
        if let gridView = gridView {
            let success = window?.makeFirstResponder(gridView) ?? false
            print("Made gridView first responder: \(success)")

            // Update monitor info in grid view
            gridView.currentMonitorIndex = currentMonitorIndex
            gridView.totalMonitors = monitorCount

            // Pass target window ID for per-window preset cycling
            gridView.targetWindowID = targetWindow?.identifier
        }

        // Set initial selection to match window position
        currentSelection = initialSelection
        gridView?.selection = currentSelection
        gridView?.needsDisplay = true

        // Start mouse monitoring for multi-monitor switching
        startMouseMonitoring()
    }

    func hideOverlay(cancelled: Bool = false) {
        // Stop mouse monitoring
        stopMouseMonitoring()
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

        // Calculate safe area insets (menu bar, dock, etc.)
        updateGridViewSafeAreaInsets(for: screen)

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

    /// Calculate and set safe area insets for the grid view
    /// These insets define the unusable area (menu bar, dock) so the grid
    /// only covers the area where windows can actually be placed (visibleFrame)
    private func updateGridViewSafeAreaInsets(for screen: NSScreen) {
        guard let gridView = gridView else { return }

        // The overlay covers screen.frame (full screen)
        // But windows can only be placed in screen.visibleFrame (excludes menu bar, dock)
        // We need insets to offset the grid drawing and mouse handling

        // Top inset: menu bar (and notch on newer MacBooks)
        let topInset = screen.frame.maxY - screen.visibleFrame.maxY

        // Bottom inset: dock if positioned at bottom
        let bottomInset = screen.visibleFrame.minY - screen.frame.minY

        // Left inset: dock if positioned on left
        let leftInset = screen.visibleFrame.minX - screen.frame.minX

        // Right inset: dock if positioned on right
        let rightInset = screen.frame.maxX - screen.visibleFrame.maxX

        print("[SafeArea] Screen frame: \(screen.frame)")
        print("[SafeArea] Screen visibleFrame: \(screen.visibleFrame)")
        print("[SafeArea] Insets - top: \(topInset), bottom: \(bottomInset), left: \(leftInset), right: \(rightInset)")

        gridView.topSafeAreaInset = max(0, topInset)
        gridView.bottomSafeAreaInset = max(0, bottomInset)
        gridView.leftSafeAreaInset = max(0, leftInset)
        gridView.rightSafeAreaInset = max(0, rightInset)
    }

    // MARK: - Mouse-Based Monitor Switching

    private func startMouseMonitoring() {
        guard monitorCount > 1 else { return } // Only monitor if multiple screens

        // Stop any existing monitoring first
        stopMouseMonitoring()

        // Reset tracking state
        lastMousePosition = NSEvent.mouseLocation
        mouseMovementOnOtherMonitor = 0

        // Monitor global mouse movement (when mouse is over other monitors/apps)
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            self?.handleMouseMovement()
        }

        // Monitor local mouse movement (when mouse is over our window)
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            self?.handleMouseMovement()
            return event
        }
    }

    private func stopMouseMonitoring() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseMonitor = nil
        }
        lastMousePosition = nil
        mouseMovementOnOtherMonitor = 0
    }

    private func handleMouseMovement() {
        let currentPosition = NSEvent.mouseLocation
        let mouseMonitorIndex = monitorIndexForPoint(currentPosition)

        // Calculate movement distance from last position
        if let lastPosition = lastMousePosition {
            let dx = currentPosition.x - lastPosition.x
            let dy = currentPosition.y - lastPosition.y
            let distance = sqrt(dx * dx + dy * dy)

            if mouseMonitorIndex != currentMonitorIndex {
                // Mouse is on a different monitor - accumulate movement
                mouseMovementOnOtherMonitor += distance

                if mouseMovementOnOtherMonitor >= mouseMovementThreshold {
                    // Threshold exceeded - switch to that monitor
                    print("[Monitor] Mouse movement threshold exceeded on monitor \(mouseMonitorIndex + 1), switching...")
                    moveToMonitor(index: mouseMonitorIndex)
                    mouseMovementOnOtherMonitor = 0
                }
            } else {
                // Mouse is on the same monitor as overlay - reset accumulated movement
                mouseMovementOnOtherMonitor = 0
            }
        }

        lastMousePosition = currentPosition
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

    /// Activate a focus preset - hide overlay and focus the target app
    func activateFocusPreset(bundleID: String, openIfNotRunning: Bool = false) {
        // Check if the window that was focused BEFORE the overlay belongs to the target app
        // If so, we should force cycling since user was already viewing that app
        var shouldForceCycle = false
        if let targetWindow = targetWindow {
            // Get bundle ID from the process identifier
            if let targetApp = NSRunningApplication(processIdentifier: targetWindow.processIdentifier),
               targetApp.bundleIdentifier == bundleID {
                shouldForceCycle = true
                print("[FocusPreset] Pre-overlay window was from target app, will force cycle")
            }
        }

        // Hide the overlay first (don't return focus to original window)
        hideOverlay(cancelled: false)

        // Focus the target app (with force cycle if we were already on that app)
        FocusManager.shared.focusNextWindow(forBundleID: bundleID, forceCycle: shouldForceCycle, openIfNotRunning: openIfNotRunning)
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
    var onFocusPresetActivated: ((String) -> Void)?  // Called with bundle ID when focus preset is used
    var onVirtualSpaceRestore: ((Int) -> Void)?
    var onVirtualSpaceSave: ((Int) -> Void)?

    private var isSelecting = false
    private var selectionAnchor: GridOffset?
    private var didDrag = false
    private var selectionBeforeMouseDown: GridSelection?

    // Click behavior setting
    var confirmOnClickWithoutDrag: Bool = true

    // Multi-monitor info (for display)
    var currentMonitorIndex: Int = 0 {
        didSet { needsDisplay = true }
    }
    var totalMonitors: Int = 1 {
        didSet { needsDisplay = true }
    }

    // Safe area insets (for menu bar, dock, etc.)
    // These define the area where windows can actually be placed
    var topSafeAreaInset: CGFloat = 0 {
        didSet { needsDisplay = true }
    }
    var bottomSafeAreaInset: CGFloat = 0 {
        didSet { needsDisplay = true }
    }
    var leftSafeAreaInset: CGFloat = 0 {
        didSet { needsDisplay = true }
    }
    var rightSafeAreaInset: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    // The usable area for the grid (bounds minus safe area insets)
    private var gridBounds: CGRect {
        return CGRect(
            x: leftSafeAreaInset,
            y: bottomSafeAreaInset,
            width: bounds.width - leftSafeAreaInset - rightSafeAreaInset,
            height: bounds.height - topSafeAreaInset - bottomSafeAreaInset
        )
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
    var tilingPresets: [TilingPreset] = []
    var focusPresets: [FocusPreset] = []

    // Target window identifier (set by OverlayWindowController)
    var targetWindowID: UInt32?

    // Preset cycling state - now tracks per-window
    private var lastActivatedPresetIndex: Int?
    private var lastActivatedWindowID: UInt32?
    private var lastPresetActivationTime: Date?
    private var currentCycleIndex: Int = 0

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

        // Use gridBounds instead of bounds so the grid aligns with the visible frame
        // where windows can actually be placed (excluding menu bar, dock)
        let grid = gridBounds
        let cellWidth = grid.width / CGFloat(gridSize.cols)
        let cellHeight = grid.height / CGFloat(gridSize.rows)

        // Draw grid cells with alternating colors for visibility
        for row in 0..<gridSize.rows {
            for col in 0..<gridSize.cols {
                let x = grid.minX + CGFloat(col) * cellWidth
                let y = grid.minY + grid.height - CGFloat(row + 1) * cellHeight

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
            let x = grid.minX + CGFloat(col) * cellWidth
            context.move(to: CGPoint(x: x, y: grid.minY))
            context.addLine(to: CGPoint(x: x, y: grid.maxY))
        }

        // Horizontal lines
        for row in 0...gridSize.rows {
            let y = grid.minY + CGFloat(row) * cellHeight
            context.move(to: CGPoint(x: grid.minX, y: y))
            context.addLine(to: CGPoint(x: grid.maxX, y: y))
        }

        context.strokePath()

        // Draw selection highlight
        if let selection = selection {
            let normalized = selection.normalized
            let x = grid.minX + CGFloat(normalized.anchor.col) * cellWidth
            let y = grid.minY + grid.height - CGFloat(normalized.target.row + 1) * cellHeight
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
            let anchorX = grid.minX + CGFloat(selection.anchor.col) * cellWidth + cellWidth / 2 - 6
            let anchorY = grid.minY + grid.height - CGFloat(selection.anchor.row + 1) * cellHeight + cellHeight / 2 - 6
            context.setFillColor(nsColor(appearanceSettings.anchorMarkerColor).cgColor)
            context.fillEllipse(in: CGRect(x: anchorX, y: anchorY, width: 12, height: 12))

            // Draw target marker (second corner - hollow circle)
            let targetX = grid.minX + CGFloat(selection.target.col) * cellWidth + cellWidth / 2 - 6
            let targetY = grid.minY + grid.height - CGFloat(selection.target.row + 1) * cellHeight + cellHeight / 2 - 6
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

        // Convert event modifiers to our modifier flags
        let modifiers = event.modifierFlags
        var eventModifiers: UInt = KeyboardShortcut.Modifiers.none
        if modifiers.contains(.control) {
            eventModifiers |= KeyboardShortcut.Modifiers.control
        }
        if modifiers.contains(.option) {
            eventModifiers |= KeyboardShortcut.Modifiers.option
        }
        if modifiers.contains(.shift) {
            eventModifiers |= KeyboardShortcut.Modifiers.shift
        }
        if modifiers.contains(.command) {
            eventModifiers |= KeyboardShortcut.Modifiers.command
        }

        // Virtual space overlay triggers: number = restore, Shift+number = save
        if let spaceNumber = keyCodeToSpaceNumber(event.keyCode) {
            if eventModifiers == KeyboardShortcut.Modifiers.none {
                onVirtualSpaceRestore?(spaceNumber)
                return
            }
            if eventModifiers == KeyboardShortcut.Modifiers.shift {
                onVirtualSpaceSave?(spaceNumber)
                return
            }
        }

        // Check for tiling presets (now supports modifiers)
        for (presetIndex, preset) in tilingPresets.enumerated() {
            if preset.matches(keyCode: event.keyCode, modifiers: eventModifiers) {
                let now = Date()

                // Determine cycle position - only cycle if same preset AND same window
                var cycleIndex = 0
                if let lastIndex = lastActivatedPresetIndex,
                   let lastWindowID = lastActivatedWindowID,
                   let lastTime = lastPresetActivationTime,
                   lastIndex == presetIndex,
                   lastWindowID == targetWindowID {
                    // Same preset AND same window - check if within timeout
                    let elapsed = now.timeIntervalSince(lastTime) * 1000 // Convert to ms
                    if elapsed < Double(preset.cycleTimeout) {
                        // Advance to next cycle position
                        cycleIndex = (currentCycleIndex + 1) % preset.cycleCount
                    }
                }

                // Update tracking state (including window ID)
                lastActivatedPresetIndex = presetIndex
                lastActivatedWindowID = targetWindowID
                lastPresetActivationTime = now
                currentCycleIndex = cycleIndex

                let windowName = targetWindowID.map { "window \($0)" } ?? "unknown window"
                print("Preset matched: \(preset.shortcutDisplayString) -> position \(cycleIndex + 1)/\(preset.cycleCount) for \(windowName): \(preset.positions[cycleIndex].coordinateString)")
                let presetSelection = preset.toGridSelection(gridSize: gridSize, positionIndex: cycleIndex)
                selection = presetSelection

                if preset.autoConfirm {
                    print("Auto-confirming preset")
                    onSelectionConfirmed?(presetSelection)
                }
                return
            }
        }

        // Check for focus presets (that work with overlay)
        for preset in focusPresets {
            if preset.worksWithOverlay && preset.matches(keyCode: event.keyCode, modifiers: eventModifiers) {
                print("Focus preset matched: \(preset.shortcutDisplayString) -> \(preset.appName)")
                onFocusPresetActivated?(preset.appBundleID)
                return
            }
        }

        // Determine mode based on modifier (reuse eventModifiers computed above)
        enum SelectionMode {
            case pan       // Move entire selection
            case anchor    // Move first corner
            case target    // Move second corner
        }

        let mode: SelectionMode
        if eventModifiers == keyboardSettings.panModifier {
            mode = .pan
        } else if eventModifiers == keyboardSettings.anchorModifier {
            mode = .anchor
        } else if eventModifiers == keyboardSettings.targetModifier {
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

    private func keyCodeToSpaceNumber(_ keyCode: UInt16) -> Int? {
        switch keyCode {
        case 29: return 0
        case 18: return 1
        case 19: return 2
        case 20: return 3
        case 21: return 4
        case 23: return 5
        case 22: return 6
        case 26: return 7
        case 28: return 8
        case 25: return 9
        default: return nil
        }
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

        // Use gridBounds to translate mouse coordinates to grid cells
        let grid = gridBounds
        let cellWidth = grid.width / CGFloat(gridSize.cols)
        let cellHeight = grid.height / CGFloat(gridSize.rows)

        // Translate point relative to gridBounds
        let gridRelativeX = point.x - grid.minX
        let gridRelativeY = point.y - grid.minY

        let col = Int(gridRelativeX / cellWidth)
        let row = gridSize.rows - 1 - Int(gridRelativeY / cellHeight)

        let clampedCol = max(0, min(col, gridSize.cols - 1))
        let clampedRow = max(0, min(row, gridSize.rows - 1))

        // Store current selection in case we need to restore it (for click-to-confirm)
        selectionBeforeMouseDown = selection

        // Store the clicked cell as potential anchor for drag
        selectionAnchor = GridOffset(col: clampedCol, row: clampedRow)
        didDrag = false
        isSelecting = true

        // Don't change selection yet - wait to see if this is a click or drag
    }

    override func mouseDragged(with event: NSEvent) {
        guard isSelecting, let anchor = selectionAnchor else { return }

        let point = convert(event.locationInWindow, from: nil)

        // Use gridBounds to translate mouse coordinates to grid cells
        let grid = gridBounds
        let cellWidth = grid.width / CGFloat(gridSize.cols)
        let cellHeight = grid.height / CGFloat(gridSize.rows)

        // Translate point relative to gridBounds
        let gridRelativeX = point.x - grid.minX
        let gridRelativeY = point.y - grid.minY

        let col = Int(gridRelativeX / cellWidth)
        let row = gridSize.rows - 1 - Int(gridRelativeY / cellHeight)

        let clampedCol = max(0, min(col, gridSize.cols - 1))
        let clampedRow = max(0, min(row, gridSize.rows - 1))

        // Mark that dragging occurred
        didDrag = true

        // Update selection to show drag range
        selection = GridSelection(anchor: anchor, target: GridOffset(col: clampedCol, row: clampedRow))
    }

    override func mouseUp(with event: NSEvent) {
        guard isSelecting else {
            isSelecting = false
            selectionAnchor = nil
            didDrag = false
            selectionBeforeMouseDown = nil
            return
        }

        let finalSelection: GridSelection

        if didDrag {
            // User dragged - use the drag selection
            guard let anchor = selectionAnchor else {
                isSelecting = false
                selectionAnchor = nil
                didDrag = false
                selectionBeforeMouseDown = nil
                return
            }

            // Calculate final target position from mouse release location
            let point = convert(event.locationInWindow, from: nil)

            // Use gridBounds to translate mouse coordinates to grid cells
            let grid = gridBounds
            let cellWidth = grid.width / CGFloat(gridSize.cols)
            let cellHeight = grid.height / CGFloat(gridSize.rows)

            // Translate point relative to gridBounds
            let gridRelativeX = point.x - grid.minX
            let gridRelativeY = point.y - grid.minY

            let col = Int(gridRelativeX / cellWidth)
            let row = gridSize.rows - 1 - Int(gridRelativeY / cellHeight)

            let clampedCol = max(0, min(col, gridSize.cols - 1))
            let clampedRow = max(0, min(row, gridSize.rows - 1))

            finalSelection = GridSelection(
                anchor: anchor,
                target: GridOffset(col: clampedCol, row: clampedRow)
            )
            selection = finalSelection
        } else {
            // User clicked without dragging
            let clickedCell = selectionAnchor!

            // Check if click is inside the existing selection (blue area)
            let clickInsideSelection: Bool
            if let existingSelection = selectionBeforeMouseDown {
                let normalized = existingSelection.normalized
                let minCol = normalized.anchor.col
                let maxCol = normalized.target.col
                let minRow = normalized.anchor.row
                let maxRow = normalized.target.row
                clickInsideSelection = clickedCell.col >= minCol && clickedCell.col <= maxCol &&
                                       clickedCell.row >= minRow && clickedCell.row <= maxRow
            } else {
                clickInsideSelection = false
            }

            if clickInsideSelection && confirmOnClickWithoutDrag {
                // Click inside selection with confirm-on-click enabled: confirm existing selection
                finalSelection = selectionBeforeMouseDown!
                selection = finalSelection
            } else {
                // Click outside selection OR confirm-on-click disabled: select single cell
                finalSelection = GridSelection(
                    anchor: clickedCell,
                    target: clickedCell
                )
                selection = finalSelection
            }
        }

        // Clean up state before confirming (in case callback triggers UI changes)
        isSelecting = false
        selectionAnchor = nil
        didDrag = false
        selectionBeforeMouseDown = nil

        // Confirm the selection - this triggers the resize
        onSelectionConfirmed?(finalSelection)
    }
}
