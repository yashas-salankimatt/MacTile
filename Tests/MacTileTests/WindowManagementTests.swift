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
