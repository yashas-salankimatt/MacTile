#!/bin/bash

# MacTile Click Handler for Sketchybar
# Left-click: Restore a virtual space
# Right-click: Clear (unset) a virtual space

SPACE_NUM="$1"

if [ -z "$SPACE_NUM" ]; then
    echo "Usage: mactile_click.sh <space_number>"
    exit 1
fi

# Determine action based on BUTTON (provided by sketchybar)
# left = restore, right = clear
ACTION="restore"
if [ "$BUTTON" = "right" ]; then
    ACTION="clear"
fi

# Create a temporary Swift file to send notification to MacTile
TMPFILE=$(mktemp /tmp/mactile_click.XXXXXX.swift)

cat > "$TMPFILE" << 'SWIFTEOF'
import Foundation

let args = CommandLine.arguments
guard args.count > 2, let spaceNum = Int(args[1]) else {
    print("Usage: mactile_click <space_number> <action>")
    exit(1)
}

let action = args[2]
let notificationName: String

switch action {
case "clear":
    notificationName = "com.mactile.MacTile.clearSpace"
default:
    notificationName = "com.mactile.MacTile.restoreSpace"
}

let center = DistributedNotificationCenter.default()
let userInfo: [String: Any] = ["space": spaceNum]
center.postNotificationName(
    NSNotification.Name(notificationName),
    object: nil,
    userInfo: userInfo,
    deliverImmediately: true
)

// Give the notification time to be delivered
RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
SWIFTEOF

# Run the Swift script with space number and action
swift "$TMPFILE" "$SPACE_NUM" "$ACTION" 2>/dev/null

# Clean up
rm -f "$TMPFILE"
