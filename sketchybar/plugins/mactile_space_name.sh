#!/bin/bash

# MacTile Space Name Plugin for Sketchybar
# Shows the name of the currently active virtual space
# Positioned between space indicators and front_app

# Get the active space name
SPACE_NAME="$MACTILE_SPACE_NAME"

# If no name is set, try to get it from the per-space variable
if [ -z "$SPACE_NAME" ] && [ -n "$MACTILE_SPACE" ] && [ "$MACTILE_SPACE" != "-1" ]; then
    SPACE_NAME_VAR="MACTILE_SPACE_${MACTILE_SPACE}_NAME"
    eval "SPACE_NAME=\"\${$SPACE_NAME_VAR}\""
fi

# If there's an active space with a name, show it
if [ -n "$SPACE_NAME" ] && [ "$MACTILE_SPACE" != "-1" ]; then
    sketchybar --set "$NAME" \
        label="$SPACE_NAME" \
        drawing=on
else
    # No active space or no name - hide this item
    sketchybar --set "$NAME" drawing=off
fi
