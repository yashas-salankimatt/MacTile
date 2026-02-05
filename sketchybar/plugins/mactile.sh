#!/bin/bash

# MacTile Virtual Space Plugin for Sketchybar
# This script handles mactile_space_change events and updates the bar
# Shows app icons for spaces, hides empty spaces

# Try to load icon_map.sh for app icons (from sketchybar-app-font)
# If not available, we'll fall back to showing app names
ICON_MAP_LOADED=false
if [ -f "$HOME/.config/sketchybar/helpers/icon_map.sh" ]; then
    source "$HOME/.config/sketchybar/helpers/icon_map.sh"
    ICON_MAP_LOADED=true
fi

# Colors
ACTIVE_COLOR="0xffffffff"      # White - active space number
INACTIVE_COLOR="0xff888888"    # Gray - inactive space number
ACTIVE_ICON_COLOR="0xffffffff" # White - active space app icons
INACTIVE_ICON_COLOR="0xffcccccc" # Light gray - inactive space app icons
ACTIVE_BG="0x40ffffff"         # Semi-transparent white background
INACTIVE_BG="0x00000000"       # Transparent background

# Pill (label background) colors
ACTIVE_PILL="0x50ffffff"       # Semi-transparent white pill for active
INACTIVE_PILL="0x60494d64"     # More visible dark pill for inactive

# Get the space number from the item name (e.g., "mactile.space.1" -> "1")
SPACE_NUM="${NAME##*.}"

# Build app icons string from app names
get_app_icons() {
    local app_names="$1"
    local icons=""

    if [ -z "$app_names" ]; then
        echo ""
        return
    fi

    # Split by comma and get icon for each app
    IFS=',' read -ra APPS <<< "$app_names"
    for app in "${APPS[@]}"; do
        # Trim whitespace
        app=$(echo "$app" | xargs)
        if [ -n "$app" ]; then
            if [ "$ICON_MAP_LOADED" = true ]; then
                # Get icon from icon_map
                __icon_map "$app"
                if [ -n "$icon_result" ] && [ "$icon_result" != ":default:" ]; then
                    icons="${icons}${icon_result} "
                else
                    # Use default icon for unknown apps
                    icons="${icons}:default: "
                fi
            else
                # No icon map - just use first letter of app name
                icons="${icons}${app:0:1} "
            fi
        fi
    done

    # Trim trailing space
    echo "${icons% }"
}

# Get app names for THIS space from the per-space environment variable
# MacTile sends MACTILE_SPACE_N_APPS for each saved space
# Use eval to handle indirect variable access
SPACE_APPS_VAR="MACTILE_SPACE_${SPACE_NUM}_APPS"
eval "SPACE_APP_NAMES=\"\${$SPACE_APPS_VAR}\""

# Get app icons for this space
APP_ICONS=$(get_app_icons "$SPACE_APP_NAMES")

# If this space has no apps, hide it
if [ -z "$SPACE_APP_NAMES" ]; then
    sketchybar --set "$NAME" drawing=off
    exit 0
fi

# Space has apps - show it
sketchybar --set "$NAME" drawing=on

# Check if this is the active space
if [ "$MACTILE_SPACE" = "$SPACE_NUM" ]; then
    # This space is active
    if [ -n "$APP_ICONS" ]; then
        sketchybar --set "$NAME" \
            icon="$SPACE_NUM" \
            icon.color="$ACTIVE_COLOR" \
            background.color="$ACTIVE_BG" \
            label="$APP_ICONS" \
            label.color="$ACTIVE_ICON_COLOR" \
            label.background.color="$ACTIVE_PILL" \
            label.drawing=on
    else
        sketchybar --set "$NAME" \
            icon="$SPACE_NUM" \
            icon.color="$ACTIVE_COLOR" \
            background.color="$ACTIVE_BG" \
            label.drawing=off
    fi
else
    # This space is inactive - still show app icons if this space has apps
    if [ -n "$APP_ICONS" ]; then
        sketchybar --set "$NAME" \
            icon="$SPACE_NUM" \
            icon.color="$INACTIVE_COLOR" \
            background.color="$INACTIVE_BG" \
            label="$APP_ICONS" \
            label.color="$INACTIVE_ICON_COLOR" \
            label.background.color="$INACTIVE_PILL" \
            label.drawing=on
    else
        sketchybar --set "$NAME" \
            icon="$SPACE_NUM" \
            icon.color="$INACTIVE_COLOR" \
            background.color="$INACTIVE_BG" \
            label.drawing=off
    fi
fi
