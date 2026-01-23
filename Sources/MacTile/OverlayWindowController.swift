import AppKit
import MacTileCore

/// A panel that can become key even when the app is not active
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Controls the overlay window that displays the grid
class OverlayWindowController: NSWindowController {
    private var gridSize = GridSize(cols: 8, rows: 2)
    private var currentSelection: GridSelection?
    private var gridView: GridOverlayView?
    private let windowTiler: WindowTiler

    // Store reference to the window we want to tile (before overlay appears)
    private var targetWindow: WindowInfo?

    init() {
        // Initialize window tiler with real window manager
        self.windowTiler = WindowTiler(windowManager: RealWindowManager.shared)
        windowTiler.spacing = 10
        windowTiler.insets = EdgeInsets.zero

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
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.4)
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hasShadow = false
        panel.becomesKeyOnlyIfNeeded = false  // Important: always become key
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true

        super.init(window: panel)

        setupGridView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupGridView() {
        guard let window = window, let contentView = window.contentView else { return }

        let gridView = GridOverlayView(gridSize: gridSize)
        gridView.frame = contentView.bounds
        gridView.autoresizingMask = [.width, .height]
        gridView.onSelectionConfirmed = { [weak self] selection in
            self?.applySelection(selection)
        }
        gridView.onCancel = { [weak self] in
            self?.hideOverlay(cancelled: true)
        }
        gridView.onGridSizeChanged = { [weak self] newSize in
            self?.gridSize = newSize
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
        guard let screen = NSScreen.main else { return }

        // IMPORTANT: Capture window BEFORE any UI changes
        targetWindow = RealWindowManager.shared.getFocusedWindow()
        print("Captured target window: \(targetWindow?.title ?? "none")")

        // Calculate initial selection based on current window position
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

        // Make the grid view first responder for keyboard input
        if let gridView = gridView {
            let success = window?.makeFirstResponder(gridView) ?? false
            print("Made gridView first responder: \(success)")
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

    private func applySelection(_ selection: GridSelection) {
        // Get reference to target window before hiding
        let windowToTile = targetWindow

        hideOverlay()

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
            guard let screen = RealWindowManager.shared.getMainScreen() else {
                print("No main screen found")
                return
            }

            let targetFrame = GridOperations.selectionToRect(
                selection: selection,
                gridSize: gridSize,
                screenFrame: screen.visibleFrame,
                spacing: windowTiler.spacing,
                insets: windowTiler.insets
            )

            let success = RealWindowManager.shared.setWindowFrame(targetWindow, frame: targetFrame)
            if success {
                print("Successfully tiled window: \(targetWindow.title)")
            } else {
                print("Failed to tile window: \(targetWindow.title)")
            }

            // Return focus to the tiled window
            RealWindowManager.shared.activateWindow(targetWindow)
        } else {
            print("No target window captured - trying to get current focused window")
            let success = windowTiler.tileFocusedWindow(to: selection, gridSize: gridSize)
            if !success {
                print("Failed to tile window - check accessibility permissions")
            }
        }
    }
}

/// View that displays the grid and handles keyboard input
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

    private var isSelecting = false
    private var selectionAnchor: GridOffset?

    private let gridPresets = [
        GridSize(cols: 8, rows: 2),
        GridSize(cols: 6, rows: 4),
        GridSize(cols: 4, rows: 4),
        GridSize(cols: 3, rows: 3),
        GridSize(cols: 2, rows: 2)
    ]

    init(gridSize: GridSize) {
        self.gridSize = gridSize
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
                        ? NSColor.white.withAlphaComponent(0.05).cgColor
                        : NSColor.white.withAlphaComponent(0.1).cgColor
                )
                context.fill(CGRect(x: x, y: y, width: cellWidth, height: cellHeight))
            }
        }

        // Draw grid lines
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(1.0)

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
            context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.4).cgColor)
            context.fill(CGRect(x: x, y: y, width: width, height: height))

            // Selection border
            context.setStrokeColor(NSColor.systemBlue.cgColor)
            context.setLineWidth(3.0)
            context.stroke(CGRect(x: x, y: y, width: width, height: height))
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

        // Draw instructions at top
        let instructions = "Arrow/HJKL: Move | Shift: Extend | Option: Shrink | Enter: Apply | Esc: Cancel | Space: Cycle"
        let instrAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let instrSize = instructions.size(withAttributes: instrAttrs)
        let instrX = (bounds.width - instrSize.width) / 2
        instructions.draw(at: CGPoint(x: instrX, y: bounds.height - 40), withAttributes: instrAttrs)

        // Draw selection info
        if let selection = selection {
            let selInfo = "Selection: cols \(selection.normalized.anchor.col)-\(selection.normalized.target.col), rows \(selection.normalized.anchor.row)-\(selection.normalized.target.row)"
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

        let shift = event.modifierFlags.contains(.shift)
        let option = event.modifierFlags.contains(.option)

        // Determine mode: Option = shrink, Shift = extend, neither = pan
        let mode: AdjustMode? = option ? .shrink : (shift ? .extend : nil)

        // Handle by character for HJKL (more reliable than key codes)
        if let chars = event.charactersIgnoringModifiers?.lowercased() {
            switch chars {
            case "h":
                if let mode = mode {
                    // For shrink, reverse direction: Option+H shrinks RIGHT edge
                    let dir: Direction = (mode == .shrink) ? .right : .left
                    currentSelection = GridOperations.adjust(selection: currentSelection, direction: dir, mode: mode, gridSize: gridSize)
                } else {
                    currentSelection = GridOperations.pan(selection: currentSelection, direction: .left, gridSize: gridSize)
                }
                selection = currentSelection
                return
            case "l":
                if let mode = mode {
                    // For shrink, reverse direction: Option+L shrinks LEFT edge
                    let dir: Direction = (mode == .shrink) ? .left : .right
                    currentSelection = GridOperations.adjust(selection: currentSelection, direction: dir, mode: mode, gridSize: gridSize)
                } else {
                    currentSelection = GridOperations.pan(selection: currentSelection, direction: .right, gridSize: gridSize)
                }
                selection = currentSelection
                return
            case "j":
                if let mode = mode {
                    // For shrink, reverse direction: Option+J shrinks TOP edge
                    let dir: Direction = (mode == .shrink) ? .up : .down
                    currentSelection = GridOperations.adjust(selection: currentSelection, direction: dir, mode: mode, gridSize: gridSize)
                } else {
                    currentSelection = GridOperations.pan(selection: currentSelection, direction: .down, gridSize: gridSize)
                }
                selection = currentSelection
                return
            case "k":
                if let mode = mode {
                    // For shrink, reverse direction: Option+K shrinks BOTTOM edge
                    let dir: Direction = (mode == .shrink) ? .down : .up
                    currentSelection = GridOperations.adjust(selection: currentSelection, direction: dir, mode: mode, gridSize: gridSize)
                } else {
                    currentSelection = GridOperations.pan(selection: currentSelection, direction: .up, gridSize: gridSize)
                }
                selection = currentSelection
                return
            case " ":
                cycleGridSize()
                return
            default:
                break
            }
        }

        // Handle by key code for special keys (arrows)
        switch event.keyCode {
        case 123: // Left arrow
            if let mode = mode {
                let dir: Direction = (mode == .shrink) ? .right : .left
                currentSelection = GridOperations.adjust(selection: currentSelection, direction: dir, mode: mode, gridSize: gridSize)
            } else {
                currentSelection = GridOperations.pan(selection: currentSelection, direction: .left, gridSize: gridSize)
            }

        case 124: // Right arrow
            if let mode = mode {
                let dir: Direction = (mode == .shrink) ? .left : .right
                currentSelection = GridOperations.adjust(selection: currentSelection, direction: dir, mode: mode, gridSize: gridSize)
            } else {
                currentSelection = GridOperations.pan(selection: currentSelection, direction: .right, gridSize: gridSize)
            }

        case 125: // Down arrow
            if let mode = mode {
                let dir: Direction = (mode == .shrink) ? .up : .down
                currentSelection = GridOperations.adjust(selection: currentSelection, direction: dir, mode: mode, gridSize: gridSize)
            } else {
                currentSelection = GridOperations.pan(selection: currentSelection, direction: .down, gridSize: gridSize)
            }

        case 126: // Up arrow
            if let mode = mode {
                let dir: Direction = (mode == .shrink) ? .down : .up
                currentSelection = GridOperations.adjust(selection: currentSelection, direction: dir, mode: mode, gridSize: gridSize)
            } else {
                currentSelection = GridOperations.pan(selection: currentSelection, direction: .up, gridSize: gridSize)
            }

        case 36: // Enter
            print("Enter pressed - confirming selection")
            onSelectionConfirmed?(currentSelection)
            return

        case 53: // Escape
            print("Escape pressed - cancelling")
            onCancel?()
            return

        case 49: // Space
            cycleGridSize()
            return

        default:
            print("Unhandled key code: \(event.keyCode)")
            super.keyDown(with: event)
            return
        }

        selection = currentSelection
    }

    private func cycleGridSize() {
        if let currentIndex = gridPresets.firstIndex(of: gridSize) {
            let nextIndex = (currentIndex + 1) % gridPresets.count
            gridSize = gridPresets[nextIndex]
        } else {
            gridSize = gridPresets[0]
        }

        // Reset selection to single cell
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
        if isSelecting, let selection = selection {
            // Double-click confirms selection
            if event.clickCount >= 2 {
                onSelectionConfirmed?(selection)
            }
        }
        isSelecting = false
        selectionAnchor = nil
    }
}
