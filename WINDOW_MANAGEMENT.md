# Window Management: Technical Deep Dive

MacTile's window management system solves significant challenges with the macOS Accessibility API. This document details the key insights and algorithms that make reliable window tiling possible.

## The Core Challenge

Unlike GNOME (where gTile operates), macOS's Accessibility API is **asynchronous**. When you call `AXUIElementSetAttributeValue` to set a window's size or position, the call returns immediately but the window may not reach the target state for several milliseconds—or may never reach it due to application constraints.

This creates several problems:
1. **Race conditions**: Reading window state immediately after setting it returns stale values
2. **Position-size coupling**: Many apps (especially browsers) move the window when you resize it, and vice versa
3. **Minimum constraints**: Apps may enforce minimum window sizes that differ from our target
4. **Edge anchoring**: Windows near screen edges may anchor to that edge during resize operations

## Key Insights from Development

### 1. gTile Doesn't Need Retries—But We Do

Exploring gTile's codebase revealed they use a simple two-step approach:
```javascript
moveResize(window, newX, newY, newWidth, newHeight) {
    window.move_frame(true, newX, newY);
    window.move_resize_frame(true, newX, newY, newWidth, newHeight);
}
```

This works for gTile because GNOME's window management API is **synchronous**—the window is guaranteed to be at the target state when the call returns. macOS provides no such guarantee.

### 2. The "Safe Zone" Strategy

Windows near screen edges exhibit unexpected behavior during resizing. A window at the right edge may anchor to that edge, causing position drift when resized. The solution:

1. **Move to safe zone first**: Move the window to x=0 (left edge) before any resize operations
2. **Resize in the safe zone**: The left edge provides consistent anchoring behavior
3. **Move to final position**: After achieving target size, move to the intended position

This approach dramatically improved reliability across all tested applications.

### 3. Unified Correction Loop

Because position and size changes can affect each other, we use a **unified correction loop** that sets both attributes in each iteration:

```
For each attempt (up to 10):
    1. Read current window state
    2. Check if position is within tolerance (±10px)
    3. Check if size is within tolerance (±10px)
    4. If both OK, we're done
    5. If stuck for 3+ attempts with no change, check for minimum constraints
    6. Otherwise: Set size → wait → Set position → wait → Set size → wait → Set position → wait
```

The double set (size-position-size-position) helps overcome apps that "fight back" against changes.

### 4. Minimum Constraint Detection

Some applications enforce minimum window sizes. Detecting this correctly is crucial:

- **Wrong approach**: Accept "size exceeds target" on first attempt as minimum constraint
- **Problem**: Intermediate resize states can temporarily exceed target in one dimension while being short in another
- **Correct approach**: Only detect minimum constraint after 3+ consecutive attempts with **no state change at all**

The key insight: if we're truly at a minimum constraint, the window state will be completely stable (not changing at all), and the size will exceed the target without falling short in any dimension.

### 5. Tolerance-Based Success

Pixel-perfect positioning is neither possible nor necessary:
- **±10 pixels** is acceptable for both position and size
- This accounts for window chrome variations and system-level adjustments

## The Final Algorithm

```
moveAndResizeWindow(window, targetFrame):
    1. FOCUS: Bring window to front (required for some apps)

    2. SAFE ZONE: Move window to x=0 to avoid edge effects
       - Set position to (0, targetY)
       - Wait for position to stabilize (up to 5 attempts)

    3. INITIAL SIZE: Set target size in safe zone
       - Apply target size
       - Short delay for async processing

    4. UNIFIED CORRECTION LOOP (up to 10 attempts):
       - Read current state
       - Check position tolerance (±10px)
       - Check size tolerance (±10px)
       - If both OK → success
       - If stuck 3+ times with no change:
           - If size exceeds target in all dimensions → minimum constraint (accept)
           - Otherwise → give up
       - Apply: size → delay → position → delay → size → delay → position → delay

    5. REPORT: Log final state and any remaining deltas
```

## Why This Works

1. **Safe zone eliminates edge anchoring**: By starting at x=0, we get consistent resize behavior
2. **Multiple iterations overcome async delays**: The AX API may take several attempts to reach target
3. **Position-size coupling handled**: Setting both each iteration corrects mutual interference
4. **Conservative minimum detection**: Only accepts constraints after confirming window is truly stuck
5. **Tolerance allows imperfection**: Real-world window management has inherent imprecision

## Testing the Algorithm

The test suite includes specific scenarios from real-world debugging:

```swift
func testScenario_BrowserFightingResize() {
    // From logs: Target (1290, 1415), got (1484, 1097)
    // Browser fighting - width exceeds but height is SHORT
    // This should NOT be accepted as minimum constraint
    let targetSize = CGSize(width: 1290, height: 1415)
    let actualSize = CGSize(width: 1484, height: 1097)
    XCTAssertFalse(isMinimumConstraint(actual: actualSize, target: targetSize))
}
```

This test captures the bug that was causing incorrect minimum constraint detection—the system was accepting intermediate states where one dimension exceeded target but another fell short.

## Related Code

The implementation lives in `Sources/MacTile/WindowManager.swift`, specifically in the `setWindowFrame(_:frame:)` method of `RealWindowManager`.
