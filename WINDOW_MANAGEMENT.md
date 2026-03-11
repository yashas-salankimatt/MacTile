# Window Management: Technical Deep Dive

MacTile's window management system solves significant challenges with the macOS Accessibility API. This document details the key insights and algorithms that make reliable window tiling possible.

## The Core Challenge

Unlike GNOME (where gTile operates), macOS's Accessibility API is **asynchronous**. When you call `AXUIElementSetAttributeValue` to set a window's size or position, the call returns immediately but the window may not reach the target state for several milliseconds—or may never reach it due to application constraints.

This creates several problems:
1. **Position-size coupling**: Many apps (especially browsers) move the window when you resize it, and vice versa
2. **Minimum constraints**: Apps may enforce minimum window sizes that differ from our target
3. **Cross-monitor resistance**: Browsers refuse to move large windows "mostly off-screen", blocking cross-monitor moves
4. **Animations**: macOS animates window transitions, causing visual lag and timing issues

## Approach: AeroSpace-Inspired Positioning

After analyzing [AeroSpace](https://github.com/nikitabobko/AeroSpace) (a macOS tiling window manager), MacTile adopted several key techniques that eliminate most delays and produce near-instant window positioning.

### 1. Animation Disabling via AXEnhancedUserInterface

The single biggest performance improvement. Before any frame changes, MacTile temporarily sets the undocumented `AXEnhancedUserInterface` attribute to `false` on the target application, then restores it via `defer` after positioning completes. This suppresses macOS window animations during move/resize operations, producing instant visual feedback.

This technique is used by AeroSpace, yabai, and Rectangle.

### 2. Size → Position → Size Order

AeroSpace discovered (issues [#143](https://github.com/nikitabobko/AeroSpace/issues/143), [#335](https://github.com/nikitabobko/AeroSpace/issues/335)) that setting attributes in the order **Size → Position → Size** handles macOS AX quirks where setting one attribute affects the other. This single three-call sequence replaces the previous multi-step safe-zone strategy and iterative correction loops in most cases.

### 3. Fire-and-Forget AX Calls

AX calls are serialized per-app at the accessibility server level, so calls issued back-to-back are processed in order without needing explicit delays. MacTile issues all AX calls with zero `usleep` delays between them, matching AeroSpace's approach.

### 4. Cross-Monitor Shrink Strategy

For cross-monitor moves, browsers and some apps refuse to move large windows across monitor boundaries (they resist being "mostly off-screen"). MacTile handles this by:

1. **Shrink** the window to a small intermediate size (≤400×300, or the target size if smaller)
2. **Move** the small window to the target position on the other monitor
3. **Apply Size → Position → Size** for final placement

This adds a small overhead for cross-monitor moves but ensures reliability with stubborn apps.

## The Algorithm

```
setAXWindowFrame(window, targetFrame):
    1. DISABLE ANIMATIONS
       - Read AXEnhancedUserInterface from the app element
       - Set to false if it was true
       - defer: restore original value

    2. DETECT CROSS-MONITOR MOVE
       - Find which screen contains the window's center
       - Find which screen contains the target's center
       - Compare screens

    3. POSITION WINDOW
       If cross-monitor:
           - Shrink to min(400, targetWidth) × min(300, targetHeight)
           - Move to target position (small window moves freely)
           - Size → Position → Size for final placement
       If same-screen:
           - Size → Position → Size (direct)

    4. VERIFY
       - Read back window state immediately
       - If position and size are within tolerance (±10px) → success
       - If size exceeds target → check if minimum constraint → accept

    5. CORRECTION LOOP (safety net, rarely needed)
       - Up to 10 attempts with delays between AX calls
       - Apply Size → Position → Size each iteration
       - Detect stuck state (3+ consecutive identical readings)
       - Detect minimum constraints vs. intermediate states
       - Bail out if AX reads return zero-size (window closed)
```

## Minimum Constraint Detection

Some applications enforce minimum window sizes. Detecting this correctly is crucial:

- **Wrong approach**: Accept "size exceeds target" on first attempt as minimum constraint
- **Problem**: Intermediate resize states can temporarily exceed target in one dimension while being short in another
- **Correct approach**: Only detect minimum constraint after 3+ consecutive attempts with **no state change at all**

The key insight: if we're truly at a minimum constraint, the window state will be completely stable (not changing at all), and the size will exceed the target without falling short in any dimension.

## Tolerance-Based Success

Pixel-perfect positioning is neither possible nor necessary:
- **±10 pixels** is acceptable for both position and size
- This accounts for window chrome variations and system-level adjustments

## Why This Works

1. **Animation disabling eliminates visual lag**: No smooth transitions means the window appears at its target instantly
2. **S→P→S handles attribute coupling**: The double size-set corrects for position changes affecting size
3. **AX serialization guarantees order**: Calls are processed sequentially per-app without needing explicit delays
4. **Cross-monitor shrink bypasses visibility protection**: Small windows move freely across monitor boundaries
5. **Correction loop catches edge cases**: Acts as a safety net for apps that don't respond to the fast path
6. **Conservative minimum detection**: Only accepts constraints after confirming the window is truly stuck

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

The implementation lives in `Sources/MacTile/WindowManager.swift`, specifically in the `setAXWindowFrame(_:frame:)` method of `RealWindowManager`.
