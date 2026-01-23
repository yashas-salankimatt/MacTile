import XCTest
@testable import MacTileCore

final class GridTests: XCTestCase {

    // MARK: - GridSize Tests

    func testGridSizeInitialization() {
        let grid = GridSize(cols: 8, rows: 2)
        XCTAssertEqual(grid.cols, 8)
        XCTAssertEqual(grid.rows, 2)
    }

    func testGridSizeEquatable() {
        let grid1 = GridSize(cols: 8, rows: 2)
        let grid2 = GridSize(cols: 8, rows: 2)
        let grid3 = GridSize(cols: 4, rows: 4)

        XCTAssertEqual(grid1, grid2)
        XCTAssertNotEqual(grid1, grid3)
    }

    func testGridSizeFromString() {
        let grid = GridSize.parse("8x2")
        XCTAssertNotNil(grid)
        XCTAssertEqual(grid?.cols, 8)
        XCTAssertEqual(grid?.rows, 2)

        let invalid = GridSize.parse("invalid")
        XCTAssertNil(invalid)

        let invalid2 = GridSize.parse("8x")
        XCTAssertNil(invalid2)
    }

    // MARK: - GridOffset Tests

    func testGridOffsetInitialization() {
        let offset = GridOffset(col: 2, row: 1)
        XCTAssertEqual(offset.col, 2)
        XCTAssertEqual(offset.row, 1)
    }

    func testGridOffsetEquatable() {
        let offset1 = GridOffset(col: 2, row: 1)
        let offset2 = GridOffset(col: 2, row: 1)
        let offset3 = GridOffset(col: 3, row: 1)

        XCTAssertEqual(offset1, offset2)
        XCTAssertNotEqual(offset1, offset3)
    }

    // MARK: - GridSelection Tests

    func testGridSelectionInitialization() {
        let anchor = GridOffset(col: 0, row: 0)
        let target = GridOffset(col: 3, row: 1)
        let selection = GridSelection(anchor: anchor, target: target)

        XCTAssertEqual(selection.anchor, anchor)
        XCTAssertEqual(selection.target, target)
    }

    func testGridSelectionNormalized() {
        // When target is before anchor, normalized should swap them
        let anchor = GridOffset(col: 3, row: 1)
        let target = GridOffset(col: 0, row: 0)
        let selection = GridSelection(anchor: anchor, target: target)
        let normalized = selection.normalized

        XCTAssertEqual(normalized.anchor.col, 0)
        XCTAssertEqual(normalized.anchor.row, 0)
        XCTAssertEqual(normalized.target.col, 3)
        XCTAssertEqual(normalized.target.row, 1)
    }

    func testGridSelectionWidth() {
        let selection = GridSelection(
            anchor: GridOffset(col: 1, row: 0),
            target: GridOffset(col: 4, row: 0)
        )
        XCTAssertEqual(selection.width, 4)
    }

    func testGridSelectionHeight() {
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 1),
            target: GridOffset(col: 0, row: 3)
        )
        XCTAssertEqual(selection.height, 3)
    }

    // MARK: - Pan Operation Tests

    func testPanRight() {
        let gridSize = GridSize(cols: 8, rows: 2)
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 1, row: 0)
        )

        let result = GridOperations.pan(selection: selection, direction: .right, gridSize: gridSize)

        XCTAssertEqual(result.anchor.col, 1)
        XCTAssertEqual(result.target.col, 2)
    }

    func testPanLeft() {
        let gridSize = GridSize(cols: 8, rows: 2)
        let selection = GridSelection(
            anchor: GridOffset(col: 1, row: 0),
            target: GridOffset(col: 2, row: 0)
        )

        let result = GridOperations.pan(selection: selection, direction: .left, gridSize: gridSize)

        XCTAssertEqual(result.anchor.col, 0)
        XCTAssertEqual(result.target.col, 1)
    }

    func testPanDown() {
        let gridSize = GridSize(cols: 8, rows: 4)
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 0, row: 0)
        )

        let result = GridOperations.pan(selection: selection, direction: .down, gridSize: gridSize)

        XCTAssertEqual(result.anchor.row, 1)
        XCTAssertEqual(result.target.row, 1)
    }

    func testPanUp() {
        let gridSize = GridSize(cols: 8, rows: 4)
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 1),
            target: GridOffset(col: 0, row: 2)
        )

        let result = GridOperations.pan(selection: selection, direction: .up, gridSize: gridSize)

        XCTAssertEqual(result.anchor.row, 0)
        XCTAssertEqual(result.target.row, 1)
    }

    func testPanClampedAtBoundary() {
        let gridSize = GridSize(cols: 8, rows: 2)
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 1, row: 0)
        )

        // Pan left at left boundary should not change
        let result = GridOperations.pan(selection: selection, direction: .left, gridSize: gridSize)

        XCTAssertEqual(result.anchor.col, 0)
        XCTAssertEqual(result.target.col, 1)
    }

    func testPanClampedAtRightBoundary() {
        let gridSize = GridSize(cols: 8, rows: 2)
        let selection = GridSelection(
            anchor: GridOffset(col: 6, row: 0),
            target: GridOffset(col: 7, row: 0)
        )

        // Pan right at right boundary should not change
        let result = GridOperations.pan(selection: selection, direction: .right, gridSize: gridSize)

        XCTAssertEqual(result.anchor.col, 6)
        XCTAssertEqual(result.target.col, 7)
    }

    // MARK: - Adjust/Extend Operation Tests

    func testExtendRight() {
        let gridSize = GridSize(cols: 8, rows: 2)
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 1, row: 0)
        )

        let result = GridOperations.adjust(selection: selection, direction: .right, mode: .extend, gridSize: gridSize)

        XCTAssertEqual(result.target.col, 2)
        XCTAssertEqual(result.anchor.col, 0) // anchor unchanged
    }

    func testExtendDown() {
        let gridSize = GridSize(cols: 8, rows: 4)
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 1, row: 0)
        )

        let result = GridOperations.adjust(selection: selection, direction: .down, mode: .extend, gridSize: gridSize)

        XCTAssertEqual(result.target.row, 1)
    }

    func testShrinkRight() {
        let gridSize = GridSize(cols: 8, rows: 2)
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 3, row: 0)
        )

        let result = GridOperations.adjust(selection: selection, direction: .right, mode: .shrink, gridSize: gridSize)

        XCTAssertEqual(result.target.col, 2)
    }

    func testShrinkCannotMakeSmallerThanOneCell() {
        let gridSize = GridSize(cols: 8, rows: 2)
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 0, row: 0)
        )

        let result = GridOperations.adjust(selection: selection, direction: .right, mode: .shrink, gridSize: gridSize)

        // Should remain 1 cell wide
        XCTAssertEqual(result.width, 1)
    }

    func testShrinkLeft() {
        let gridSize = GridSize(cols: 8, rows: 2)
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 3, row: 0)
        )

        let result = GridOperations.adjust(selection: selection, direction: .left, mode: .shrink, gridSize: gridSize)

        // Should shrink from left (anchor moves right)
        XCTAssertEqual(result.anchor.col, 1)
        XCTAssertEqual(result.target.col, 3)
        XCTAssertEqual(result.width, 3)
    }

    func testShrinkUp() {
        let gridSize = GridSize(cols: 8, rows: 4)
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 0, row: 2)
        )

        let result = GridOperations.adjust(selection: selection, direction: .up, mode: .shrink, gridSize: gridSize)

        // Should shrink from top (anchor moves down)
        XCTAssertEqual(result.anchor.row, 1)
        XCTAssertEqual(result.target.row, 2)
        XCTAssertEqual(result.height, 2)
    }

    func testShrinkDown() {
        let gridSize = GridSize(cols: 8, rows: 4)
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 0, row: 2)
        )

        let result = GridOperations.adjust(selection: selection, direction: .down, mode: .shrink, gridSize: gridSize)

        // Should shrink from bottom (target moves up)
        XCTAssertEqual(result.anchor.row, 0)
        XCTAssertEqual(result.target.row, 1)
        XCTAssertEqual(result.height, 2)
    }

    // MARK: - Rectangle to Selection Tests

    func testRectToSelectionLeftHalf() {
        let gridSize = GridSize(cols: 2, rows: 1)
        let screenFrame = CGRect(x: 0, y: 0, width: 1000, height: 500)
        // Window occupies left half
        let rect = CGRect(x: 0, y: 0, width: 500, height: 500)

        let selection = GridOperations.rectToSelection(
            rect: rect,
            gridSize: gridSize,
            screenFrame: screenFrame,
            insets: EdgeInsets.zero
        )

        XCTAssertEqual(selection.anchor.col, 0)
        XCTAssertEqual(selection.target.col, 0)
    }

    func testRectToSelectionRightHalf() {
        let gridSize = GridSize(cols: 2, rows: 1)
        let screenFrame = CGRect(x: 0, y: 0, width: 1000, height: 500)
        // Window occupies right half
        let rect = CGRect(x: 500, y: 0, width: 500, height: 500)

        let selection = GridOperations.rectToSelection(
            rect: rect,
            gridSize: gridSize,
            screenFrame: screenFrame,
            insets: EdgeInsets.zero
        )

        XCTAssertEqual(selection.anchor.col, 1)
        XCTAssertEqual(selection.target.col, 1)
    }

    func testRectToSelectionFullScreen() {
        let gridSize = GridSize(cols: 4, rows: 2)
        let screenFrame = CGRect(x: 0, y: 0, width: 800, height: 400)
        // Window occupies full screen
        let rect = CGRect(x: 0, y: 0, width: 800, height: 400)

        let selection = GridOperations.rectToSelection(
            rect: rect,
            gridSize: gridSize,
            screenFrame: screenFrame,
            insets: EdgeInsets.zero
        )

        XCTAssertEqual(selection.anchor.col, 0)
        XCTAssertEqual(selection.anchor.row, 0)
        XCTAssertEqual(selection.target.col, 3)
        XCTAssertEqual(selection.target.row, 1)
    }

    // MARK: - Rectangle Conversion Tests

    func testSelectionToRectangle() {
        let gridSize = GridSize(cols: 4, rows: 2)
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 1, row: 0)
        )
        let screenFrame = CGRect(x: 0, y: 0, width: 1000, height: 500)

        let rect = GridOperations.selectionToRect(
            selection: selection,
            gridSize: gridSize,
            screenFrame: screenFrame,
            spacing: 0,
            insets: EdgeInsets.zero
        )

        // 2 columns out of 4 = 50% of width = 500
        XCTAssertEqual(rect.width, 500, accuracy: 0.1)
        XCTAssertEqual(rect.height, 250, accuracy: 0.1) // half height (1 row of 2)
        XCTAssertEqual(rect.origin.x, 0, accuracy: 0.1)
        // Grid row 0 = top of screen, in macOS coords origin.y = 500 - 250 = 250
        XCTAssertEqual(rect.origin.y, 250, accuracy: 0.1)
    }

    func testSelectionToRectangleWithInsets() {
        let gridSize = GridSize(cols: 2, rows: 2)
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 1, row: 1)
        )
        let screenFrame = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        let insets = EdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        let rect = GridOperations.selectionToRect(
            selection: selection,
            gridSize: gridSize,
            screenFrame: screenFrame,
            spacing: 0,
            insets: insets
        )

        // Full grid minus insets
        XCTAssertEqual(rect.width, 980, accuracy: 0.1)
        XCTAssertEqual(rect.height, 980, accuracy: 0.1)
        XCTAssertEqual(rect.origin.x, 10, accuracy: 0.1)
        XCTAssertEqual(rect.origin.y, 10, accuracy: 0.1)
    }

    func testSelectionToRectangleWithSpacing() {
        let gridSize = GridSize(cols: 2, rows: 1)
        let selection = GridSelection(
            anchor: GridOffset(col: 0, row: 0),
            target: GridOffset(col: 0, row: 0)
        )
        let screenFrame = CGRect(x: 0, y: 0, width: 1000, height: 500)

        let rect = GridOperations.selectionToRect(
            selection: selection,
            gridSize: gridSize,
            screenFrame: screenFrame,
            spacing: 10,
            insets: EdgeInsets.zero
        )

        // Left cell should be 500 - 5 (half spacing) = 495 wide
        XCTAssertEqual(rect.width, 495, accuracy: 0.1)
    }
}

// MARK: - Direction Tests

final class DirectionTests: XCTestCase {
    func testDirectionOpposites() {
        XCTAssertEqual(Direction.left.opposite, Direction.right)
        XCTAssertEqual(Direction.right.opposite, Direction.left)
        XCTAssertEqual(Direction.up.opposite, Direction.down)
        XCTAssertEqual(Direction.down.opposite, Direction.up)
    }

    func testDirectionDelta() {
        XCTAssertEqual(Direction.left.colDelta, -1)
        XCTAssertEqual(Direction.right.colDelta, 1)
        XCTAssertEqual(Direction.up.rowDelta, -1)
        XCTAssertEqual(Direction.down.rowDelta, 1)
    }
}

// MARK: - EdgeInsets Tests

final class EdgeInsetsTests: XCTestCase {
    func testEdgeInsetsZero() {
        let insets = EdgeInsets.zero
        XCTAssertEqual(insets.top, 0)
        XCTAssertEqual(insets.left, 0)
        XCTAssertEqual(insets.bottom, 0)
        XCTAssertEqual(insets.right, 0)
    }

    func testEdgeInsetsInitialization() {
        let insets = EdgeInsets(top: 10, left: 20, bottom: 30, right: 40)
        XCTAssertEqual(insets.top, 10)
        XCTAssertEqual(insets.left, 20)
        XCTAssertEqual(insets.bottom, 30)
        XCTAssertEqual(insets.right, 40)
    }
}
