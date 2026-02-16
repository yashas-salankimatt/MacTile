import AppKit
import MacTileCore

// MARK: - Overlay Item Model

/// Represents a navigable item in the workspace management overlay
enum VSManageItem {
    case workspaceHeader(space: VirtualSpace)
    case windowEntry(spaceNumber: Int, window: VirtualSpaceWindow, appName: String)

    var spaceNumber: Int {
        switch self {
        case .workspaceHeader(let space): return space.number
        case .windowEntry(let num, _, _): return num
        }
    }
}

// MARK: - Virtual Space Manage Controller

/// Controls the floating panel for managing virtual workspace contents
class VirtualSpaceManageController: NSWindowController {
    private var manageView: VirtualSpaceManageView?
    private var targetWindow: WindowInfo?
    private var isDismissed = false
    private let panelWidth: CGFloat = 520

    /// Called after the overlay is dismissed so the parent can clean up its reference
    var onDismissComplete: (() -> Void)?

    init(displayID: UInt32, targetWindow: WindowInfo?, screen: NSScreen) {
        self.targetWindow = targetWindow

        let tempHeight: CGFloat = 200

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: tempHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false

        super.init(window: panel)

        setupContent(displayID: displayID, screen: screen)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContent(displayID: UInt32, screen: NSScreen) {
        guard let panel = window, let contentView = panel.contentView else { return }

        // Visual effect view for native macOS blur background
        let effectView = NSVisualEffectView(frame: contentView.bounds)
        effectView.autoresizingMask = [.width, .height]
        effectView.material = .hudWindow
        effectView.state = .active
        effectView.blendingMode = .behindWindow
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 12
        effectView.layer?.masksToBounds = true
        contentView.addSubview(effectView)

        // Content view for rendering items
        let view = VirtualSpaceManageView(frame: contentView.bounds, displayID: displayID)
        view.autoresizingMask = [.width, .height]
        view.onDismiss = { [weak self] in
            self?.dismiss()
        }
        effectView.addSubview(view)
        self.manageView = view

        // Size panel to fit content
        let contentHeight = view.calculateContentHeight()
        let maxHeight = min(screen.visibleFrame.height * 0.75, 700)
        let minHeight: CGFloat = 140
        let panelHeight = max(minHeight, min(contentHeight, maxHeight))
        let x = screen.frame.midX - panelWidth / 2
        let y = screen.frame.midY - panelHeight / 2

        panel.setFrame(
            NSRect(x: x, y: y, width: panelWidth, height: panelHeight),
            display: true
        )
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if let view = manageView {
            let success = window?.makeFirstResponder(view) ?? false
            print("[VSManage] Made view first responder: \(success)")
        }
    }

    func dismiss() {
        guard !isDismissed else { return }
        isDismissed = true

        window?.orderOut(nil)

        if let tw = targetWindow {
            RealWindowManager.shared.activateWindow(tw)
        }
        targetWindow = nil
        onDismissComplete?()
    }
}

// MARK: - Virtual Space Manage View

/// Renders the virtual workspace list and handles keyboard navigation
class VirtualSpaceManageView: NSView {

    // MARK: - Layout Constants

    private let padding: CGFloat = 20
    private let titleFontSize: CGFloat = 16
    private let subtitleFontSize: CGFloat = 11
    private let headerRowHeight: CGFloat = 36
    private let windowRowHeight: CGFloat = 28
    private let groupGap: CGFloat = 10
    private let windowIndent: CGFloat = 28
    private let selectionRadius: CGFloat = 6

    // Fixed area heights
    private let titleBlockHeight: CGFloat = 48
    private let separatorBlockHeight: CGFloat = 17
    private let footerBlockHeight: CGFloat = 28

    // MARK: - State

    private var items: [VSManageItem] = []
    private var selectedIndex: Int = 0
    private var scrollOffset: CGFloat = 0
    private var displayID: UInt32
    private var itemLayouts: [(relativeY: CGFloat, height: CGFloat)] = []
    private var totalItemsHeight: CGFloat = 0
    private var workspaceHeaderCount: Int = 0

    // App name cache to avoid repeated NSWorkspace lookups
    private static var appNameCache: [String: String] = [:]

    // MARK: - Callbacks

    var onDismiss: (() -> Void)?

    // MARK: - Init

    init(frame: NSRect, displayID: UInt32) {
        self.displayID = displayID
        super.init(frame: frame)
        wantsLayer = true
        rebuildItems()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { true }

    // MARK: - Data

    private func rebuildItems() {
        items = []
        itemLayouts = []
        totalItemsHeight = 0
        workspaceHeaderCount = 0

        let storage = SettingsManager.shared.settings.virtualSpaces
        let spaces = storage.getNonEmptySpaces(displayID: displayID)
            .sorted { $0.number < $1.number }

        for space in spaces {
            if !items.isEmpty {
                totalItemsHeight += groupGap
            }

            items.append(.workspaceHeader(space: space))
            itemLayouts.append((relativeY: totalItemsHeight, height: headerRowHeight))
            totalItemsHeight += headerRowHeight
            workspaceHeaderCount += 1

            for window in space.windowsByZOrder {
                let appName = Self.resolveAppName(bundleID: window.appBundleID)
                items.append(.windowEntry(
                    spaceNumber: space.number,
                    window: window,
                    appName: appName
                ))
                itemLayouts.append((relativeY: totalItemsHeight, height: windowRowHeight))
                totalItemsHeight += windowRowHeight
            }
        }

        if items.isEmpty {
            selectedIndex = 0
        } else {
            selectedIndex = max(0, min(selectedIndex, items.count - 1))
        }
    }

    static func resolveAppName(bundleID: String) -> String {
        if let cached = appNameCache[bundleID] {
            return cached
        }
        let name: String
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            name = FileManager.default.displayName(atPath: appURL.path)
                .replacingOccurrences(of: ".app", with: "")
        } else {
            name = bundleID.split(separator: ".").last.map(String.init) ?? bundleID
        }
        appNameCache[bundleID] = name
        return name
    }

    // MARK: - Height Calculation

    func calculateContentHeight() -> CGFloat {
        var h: CGFloat = padding
        h += titleBlockHeight
        h += separatorBlockHeight

        if items.isEmpty {
            h += 50
        } else {
            h += totalItemsHeight
        }

        h += separatorBlockHeight
        h += footerBlockHeight
        h += padding
        return h
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let w = bounds.width

        // -- Title --
        var y = bounds.height - padding

        let titleFont = NSFont.systemFont(ofSize: titleFontSize, weight: .bold)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.white
        ]
        y -= titleFontSize + 2
        "Virtual Workspaces".draw(at: CGPoint(x: padding, y: y), withAttributes: titleAttrs)

        // -- Subtitle (computed from local state, not re-querying storage) --
        let subtitleText = "\(workspaceHeaderCount) workspace\(workspaceHeaderCount == 1 ? "" : "s")"
        let subFont = NSFont.systemFont(ofSize: subtitleFontSize, weight: .regular)
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: subFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.4)
        ]
        y -= subtitleFontSize + 8
        subtitleText.draw(at: CGPoint(x: padding, y: y), withAttributes: subAttrs)
        y -= 6

        // -- Top Separator --
        y -= 6
        drawSeparator(ctx: ctx, y: y, width: w)
        y -= 6

        // -- Items Area --
        let itemsAreaTop = y
        let footerAreaHeight = padding + footerBlockHeight + separatorBlockHeight
        let itemsAreaBottom = footerAreaHeight
        let itemsAreaHeight = itemsAreaTop - itemsAreaBottom

        if items.isEmpty {
            let emptyAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor.white.withAlphaComponent(0.35)
            ]
            let emptyText = "No virtual workspaces saved"
            let emptySize = emptyText.size(withAttributes: emptyAttrs)
            emptyText.draw(
                at: CGPoint(x: (w - emptySize.width) / 2, y: itemsAreaTop - 30),
                withAttributes: emptyAttrs
            )
        } else {
            ensureSelectedVisible(itemsAreaHeight: itemsAreaHeight)

            ctx.saveGState()
            ctx.clip(to: CGRect(x: 0, y: itemsAreaBottom, width: w, height: itemsAreaHeight))

            for (index, item) in items.enumerated() {
                let layout = itemLayouts[index]
                let itemY = itemsAreaTop - layout.relativeY - layout.height + scrollOffset
                let itemH = layout.height

                if itemY + itemH < itemsAreaBottom || itemY > itemsAreaTop {
                    continue
                }

                drawItem(item, at: itemY, height: itemH, isSelected: index == selectedIndex, ctx: ctx, width: w)
            }

            ctx.restoreGState()
        }

        // -- Bottom Separator --
        let bottomSepY = footerAreaHeight - 2
        drawSeparator(ctx: ctx, y: bottomSepY, width: w)

        // -- Footer --
        let helpFont = NSFont.systemFont(ofSize: 11, weight: .medium)
        let helpAttrs: [NSAttributedString.Key: Any] = [
            .font: helpFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.35)
        ]
        let helpText = items.isEmpty
            ? "Esc  Close"
            : "\u{2191}\u{2193}/JK  Navigate    X/D  Remove    Esc  Close"
        let helpSize = helpText.size(withAttributes: helpAttrs)
        helpText.draw(
            at: CGPoint(
                x: (w - helpSize.width) / 2,
                y: padding + (footerBlockHeight - helpSize.height) / 2
            ),
            withAttributes: helpAttrs
        )
    }

    private func drawSeparator(ctx: CGContext, y: CGFloat, width: CGFloat) {
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.08).cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: padding, y: y))
        ctx.addLine(to: CGPoint(x: width - padding, y: y))
        ctx.strokePath()
    }

    private func drawItem(_ item: VSManageItem, at y: CGFloat, height: CGFloat, isSelected: Bool, ctx: CGContext, width: CGFloat) {
        let leftPad = padding
        let rightPad = padding

        switch item {
        case .workspaceHeader(let space):
            drawWorkspaceHeader(space: space, at: y, height: height, isSelected: isSelected, ctx: ctx, width: width, leftPad: leftPad, rightPad: rightPad)

        case .windowEntry(_, let window, let appName):
            drawWindowEntry(window: window, appName: appName, at: y, height: height, isSelected: isSelected, ctx: ctx, width: width, leftPad: leftPad, rightPad: rightPad)
        }
    }

    private func drawWorkspaceHeader(space: VirtualSpace, at y: CGFloat, height: CGFloat, isSelected: Bool, ctx: CGContext, width: CGFloat, leftPad: CGFloat, rightPad: CGFloat) {
        // Selection highlight
        if isSelected {
            let rect = NSRect(x: leftPad - 6, y: y, width: width - leftPad - rightPad + 12, height: height)
            let path = NSBezierPath(roundedRect: rect, xRadius: selectionRadius, yRadius: selectionRadius)
            NSColor.systemBlue.withAlphaComponent(0.2).setFill()
            path.fill()
            NSColor.systemBlue.withAlphaComponent(0.5).setStroke()
            path.lineWidth = 1
            path.stroke()
        }

        // Number badge
        let badgeSize: CGFloat = 22
        let badgeX = leftPad + 2
        let badgeY = y + (height - badgeSize) / 2
        let badgeRect = NSRect(x: badgeX, y: badgeY, width: badgeSize, height: badgeSize)
        let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: 5, yRadius: 5)
        NSColor.systemBlue.withAlphaComponent(0.7).setFill()
        badgePath.fill()

        let numFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .bold)
        let numAttrs: [NSAttributedString.Key: Any] = [
            .font: numFont,
            .foregroundColor: NSColor.white
        ]
        let numStr = "\(space.number)"
        let numSize = numStr.size(withAttributes: numAttrs)
        numStr.draw(
            at: CGPoint(
                x: badgeX + (badgeSize - numSize.width) / 2,
                y: badgeY + (badgeSize - numSize.height) / 2
            ),
            withAttributes: numAttrs
        )

        // Space name
        let nameFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: nameFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.95)
        ]
        let nameText = space.name ?? "Space \(space.number)"
        let nameX = badgeX + badgeSize + 10
        let nameSize = nameText.size(withAttributes: nameAttrs)
        nameText.draw(
            at: CGPoint(x: nameX, y: y + (height - nameSize.height) / 2),
            withAttributes: nameAttrs
        )

        // Unique app count (not window count)
        let uniqueApps = Set(space.windows.map { $0.appBundleID }).count
        let countFont = NSFont.systemFont(ofSize: 11, weight: .regular)
        let countAttrs: [NSAttributedString.Key: Any] = [
            .font: countFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.3)
        ]
        let countText = "\(uniqueApps) app\(uniqueApps == 1 ? "" : "s")"
        let countSize = countText.size(withAttributes: countAttrs)
        countText.draw(
            at: CGPoint(
                x: width - rightPad - countSize.width,
                y: y + (height - countSize.height) / 2
            ),
            withAttributes: countAttrs
        )
    }

    private func drawWindowEntry(window: VirtualSpaceWindow, appName: String, at y: CGFloat, height: CGFloat, isSelected: Bool, ctx: CGContext, width: CGFloat, leftPad: CGFloat, rightPad: CGFloat) {
        // Selection highlight
        if isSelected {
            let rect = NSRect(x: leftPad - 6, y: y, width: width - leftPad - rightPad + 12, height: height)
            let path = NSBezierPath(roundedRect: rect, xRadius: selectionRadius, yRadius: selectionRadius)
            NSColor.systemBlue.withAlphaComponent(0.2).setFill()
            path.fill()
            NSColor.systemBlue.withAlphaComponent(0.5).setStroke()
            path.lineWidth = 1
            path.stroke()
        }

        // Dot indicator
        let dotSize: CGFloat = 4
        let dotX = leftPad + windowIndent / 2 - dotSize / 2 + 2
        let dotY = y + (height - dotSize) / 2
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.25).cgColor)
        ctx.fillEllipse(in: CGRect(x: dotX, y: dotY, width: dotSize, height: dotSize))

        // App name
        let appFont = NSFont.systemFont(ofSize: 12, weight: .medium)
        let appAttrs: [NSAttributedString.Key: Any] = [
            .font: appFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.8)
        ]
        let appX = leftPad + windowIndent
        let appSize = appName.size(withAttributes: appAttrs)
        appName.draw(
            at: CGPoint(x: appX, y: y + (height - appSize.height) / 2),
            withAttributes: appAttrs
        )

        // Window title
        if !window.windowTitle.isEmpty {
            let titleFont = NSFont.systemFont(ofSize: 12, weight: .regular)
            let dimColor = NSColor.white.withAlphaComponent(0.35)
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: dimColor
            ]

            let sepStr = " \u{2014} "
            let sepSize = sepStr.size(withAttributes: titleAttrs)

            sepStr.draw(
                at: CGPoint(x: appX + appSize.width, y: y + (height - sepSize.height) / 2),
                withAttributes: titleAttrs
            )

            // Truncate from original string to avoid compounding ellipsis
            let maxTitleW = width - appX - appSize.width - sepSize.width - rightPad - 4
            if maxTitleW > 20 {
                var truncated = window.windowTitle
                var titleSize = truncated.size(withAttributes: titleAttrs)

                if titleSize.width > maxTitleW {
                    while titleSize.width > maxTitleW && truncated.count > 1 {
                        truncated = String(truncated.dropLast())
                        titleSize = (truncated + "\u{2026}").size(withAttributes: titleAttrs)
                    }
                    truncated = truncated + "\u{2026}"
                    titleSize = truncated.size(withAttributes: titleAttrs)
                }

                truncated.draw(
                    at: CGPoint(
                        x: appX + appSize.width + sepSize.width,
                        y: y + (height - titleSize.height) / 2
                    ),
                    withAttributes: titleAttrs
                )
            }
        }
    }

    // MARK: - Scrolling

    private func ensureSelectedVisible(itemsAreaHeight: CGFloat) {
        guard !items.isEmpty && selectedIndex < itemLayouts.count else { return }

        let layout = itemLayouts[selectedIndex]

        // Include group gap above workspace headers so the gap is visible when scrolling
        var topPadding: CGFloat = 0
        if case .workspaceHeader = items[selectedIndex], selectedIndex > 0 {
            topPadding = groupGap
        }

        let itemTop = layout.relativeY - topPadding - scrollOffset
        let itemBottom = layout.relativeY + layout.height - scrollOffset

        if itemBottom > itemsAreaHeight {
            scrollOffset = layout.relativeY + layout.height - itemsAreaHeight
        }
        if itemTop < 0 {
            scrollOffset = layout.relativeY - topPadding
        }

        let maxScroll = max(0, totalItemsHeight - itemsAreaHeight)
        scrollOffset = max(0, min(scrollOffset, maxScroll))
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        let chars = event.charactersIgnoringModifiers?.lowercased()

        if items.isEmpty {
            if event.keyCode == 53 || event.keyCode == 36 {
                onDismiss?()
            }
            return
        }

        // Navigation
        if event.keyCode == 126 || chars == "k" {
            if selectedIndex > 0 {
                selectedIndex -= 1
                needsDisplay = true
            }
            return
        }
        if event.keyCode == 125 || chars == "j" {
            if selectedIndex < items.count - 1 {
                selectedIndex += 1
                needsDisplay = true
            }
            return
        }

        // Delete
        if chars == "x" || chars == "d" {
            deleteSelectedItem()
            return
        }

        // Dismiss
        if event.keyCode == 53 || event.keyCode == 36 {
            onDismiss?()
            return
        }
    }

    private func deleteSelectedItem() {
        guard selectedIndex >= 0 && selectedIndex < items.count else { return }

        let item = items[selectedIndex]

        switch item {
        case .workspaceHeader(let space):
            print("[VSManage] Deleting workspace \(space.number)")
            VirtualSpaceManager.shared.clearSpace(number: space.number, forMonitor: displayID)

        case .windowEntry(let spaceNumber, let window, _):
            print("[VSManage] Removing window '\(window.windowTitle)' from space \(spaceNumber)")
            removeWindowFromSpace(window, spaceNumber: spaceNumber)
        }

        rebuildItems()
        needsDisplay = true
        resizePanel()

        if items.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.onDismiss?()
            }
        }
    }

    private func removeWindowFromSpace(_ window: VirtualSpaceWindow, spaceNumber: Int) {
        var storage = SettingsManager.shared.settings.virtualSpaces
        guard var space = storage.getSpace(displayID: displayID, number: spaceNumber) else { return }

        space.windows.removeAll { $0 == window }

        if space.isEmpty {
            // Use VirtualSpaceManager to do full cleanup (sketchybar notification, etc.)
            // Call this before persisting the empty state so it can read the original space info
            VirtualSpaceManager.shared.clearSpace(number: spaceNumber, forMonitor: displayID)
        } else {
            storage.setSpace(space, displayID: displayID)
            SettingsManager.shared.saveVirtualSpacesQuietly(storage)
        }
    }

    private func resizePanel() {
        guard let window = self.window else { return }
        guard let screen = window.screen ?? NSScreen.main else { return }

        let contentHeight = calculateContentHeight()
        let maxHeight = min(screen.visibleFrame.height * 0.75, 700)
        let minHeight: CGFloat = 140
        let panelHeight = max(minHeight, min(contentHeight, maxHeight))

        let x = screen.frame.midX - window.frame.width / 2
        let y = screen.frame.midY - panelHeight / 2

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(
                NSRect(x: x, y: y, width: window.frame.width, height: panelHeight),
                display: true
            )
        })
    }
}
