import Foundation
import CoreGraphics

// MARK: - Grid Size

/// Represents the dimensions of a grid (columns x rows)
public struct GridSize: Equatable, Hashable {
    public let cols: Int
    public let rows: Int

    public init(cols: Int, rows: Int) {
        self.cols = max(1, cols)
        self.rows = max(1, rows)
    }

    /// Parse a grid size from string format "CxR" (e.g., "8x2")
    public static func parse(_ string: String) -> GridSize? {
        let parts = string.lowercased().split(separator: "x")
        guard parts.count == 2,
              let cols = Int(parts[0]),
              let rows = Int(parts[1]),
              cols > 0,
              rows > 0 else {
            return nil
        }
        return GridSize(cols: cols, rows: rows)
    }
}

// MARK: - Grid Offset

/// Represents a position in the grid (0-indexed)
public struct GridOffset: Equatable, Hashable {
    public let col: Int
    public let row: Int

    public init(col: Int, row: Int) {
        self.col = col
        self.row = row
    }
}

// MARK: - Grid Selection

/// Represents a rectangular selection in the grid from anchor to target
public struct GridSelection: Equatable {
    public let anchor: GridOffset
    public let target: GridOffset

    public init(anchor: GridOffset, target: GridOffset) {
        self.anchor = anchor
        self.target = target
    }

    /// Returns a normalized selection where anchor is top-left and target is bottom-right
    public var normalized: GridSelection {
        let minCol = min(anchor.col, target.col)
        let maxCol = max(anchor.col, target.col)
        let minRow = min(anchor.row, target.row)
        let maxRow = max(anchor.row, target.row)

        return GridSelection(
            anchor: GridOffset(col: minCol, row: minRow),
            target: GridOffset(col: maxCol, row: maxRow)
        )
    }

    /// Width of the selection in grid cells
    public var width: Int {
        return abs(target.col - anchor.col) + 1
    }

    /// Height of the selection in grid cells
    public var height: Int {
        return abs(target.row - anchor.row) + 1
    }
}

// MARK: - Direction

/// Cardinal directions for navigation
public enum Direction {
    case up, down, left, right

    public var opposite: Direction {
        switch self {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        }
    }

    public var colDelta: Int {
        switch self {
        case .left: return -1
        case .right: return 1
        case .up, .down: return 0
        }
    }

    public var rowDelta: Int {
        switch self {
        case .up: return -1
        case .down: return 1
        case .left, .right: return 0
        }
    }
}

// MARK: - Adjust Mode

/// Mode for adjusting selection size
public enum AdjustMode {
    case extend
    case shrink
}

// MARK: - Edge Insets

/// Insets for screen margins
public struct EdgeInsets: Equatable {
    public let top: CGFloat
    public let left: CGFloat
    public let bottom: CGFloat
    public let right: CGFloat

    public init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    public static let zero = EdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
}

// MARK: - Grid Operations

/// Operations on grid selections
public enum GridOperations {
    /// Pan the selection in a direction (move entire selection)
    public static func pan(selection: GridSelection, direction: Direction, gridSize: GridSize) -> GridSelection {
        let normalized = selection.normalized
        let selWidth = selection.width
        let selHeight = selection.height

        var newAnchorCol = normalized.anchor.col + direction.colDelta
        var newAnchorRow = normalized.anchor.row + direction.rowDelta

        // Clamp to grid boundaries
        newAnchorCol = max(0, min(newAnchorCol, gridSize.cols - selWidth))
        newAnchorRow = max(0, min(newAnchorRow, gridSize.rows - selHeight))

        let newTargetCol = newAnchorCol + selWidth - 1
        let newTargetRow = newAnchorRow + selHeight - 1

        return GridSelection(
            anchor: GridOffset(col: newAnchorCol, row: newAnchorRow),
            target: GridOffset(col: newTargetCol, row: newTargetRow)
        )
    }

    /// Adjust selection by extending or shrinking in a direction
    public static func adjust(selection: GridSelection, direction: Direction, mode: AdjustMode, gridSize: GridSize) -> GridSelection {
        let normalized = selection.normalized

        var newAnchor = normalized.anchor
        var newTarget = normalized.target

        switch mode {
        case .extend:
            switch direction {
            case .left:
                let newCol = max(0, newAnchor.col - 1)
                newAnchor = GridOffset(col: newCol, row: newAnchor.row)
            case .right:
                let newCol = min(gridSize.cols - 1, newTarget.col + 1)
                newTarget = GridOffset(col: newCol, row: newTarget.row)
            case .up:
                let newRow = max(0, newAnchor.row - 1)
                newAnchor = GridOffset(col: newAnchor.col, row: newRow)
            case .down:
                let newRow = min(gridSize.rows - 1, newTarget.row + 1)
                newTarget = GridOffset(col: newTarget.col, row: newRow)
            }

        case .shrink:
            switch direction {
            case .left:
                // Shrink left edge (move anchor right)
                if newAnchor.col < newTarget.col {
                    newAnchor = GridOffset(col: newAnchor.col + 1, row: newAnchor.row)
                }
            case .right:
                // Shrink right edge (move target left)
                if newTarget.col > newAnchor.col {
                    newTarget = GridOffset(col: newTarget.col - 1, row: newTarget.row)
                }
            case .up:
                // Shrink top edge (move anchor down)
                if newAnchor.row < newTarget.row {
                    newAnchor = GridOffset(col: newAnchor.col, row: newAnchor.row + 1)
                }
            case .down:
                // Shrink bottom edge (move target up)
                if newTarget.row > newAnchor.row {
                    newTarget = GridOffset(col: newTarget.col, row: newTarget.row - 1)
                }
            }
        }

        return GridSelection(anchor: newAnchor, target: newTarget)
    }

    /// Convert a grid selection to screen coordinates
    public static func selectionToRect(
        selection: GridSelection,
        gridSize: GridSize,
        screenFrame: CGRect,
        spacing: CGFloat,
        insets: EdgeInsets
    ) -> CGRect {
        let normalized = selection.normalized

        // Calculate available area after insets
        let availableWidth = screenFrame.width - insets.left - insets.right
        let availableHeight = screenFrame.height - insets.top - insets.bottom

        // Calculate cell dimensions
        let cellWidth = availableWidth / CGFloat(gridSize.cols)
        let cellHeight = availableHeight / CGFloat(gridSize.rows)

        // Calculate position
        let x = screenFrame.origin.x + insets.left + CGFloat(normalized.anchor.col) * cellWidth
        let y = screenFrame.origin.y + insets.top + CGFloat(normalized.anchor.row) * cellHeight

        // Calculate size
        let width = CGFloat(selection.width) * cellWidth
        let height = CGFloat(selection.height) * cellHeight

        // Apply spacing
        var finalX = x
        var finalY = y
        var finalWidth = width
        var finalHeight = height

        // Apply spacing: half spacing at edges, full spacing between cells
        if spacing > 0 {
            // Left edge
            if normalized.anchor.col > 0 {
                finalX += spacing / 2
                finalWidth -= spacing / 2
            }
            // Right edge
            if normalized.target.col < gridSize.cols - 1 {
                finalWidth -= spacing / 2
            }
            // Top edge
            if normalized.anchor.row > 0 {
                finalY += spacing / 2
                finalHeight -= spacing / 2
            }
            // Bottom edge
            if normalized.target.row < gridSize.rows - 1 {
                finalHeight -= spacing / 2
            }
        }

        return CGRect(x: finalX, y: finalY, width: finalWidth, height: finalHeight)
    }

    /// Convert screen coordinates to a grid selection
    public static func rectToSelection(
        rect: CGRect,
        gridSize: GridSize,
        screenFrame: CGRect,
        insets: EdgeInsets
    ) -> GridSelection {
        let availableWidth = screenFrame.width - insets.left - insets.right
        let availableHeight = screenFrame.height - insets.top - insets.bottom

        let cellWidth = availableWidth / CGFloat(gridSize.cols)
        let cellHeight = availableHeight / CGFloat(gridSize.rows)

        let relativeX = rect.origin.x - screenFrame.origin.x - insets.left
        let relativeY = rect.origin.y - screenFrame.origin.y - insets.top

        let anchorCol = Int(round(relativeX / cellWidth))
        let anchorRow = Int(round(relativeY / cellHeight))
        let targetCol = Int(round((relativeX + rect.width) / cellWidth)) - 1
        let targetRow = Int(round((relativeY + rect.height) / cellHeight)) - 1

        return GridSelection(
            anchor: GridOffset(
                col: max(0, min(anchorCol, gridSize.cols - 1)),
                row: max(0, min(anchorRow, gridSize.rows - 1))
            ),
            target: GridOffset(
                col: max(0, min(targetCol, gridSize.cols - 1)),
                row: max(0, min(targetRow, gridSize.rows - 1))
            )
        )
    }
}
