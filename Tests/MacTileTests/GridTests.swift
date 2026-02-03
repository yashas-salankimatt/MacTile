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

// MARK: - Visibility Calculator Tests

final class VisibilityCalculatorTests: XCTestCase {

    // MARK: - Basic Visibility Tests

    func testFullyVisibleWindow_NoOccluders() {
        // A window with no occluders should be 100% visible
        let window = CGRect(x: 0, y: 0, width: 100, height: 100)
        let occluders: [CGRect] = []

        let visibility = VisibilityCalculator.calculateVisibilityPercentage(
            of: window,
            occludedBy: occluders
        )

        XCTAssertEqual(visibility, 100.0, accuracy: 1.0)
    }

    func testFullyOccludedWindow() {
        // A window completely covered by an occluder should be 0% visible
        let window = CGRect(x: 100, y: 100, width: 100, height: 100)
        let occluder = CGRect(x: 50, y: 50, width: 200, height: 200) // Completely covers window

        let visibility = VisibilityCalculator.calculateVisibilityPercentage(
            of: window,
            occludedBy: [occluder]
        )

        XCTAssertEqual(visibility, 0.0, accuracy: 1.0)
    }

    func testHalfOccludedWindow_LeftHalf() {
        // Occluder covers left half of window
        let window = CGRect(x: 0, y: 0, width: 100, height: 100)
        let occluder = CGRect(x: 0, y: 0, width: 50, height: 100) // Covers left half

        let visibility = VisibilityCalculator.calculateVisibilityPercentage(
            of: window,
            occludedBy: [occluder]
        )

        XCTAssertEqual(visibility, 50.0, accuracy: 5.0) // Allow some grid sampling error
    }

    func testHalfOccludedWindow_TopHalf() {
        // Occluder covers top half of window
        let window = CGRect(x: 0, y: 0, width: 100, height: 100)
        let occluder = CGRect(x: 0, y: 50, width: 100, height: 50) // Covers top half

        let visibility = VisibilityCalculator.calculateVisibilityPercentage(
            of: window,
            occludedBy: [occluder]
        )

        XCTAssertEqual(visibility, 50.0, accuracy: 5.0)
    }

    func testQuarterOccludedWindow() {
        // Occluder covers top-left quarter
        let window = CGRect(x: 0, y: 0, width: 100, height: 100)
        let occluder = CGRect(x: 0, y: 50, width: 50, height: 50) // Covers top-left quarter

        let visibility = VisibilityCalculator.calculateVisibilityPercentage(
            of: window,
            occludedBy: [occluder]
        )

        XCTAssertEqual(visibility, 75.0, accuracy: 5.0)
    }

    // MARK: - Multiple Occluders Tests

    func testMultipleNonOverlappingOccluders() {
        // Two occluders, each covering 25% of window, not overlapping each other
        let window = CGRect(x: 0, y: 0, width: 100, height: 100)
        let occluder1 = CGRect(x: 0, y: 0, width: 50, height: 50)   // Bottom-left quarter
        let occluder2 = CGRect(x: 50, y: 50, width: 50, height: 50) // Top-right quarter

        let visibility = VisibilityCalculator.calculateVisibilityPercentage(
            of: window,
            occludedBy: [occluder1, occluder2]
        )

        XCTAssertEqual(visibility, 50.0, accuracy: 5.0) // 50% visible (two quarters covered)
    }

    func testOverlappingOccluders_ShouldNotDoubleCount() {
        // Two occluders that overlap each other over the target window
        // This tests that we don't double-count the overlapping region
        let window = CGRect(x: 0, y: 0, width: 100, height: 100)

        // Occluder 1 covers left 60% (x: 0-60)
        let occluder1 = CGRect(x: 0, y: 0, width: 60, height: 100)
        // Occluder 2 covers right 60% (x: 40-100)
        let occluder2 = CGRect(x: 40, y: 0, width: 60, height: 100)

        // Together they cover 100% (0-60 from occluder1, 60-100 from occluder2)
        // The overlap region (40-60) should only be counted once

        let visibility = VisibilityCalculator.calculateVisibilityPercentage(
            of: window,
            occludedBy: [occluder1, occluder2]
        )

        // Should be 0% visible (fully covered), not -20% (if we double-counted)
        XCTAssertEqual(visibility, 0.0, accuracy: 5.0)
    }

    func testPartiallyOverlappingOccluders() {
        // Two occluders that partially overlap, leaving some window visible
        let window = CGRect(x: 0, y: 0, width: 100, height: 100)

        // Occluder 1 covers left 40%
        let occluder1 = CGRect(x: 0, y: 0, width: 40, height: 100)
        // Occluder 2 covers middle 40% (overlaps 20% with occluder1)
        let occluder2 = CGRect(x: 20, y: 0, width: 40, height: 100)

        // Together they cover x: 0-60 (60% of window)
        // Window visible: x: 60-100 (40% of window)

        let visibility = VisibilityCalculator.calculateVisibilityPercentage(
            of: window,
            occludedBy: [occluder1, occluder2]
        )

        XCTAssertEqual(visibility, 40.0, accuracy: 5.0)
    }

    // MARK: - Edge Cases

    func testOccluderCompletelyOutsideWindow() {
        // Occluder doesn't overlap window at all
        let window = CGRect(x: 0, y: 0, width: 100, height: 100)
        let occluder = CGRect(x: 200, y: 200, width: 100, height: 100) // Far away

        let visibility = VisibilityCalculator.calculateVisibilityPercentage(
            of: window,
            occludedBy: [occluder]
        )

        XCTAssertEqual(visibility, 100.0, accuracy: 1.0)
    }

    func testOccluderPartiallyOutsideWindow() {
        // Occluder extends beyond window bounds - only intersection counts
        let window = CGRect(x: 50, y: 50, width: 100, height: 100)
        // Occluder starts at origin, covers bottom-left quarter of window
        let occluder = CGRect(x: 0, y: 0, width: 100, height: 100)

        // Intersection: (50,50) to (100,100) = 50x50 = 25% of window

        let visibility = VisibilityCalculator.calculateVisibilityPercentage(
            of: window,
            occludedBy: [occluder]
        )

        XCTAssertEqual(visibility, 75.0, accuracy: 5.0)
    }

    func testOccluderMuchLargerThanWindow() {
        // Very large occluder that completely engulfs window
        let window = CGRect(x: 100, y: 100, width: 50, height: 50)
        let occluder = CGRect(x: 0, y: 0, width: 1000, height: 1000)

        let visibility = VisibilityCalculator.calculateVisibilityPercentage(
            of: window,
            occludedBy: [occluder]
        )

        XCTAssertEqual(visibility, 0.0, accuracy: 1.0)
    }

    // MARK: - Threshold Tests (40% visibility)

    func testVisibility30Percent_BelowThreshold() {
        // Window is ~30% visible - should be clearly below 40% threshold
        let window = CGRect(x: 0, y: 0, width: 100, height: 100)
        // Cover 70% of window (left 70 pixels)
        let occluder = CGRect(x: 0, y: 0, width: 70, height: 100)

        let visibility = VisibilityCalculator.calculateVisibilityPercentage(
            of: window,
            occludedBy: [occluder]
        )

        XCTAssertLessThan(visibility, 40.0, "30% visible should be below 40% threshold")
    }

    func testVisibility50Percent_AboveThreshold() {
        // Window is 50% visible - should be clearly above 40% threshold
        let window = CGRect(x: 0, y: 0, width: 100, height: 100)
        // Cover 50% of window (left half)
        let occluder = CGRect(x: 0, y: 0, width: 50, height: 100)

        let visibility = VisibilityCalculator.calculateVisibilityPercentage(
            of: window,
            occludedBy: [occluder]
        )

        XCTAssertGreaterThan(visibility, 40.0, "50% visible should be above 40% threshold")
    }

    func testVisibilityNearThreshold_35Percent() {
        // Window is ~35% visible - should be below 40% threshold
        let window = CGRect(x: 0, y: 0, width: 100, height: 100)
        // Cover 65% of window
        let occluder = CGRect(x: 0, y: 0, width: 65, height: 100)

        let visibility = VisibilityCalculator.calculateVisibilityPercentage(
            of: window,
            occludedBy: [occluder]
        )

        XCTAssertLessThan(visibility, 40.0, "35% visible should be below 40% threshold")
    }

    func testVisibilityNearThreshold_45Percent() {
        // Window is ~45% visible - should be above 40% threshold
        let window = CGRect(x: 0, y: 0, width: 100, height: 100)
        // Cover 55% of window
        let occluder = CGRect(x: 0, y: 0, width: 55, height: 100)

        let visibility = VisibilityCalculator.calculateVisibilityPercentage(
            of: window,
            occludedBy: [occluder]
        )

        XCTAssertGreaterThan(visibility, 40.0, "45% visible should be above 40% threshold")
    }

    // MARK: - Real-World Scenario Tests

    func testSideBySideWindows_BothFullyVisible() {
        // Two windows side by side - neither occludes the other
        let leftWindow = CGRect(x: 0, y: 0, width: 500, height: 1000)
        let rightWindow = CGRect(x: 500, y: 0, width: 500, height: 1000)

        // Left window visibility (right window doesn't occlude it)
        let leftVisibility = VisibilityCalculator.calculateVisibilityPercentage(
            of: leftWindow,
            occludedBy: [rightWindow]
        )

        // Right window visibility (left window doesn't occlude it)
        let rightVisibility = VisibilityCalculator.calculateVisibilityPercentage(
            of: rightWindow,
            occludedBy: [leftWindow]
        )

        XCTAssertEqual(leftVisibility, 100.0, accuracy: 1.0)
        XCTAssertEqual(rightVisibility, 100.0, accuracy: 1.0)
    }

    func testFloatingFinderWindow_PartialOcclusion() {
        // Terminal on left, Finder floating on top (partially covering terminal)
        let terminal = CGRect(x: 0, y: 0, width: 500, height: 1000)
        let finder = CGRect(x: 200, y: 300, width: 300, height: 400) // Floating over terminal

        // Finder covers 300x400 = 120,000 of terminal's 500x1000 = 500,000
        // That's 24% covered, so 76% visible

        let terminalVisibility = VisibilityCalculator.calculateVisibilityPercentage(
            of: terminal,
            occludedBy: [finder]
        )

        XCTAssertEqual(terminalVisibility, 76.0, accuracy: 5.0)
    }

    func testCascadedWindows() {
        // Three cascaded windows (like when you Cmd+` through windows)
        let backWindow = CGRect(x: 0, y: 0, width: 800, height: 600)
        let middleWindow = CGRect(x: 50, y: 50, width: 800, height: 600)
        let frontWindow = CGRect(x: 100, y: 100, width: 800, height: 600)

        // Back window is occluded by both middle and front
        // Middle window is only occluded by front
        // Front window is not occluded

        let backVisibility = VisibilityCalculator.calculateVisibilityPercentage(
            of: backWindow,
            occludedBy: [middleWindow, frontWindow]
        )

        let middleVisibility = VisibilityCalculator.calculateVisibilityPercentage(
            of: middleWindow,
            occludedBy: [frontWindow]
        )

        let frontVisibility = VisibilityCalculator.calculateVisibilityPercentage(
            of: frontWindow,
            occludedBy: []
        )

        // Back window: visible region is roughly the L-shaped area not covered
        // Should be relatively low visibility
        XCTAssertLessThan(backVisibility, 30.0)

        // Middle window: similar L-shaped visible region
        XCTAssertLessThan(middleVisibility, 30.0)

        // Front window: fully visible
        XCTAssertEqual(frontVisibility, 100.0, accuracy: 1.0)
    }

    // MARK: - Filter Function Tests

    func testFilterWindowsByVisibility_KeepsVisibleWindows() {
        // Create a list of window frames with their z-indices
        // Windows with lower index are in front
        let windows: [(frame: CGRect, zIndex: Int)] = [
            (CGRect(x: 0, y: 0, width: 500, height: 500), 0),      // Front - 100% visible
            (CGRect(x: 500, y: 0, width: 500, height: 500), 1),    // Side - 100% visible
            (CGRect(x: 250, y: 250, width: 500, height: 500), 2),  // Back - partially covered
        ]

        let visibleIndices = VisibilityCalculator.filterByVisibility(
            windows: windows,
            minimumVisibility: 40.0
        )

        // First two should definitely be included (100% visible)
        XCTAssertTrue(visibleIndices.contains(0))
        XCTAssertTrue(visibleIndices.contains(1))
        // Third might or might not be included depending on exact coverage
    }

    func testFilterWindowsByVisibility_ExcludesHiddenWindows() {
        // Window completely behind another
        let windows: [(frame: CGRect, zIndex: Int)] = [
            (CGRect(x: 0, y: 0, width: 1000, height: 1000), 0),   // Front - covers everything
            (CGRect(x: 100, y: 100, width: 200, height: 200), 1), // Back - completely hidden
        ]

        let visibleIndices = VisibilityCalculator.filterByVisibility(
            windows: windows,
            minimumVisibility: 40.0
        )

        XCTAssertTrue(visibleIndices.contains(0))  // Front window visible
        XCTAssertFalse(visibleIndices.contains(1)) // Back window hidden
    }
}
