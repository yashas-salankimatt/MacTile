import XCTest
@testable import MacTileCore

// Helper to assert CGFloat with accuracy
func assertEqualWithAccuracy(_ actual: CGFloat?, _ expected: Double, accuracy: Double, file: StaticString = #file, line: UInt = #line) {
    guard let actual = actual else {
        XCTFail("Value was nil", file: file, line: line)
        return
    }
    XCTAssertEqual(Double(actual), expected, accuracy: accuracy, file: file, line: line)
}

final class WindowManagementTests: XCTestCase {

    // MARK: - Mock Setup Tests

    func testMockWindowInfoCreation() {
        let window = MockWindowInfo(
            identifier: 123,
            title: "Test",
            frame: CGRect(x: 100, y: 100, width: 500, height: 400),
            processIdentifier: 456,
            isMinimized: false
        )

        XCTAssertEqual(window.identifier, 123)
        XCTAssertEqual(window.title, "Test")
        XCTAssertEqual(window.frame, CGRect(x: 100, y: 100, width: 500, height: 400))
        XCTAssertEqual(window.processIdentifier, 456)
        XCTAssertFalse(window.isMinimized)
    }

    func testMockScreenInfoCreation() {
        let screen = MockScreenInfo(
            identifier: 1,
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055),
            isMain: true
        )

        XCTAssertEqual(screen.identifier, 1)
        XCTAssertEqual(screen.frame, CGRect(x: 0, y: 0, width: 1920, height: 1080))
        XCTAssertEqual(screen.visibleFrame, CGRect(x: 0, y: 25, width: 1920, height: 1055))
        XCTAssertTrue(screen.isMain)
    }

    func testMockWindowManagerBasics() {
        let manager = MockWindowManager()

        XCTAssertTrue(manager.hasAccessibilityPermissions())
        XCTAssertNotNil(manager.getMainScreen())
    }

    // MARK: - Window Tiler Tests

    func testTileFocusedWindowLeftHalf() {
        let manager = MockWindowManager()
        let screen = MockScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 500),
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 500)
        )
        manager.screens = [screen]

        let window = MockWindowInfo(
            identifier: 1,
            title: "Test",
            frame: CGRect(x: 200, y: 100, width: 400, height: 300)
        )
        manager.windows = [window]
        manager.focusedWindow = window

        let tiler = WindowTiler(windowManager: manager)
        tiler.spacing = 0
        tiler.insets = EdgeInsets.zero

        // Select left half of a 2x1 grid
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 0, row: 0)
        )
        let gridSize = GridSize(cols: 2, rows: 1)

        let result = tiler.tileFocusedWindow(to: selection, gridSize: gridSize)

        XCTAssertTrue(result)
        XCTAssertNotNil(manager.lastSetFrame)

        // Should be left half: x=0, width=500
        assertEqualWithAccuracy(manager.lastSetFrame?.origin.x, 0, accuracy: 0.1)
        assertEqualWithAccuracy(manager.lastSetFrame?.width, 500, accuracy: 0.1)
        assertEqualWithAccuracy(manager.lastSetFrame?.height, 500, accuracy: 0.1)
    }

    func testTileFocusedWindowRightHalf() {
        let manager = MockWindowManager()
        let screen = MockScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 500),
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 500)
        )
        manager.screens = [screen]

        let window = MockWindowInfo()
        manager.windows = [window]
        manager.focusedWindow = window

        let tiler = WindowTiler(windowManager: manager)
        tiler.spacing = 0
        tiler.insets = EdgeInsets.zero

        // Select right half of a 2x1 grid
        let selection = GridSelection(
            anchor: GridOffset(col: 1, row: 0),
            target: GridOffset(col: 1, row: 0)
        )
        let gridSize = GridSize(cols: 2, rows: 1)

        let result = tiler.tileFocusedWindow(to: selection, gridSize: gridSize)

        XCTAssertTrue(result)

        // Should be right half: x=500, width=500
        assertEqualWithAccuracy(manager.lastSetFrame?.origin.x, 500, accuracy: 0.1)
        assertEqualWithAccuracy(manager.lastSetFrame?.width, 500, accuracy: 0.1)
    }

    func testTileFocusedWindowTopLeft() {
        let manager = MockWindowManager()
        let screen = MockScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 1000),
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 1000)
        )
        manager.screens = [screen]

        let window = MockWindowInfo()
        manager.windows = [window]
        manager.focusedWindow = window

        let tiler = WindowTiler(windowManager: manager)
        tiler.spacing = 0
        tiler.insets = EdgeInsets.zero

        // Select top-left quadrant of a 2x2 grid
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 0, row: 0)
        )
        let gridSize = GridSize(cols: 2, rows: 2)

        let result = tiler.tileFocusedWindow(to: selection, gridSize: gridSize)

        XCTAssertTrue(result)

        assertEqualWithAccuracy(manager.lastSetFrame?.origin.x, 0, accuracy: 0.1)
        // Grid row 0 = top of screen, in macOS coords y = 1000 - 500 = 500
        assertEqualWithAccuracy(manager.lastSetFrame?.origin.y, 500, accuracy: 0.1)
        assertEqualWithAccuracy(manager.lastSetFrame?.width, 500, accuracy: 0.1)
        assertEqualWithAccuracy(manager.lastSetFrame?.height, 500, accuracy: 0.1)
    }

    func testTileFocusedWindowBottomRight() {
        let manager = MockWindowManager()
        let screen = MockScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 1000),
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 1000)
        )
        manager.screens = [screen]

        let window = MockWindowInfo()
        manager.windows = [window]
        manager.focusedWindow = window

        let tiler = WindowTiler(windowManager: manager)
        tiler.spacing = 0
        tiler.insets = EdgeInsets.zero

        // Select bottom-right quadrant of a 2x2 grid
        let selection = GridSelection(
            anchor: GridOffset(col: 1, row: 1),
            target: GridOffset(col: 1, row: 1)
        )
        let gridSize = GridSize(cols: 2, rows: 2)

        let result = tiler.tileFocusedWindow(to: selection, gridSize: gridSize)

        XCTAssertTrue(result)

        assertEqualWithAccuracy(manager.lastSetFrame?.origin.x, 500, accuracy: 0.1)
        // Grid row 1 = bottom of screen, in macOS coords y = 0
        assertEqualWithAccuracy(manager.lastSetFrame?.origin.y, 0, accuracy: 0.1)
        assertEqualWithAccuracy(manager.lastSetFrame?.width, 500, accuracy: 0.1)
        assertEqualWithAccuracy(manager.lastSetFrame?.height, 500, accuracy: 0.1)
    }

    func testTileFocusedWindowMultipleCells() {
        let manager = MockWindowManager()
        let screen = MockScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 800, height: 400),
            visibleFrame: CGRect(x: 0, y: 0, width: 800, height: 400)
        )
        manager.screens = [screen]

        let window = MockWindowInfo()
        manager.windows = [window]
        manager.focusedWindow = window

        let tiler = WindowTiler(windowManager: manager)
        tiler.spacing = 0
        tiler.insets = EdgeInsets.zero

        // Select 3 columns out of 4 (left 75%)
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 2, row: 0)
        )
        let gridSize = GridSize(cols: 4, rows: 1)

        let result = tiler.tileFocusedWindow(to: selection, gridSize: gridSize)

        XCTAssertTrue(result)

        assertEqualWithAccuracy(manager.lastSetFrame?.origin.x, 0, accuracy: 0.1)
        assertEqualWithAccuracy(manager.lastSetFrame?.width, 600, accuracy: 0.1) // 3/4 of 800
    }

    func testTileWithSpacing() {
        let manager = MockWindowManager()
        let screen = MockScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 500),
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 500)
        )
        manager.screens = [screen]

        let window = MockWindowInfo()
        manager.windows = [window]
        manager.focusedWindow = window

        let tiler = WindowTiler(windowManager: manager)
        tiler.spacing = 20
        tiler.insets = EdgeInsets.zero

        // Select left half with spacing
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 0, row: 0)
        )
        let gridSize = GridSize(cols: 2, rows: 1)

        let result = tiler.tileFocusedWindow(to: selection, gridSize: gridSize)

        XCTAssertTrue(result)

        // Width should be reduced by half spacing (10) because it's adjacent to right cell
        assertEqualWithAccuracy(manager.lastSetFrame?.width, 490, accuracy: 0.1)
    }

    func testTileWithInsets() {
        let manager = MockWindowManager()
        let screen = MockScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 500),
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 500)
        )
        manager.screens = [screen]

        let window = MockWindowInfo()
        manager.windows = [window]
        manager.focusedWindow = window

        let tiler = WindowTiler(windowManager: manager)
        tiler.spacing = 0
        tiler.insets = EdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        // Full screen with insets
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 0, row: 0)
        )
        let gridSize = GridSize(cols: 1, rows: 1)

        let result = tiler.tileFocusedWindow(to: selection, gridSize: gridSize)

        XCTAssertTrue(result)

        assertEqualWithAccuracy(manager.lastSetFrame?.origin.x, 10, accuracy: 0.1)
        assertEqualWithAccuracy(manager.lastSetFrame?.origin.y, 10, accuracy: 0.1)
        assertEqualWithAccuracy(manager.lastSetFrame?.width, 980, accuracy: 0.1)
        assertEqualWithAccuracy(manager.lastSetFrame?.height, 480, accuracy: 0.1)
    }

    func testTileFailsWithoutWindow() {
        let manager = MockWindowManager()
        manager.windows = []
        manager.focusedWindow = nil

        let tiler = WindowTiler(windowManager: manager)

        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 0, row: 0)
        )
        let gridSize = GridSize(cols: 2, rows: 1)

        let result = tiler.tileFocusedWindow(to: selection, gridSize: gridSize)

        XCTAssertFalse(result)
        XCTAssertNil(manager.lastSetFrame)
    }

    func testTileFailsWithoutPermissions() {
        let manager = MockWindowManager()
        manager.hasPermissions = false

        let window = MockWindowInfo()
        manager.windows = [window]
        manager.focusedWindow = window

        let tiler = WindowTiler(windowManager: manager)

        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 0, row: 0)
        )
        let gridSize = GridSize(cols: 2, rows: 1)

        let result = tiler.tileFocusedWindow(to: selection, gridSize: gridSize)

        XCTAssertFalse(result)
    }

    func testGetWindowSelection() {
        let manager = MockWindowManager()
        let screen = MockScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 500),
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 500)
        )
        manager.screens = [screen]

        // Window positioned in left half
        let window = MockWindowInfo(
            frame: CGRect(x: 0, y: 0, width: 500, height: 500)
        )
        manager.windows = [window]
        manager.focusedWindow = window

        let tiler = WindowTiler(windowManager: manager)
        tiler.spacing = 0
        tiler.insets = EdgeInsets.zero

        let gridSize = GridSize(cols: 2, rows: 1)
        let selection = tiler.getWindowSelection(gridSize: gridSize)

        XCTAssertNotNil(selection)
        XCTAssertEqual(selection?.anchor.col, 0)
        XCTAssertEqual(selection?.target.col, 0)
    }

    // MARK: - 8x2 Grid Tests (User's Preferred Configuration)

    func testTile8x2GridLeftmostColumn() {
        let manager = MockWindowManager()
        let screen = MockScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1600, height: 200),
            visibleFrame: CGRect(x: 0, y: 0, width: 1600, height: 200)
        )
        manager.screens = [screen]

        let window = MockWindowInfo()
        manager.windows = [window]
        manager.focusedWindow = window

        let tiler = WindowTiler(windowManager: manager)
        tiler.spacing = 0
        tiler.insets = EdgeInsets.zero

        // Select first column of 8x2 grid (full height)
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 0, row: 1)
        )
        let gridSize = GridSize(cols: 8, rows: 2)

        let result = tiler.tileFocusedWindow(to: selection, gridSize: gridSize)

        XCTAssertTrue(result)

        // Width should be 1/8 of 1600 = 200
        assertEqualWithAccuracy(manager.lastSetFrame?.width, 200, accuracy: 0.1)
        // Height should be full
        assertEqualWithAccuracy(manager.lastSetFrame?.height, 200, accuracy: 0.1)
    }

    func testTile8x2GridSpan4Columns() {
        let manager = MockWindowManager()
        let screen = MockScreenInfo(
            frame: CGRect(x: 0, y: 0, width: 1600, height: 200),
            visibleFrame: CGRect(x: 0, y: 0, width: 1600, height: 200)
        )
        manager.screens = [screen]

        let window = MockWindowInfo()
        manager.windows = [window]
        manager.focusedWindow = window

        let tiler = WindowTiler(windowManager: manager)
        tiler.spacing = 0
        tiler.insets = EdgeInsets.zero

        // Select 4 columns (half width, full height)
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 3, row: 1)
        )
        let gridSize = GridSize(cols: 8, rows: 2)

        let result = tiler.tileFocusedWindow(to: selection, gridSize: gridSize)

        XCTAssertTrue(result)

        // Width should be 4/8 of 1600 = 800
        assertEqualWithAccuracy(manager.lastSetFrame?.width, 800, accuracy: 0.1)
    }
}

// MARK: - Resize State Checking Tests

/// Tests for ResizeStateChecker - the production logic that determines if a resize operation was successful
/// These test the decision-making logic without needing actual AX API calls
final class ResizeStateCheckingTests: XCTestCase {

    // MARK: - Size OK Tests

    func testSizeOK_ExactMatch() {
        let target = CGSize(width: 1290, height: 1415)
        let actual = CGSize(width: 1290, height: 1415)
        XCTAssertTrue(ResizeStateChecker.isSizeOK(actual: actual, target: target))
    }

    func testSizeOK_WithinTolerance() {
        let target = CGSize(width: 1290, height: 1415)
        let actual = CGSize(width: 1295, height: 1410) // 5 pixels off each
        XCTAssertTrue(ResizeStateChecker.isSizeOK(actual: actual, target: target))
    }

    func testSizeOK_OutsideTolerance() {
        let target = CGSize(width: 1290, height: 1415)
        let actual = CGSize(width: 1320, height: 1415) // 30 pixels off width
        XCTAssertFalse(ResizeStateChecker.isSizeOK(actual: actual, target: target))
    }

    func testSizeOK_BothDimensionsOff() {
        let target = CGSize(width: 1290, height: 1415)
        let actual = CGSize(width: 1320, height: 1380) // both off
        XCTAssertFalse(ResizeStateChecker.isSizeOK(actual: actual, target: target))
    }

    // MARK: - Minimum Constraint Detection Tests

    func testMinimumConstraint_WidthExceedsHeightOK() {
        // Browser has minimum width of 500, we asked for 400
        let target = CGSize(width: 400, height: 1000)
        let actual = CGSize(width: 500, height: 1000)
        XCTAssertTrue(ResizeStateChecker.isMinimumConstraint(actual: actual, target: target))
    }

    func testMinimumConstraint_HeightExceedsWidthOK() {
        // App has minimum height of 600, we asked for 500
        let target = CGSize(width: 1000, height: 500)
        let actual = CGSize(width: 1000, height: 600)
        XCTAssertTrue(ResizeStateChecker.isMinimumConstraint(actual: actual, target: target))
    }

    func testMinimumConstraint_BothExceed() {
        // App has minimum size larger than requested
        let target = CGSize(width: 400, height: 300)
        let actual = CGSize(width: 500, height: 400)
        XCTAssertTrue(ResizeStateChecker.isMinimumConstraint(actual: actual, target: target))
    }

    func testMinimumConstraint_WidthExceedsHeightShort() {
        // This is NOT a minimum constraint - height is SHORT
        // This happens when browser is fighting with us
        let target = CGSize(width: 1290, height: 1415)
        let actual = CGSize(width: 1484, height: 1097) // width exceeds, height short
        XCTAssertFalse(ResizeStateChecker.isMinimumConstraint(actual: actual, target: target))
    }

    func testMinimumConstraint_HeightExceedsWidthShort() {
        // This is NOT a minimum constraint - width is SHORT
        let target = CGSize(width: 1500, height: 800)
        let actual = CGSize(width: 1200, height: 900) // height exceeds, width short
        XCTAssertFalse(ResizeStateChecker.isMinimumConstraint(actual: actual, target: target))
    }

    func testMinimumConstraint_BothShort() {
        // Definitely not a minimum constraint - app didn't even try
        let target = CGSize(width: 1500, height: 1200)
        let actual = CGSize(width: 1200, height: 1000)
        XCTAssertFalse(ResizeStateChecker.isMinimumConstraint(actual: actual, target: target))
    }

    func testMinimumConstraint_SizeMatches() {
        // Size matches - no minimum constraint issue
        let target = CGSize(width: 1290, height: 1415)
        let actual = CGSize(width: 1290, height: 1415)
        XCTAssertFalse(ResizeStateChecker.isMinimumConstraint(actual: actual, target: target))
    }

    func testMinimumConstraint_SlightlyOver() {
        // Within tolerance - not considered exceeding
        let target = CGSize(width: 1290, height: 1415)
        let actual = CGSize(width: 1293, height: 1418) // 3 pixels over each
        XCTAssertFalse(ResizeStateChecker.isMinimumConstraint(actual: actual, target: target))
    }

    // MARK: - Position OK Tests

    func testPositionOK_ExactMatch() {
        let target = CGPoint(x: 860, y: 25)
        let actual = CGPoint(x: 860, y: 25)
        XCTAssertTrue(ResizeStateChecker.isPositionOK(actual: actual, target: target))
    }

    func testPositionOK_WithinTolerance() {
        let target = CGPoint(x: 860, y: 25)
        let actual = CGPoint(x: 865, y: 28) // 5 and 3 pixels off
        XCTAssertTrue(ResizeStateChecker.isPositionOK(actual: actual, target: target))
    }

    func testPositionOK_OutsideTolerance() {
        let target = CGPoint(x: 860, y: 25)
        let actual = CGPoint(x: 900, y: 25) // 40 pixels off
        XCTAssertFalse(ResizeStateChecker.isPositionOK(actual: actual, target: target))
    }

    func testPositionOK_PositionDriftedDuringResize() {
        // This scenario: we set position to 1290, then resized, and it drifted to 295
        let target = CGPoint(x: 1290, y: 25)
        let actual = CGPoint(x: 295, y: 25) // massive drift
        XCTAssertFalse(ResizeStateChecker.isPositionOK(actual: actual, target: target))
    }

    // MARK: - Frame OK Tests (combined size and position)

    func testFrameOK_ExactMatch() {
        let target = CGRect(x: 100, y: 200, width: 800, height: 600)
        let actual = CGRect(x: 100, y: 200, width: 800, height: 600)
        XCTAssertTrue(ResizeStateChecker.isFrameOK(actualFrame: actual, targetFrame: target))
    }

    func testFrameOK_WithinTolerance() {
        let target = CGRect(x: 100, y: 200, width: 800, height: 600)
        let actual = CGRect(x: 105, y: 203, width: 795, height: 605)
        XCTAssertTrue(ResizeStateChecker.isFrameOK(actualFrame: actual, targetFrame: target))
    }

    func testFrameOK_SizeOffPositionOK() {
        let target = CGRect(x: 100, y: 200, width: 800, height: 600)
        let actual = CGRect(x: 100, y: 200, width: 850, height: 600) // position OK, size not
        XCTAssertFalse(ResizeStateChecker.isFrameOK(actualFrame: actual, targetFrame: target))
    }

    func testFrameOK_SizeOKPositionOff() {
        let target = CGRect(x: 100, y: 200, width: 800, height: 600)
        let actual = CGRect(x: 150, y: 200, width: 800, height: 600) // size OK, position not
        XCTAssertFalse(ResizeStateChecker.isFrameOK(actualFrame: actual, targetFrame: target))
    }

    // MARK: - Combined Scenario Tests (Real-world cases from logs)

    func testScenario_BrowserFightingResize() {
        // From logs: Target (1290, 1415), got (1484, 1097)
        // Browser is fighting - width exceeds but height is SHORT
        // This is NOT a minimum constraint - need to keep retrying
        let targetSize = CGSize(width: 1290, height: 1415)
        let actualSize = CGSize(width: 1484, height: 1097)

        XCTAssertFalse(ResizeStateChecker.isSizeOK(actual: actualSize, target: targetSize))
        XCTAssertFalse(ResizeStateChecker.isMinimumConstraint(actual: actualSize, target: targetSize))
        // Should NOT accept this as OK - need to retry
    }

    func testScenario_IntermediateSizeDuringResize() {
        // From logs: When shrinking from 1415 to 707.5 height, browser gave 1073
        // This is NOT a minimum constraint - it's an intermediate value
        // We've seen the browser go to 707-708 height successfully before
        let targetSize = CGSize(width: 1720, height: 707.5)
        let actualSize = CGSize(width: 1720, height: 1073)

        XCTAssertFalse(ResizeStateChecker.isSizeOK(actual: actualSize, target: targetSize))
        // Height exceeds but this should NOT be accepted on first attempt
        // Only accept as minimum constraint if stuck for 3+ attempts
        // The isMinimumConstraint function returns true, but the actual
        // WindowManager logic only uses it after being stuck
        XCTAssertTrue(ResizeStateChecker.isMinimumConstraint(actual: actualSize, target: targetSize))
        // Key insight: The function says it's a constraint, but we shouldn't
        // ACCEPT it until we've been stuck for 3+ attempts
    }

    func testScenario_GradualResizeProgress() {
        // From logs: size gradually approaching target
        // 1456 -> 1536 -> 1680 -> 1712 (target 1720)
        let targetSize = CGSize(width: 1720, height: 1415)

        XCTAssertFalse(ResizeStateChecker.isSizeOK(actual: CGSize(width: 1456, height: 1415), target: targetSize))
        XCTAssertFalse(ResizeStateChecker.isSizeOK(actual: CGSize(width: 1536, height: 1415), target: targetSize))
        XCTAssertFalse(ResizeStateChecker.isSizeOK(actual: CGSize(width: 1680, height: 1415), target: targetSize))
        XCTAssertTrue(ResizeStateChecker.isSizeOK(actual: CGSize(width: 1712, height: 1415), target: targetSize)) // within tolerance
    }

    func testScenario_TrueMinimumWidthConstraint() {
        // From logs: Fusion app has minimum width of 1200
        // Target: 860, Actual: 1200
        let targetSize = CGSize(width: 860, height: 1415)
        let actualSize = CGSize(width: 1200, height: 1415)

        XCTAssertFalse(ResizeStateChecker.isSizeOK(actual: actualSize, target: targetSize))
        XCTAssertTrue(ResizeStateChecker.isMinimumConstraint(actual: actualSize, target: targetSize))
        // This IS a minimum constraint - should accept
    }

    func testScenario_SmallSizeVariationFromBrowser() {
        // Browsers often give sizes like 1724 instead of 1720
        let targetSize = CGSize(width: 1720, height: 1415)
        let actualSize = CGSize(width: 1724, height: 1415)

        XCTAssertTrue(ResizeStateChecker.isSizeOK(actual: actualSize, target: targetSize)) // within tolerance
    }

    func testScenario_PositionDriftAfterSizeChange() {
        // From logs: Position was (1290, 25) then drifted to (295, 25) after size change
        let targetPos = CGPoint(x: 1290, y: 25)
        let actualPos = CGPoint(x: 295, y: 25)

        XCTAssertFalse(ResizeStateChecker.isPositionOK(actual: actualPos, target: targetPos))
        // Should detect this and re-correct position
    }

    // MARK: - Tolerance Configuration Tests

    func testDefaultTolerance() {
        XCTAssertEqual(ResizeStateChecker.defaultTolerance, 10)
    }

    func testCustomTolerance() {
        let target = CGSize(width: 1000, height: 1000)
        let actual = CGSize(width: 1015, height: 1000) // 15 pixels off

        // Should fail with default tolerance (10)
        XCTAssertFalse(ResizeStateChecker.isSizeOK(actual: actual, target: target))

        // Should pass with custom tolerance (20)
        XCTAssertTrue(ResizeStateChecker.isSizeOK(actual: actual, target: target, tolerance: 20))
    }
}
