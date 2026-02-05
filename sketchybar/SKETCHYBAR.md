# MacTile Sketchybar Integration

MacTile can integrate with [sketchybar](https://github.com/FelixKratz/SketchyBar) to display virtual space indicators in your menu bar.

## Enabling Integration

1. Open MacTile Settings (click menu bar icon → Settings, or use the settings shortcut)
2. Go to the "Virtual Spaces" tab
3. Check "Enable Sketchybar Integration"

### What Happens Automatically

When you enable the integration, MacTile will:

1. **Deploy plugin scripts** to `~/.config/sketchybar/plugins/`:
   - `mactile.sh` - Main space indicator script
   - `mactile_click.sh` - Click handler for restore/clear
   - `mactile_space_name.sh` - Active space name display

2. **Deploy helper scripts** to `~/.config/sketchybar/helpers/`:
   - `icon_map.sh` - App name to icon mapping (from sketchybar-app-font)

3. **Install the sketchybar-app-font** to `~/Library/Fonts/`:
   - `sketchybar-app-font.ttf` - Font with app icon ligatures
   - Only installed if not already present

4. **Check your sketchybarrc**:
   - If no `sketchybarrc` exists, MacTile deploys a complete working template
   - If one exists but isn't configured for MacTile, you'll see a dialog with instructions

5. **Restart sketchybar** via `brew services restart sketchybar`

### If Your sketchybarrc Already Exists

If you have an existing sketchybar configuration, MacTile will detect that it's not configured for MacTile and show a dialog. You'll need to manually add the MacTile sections to your config. An example config is placed at:

```
~/.config/sketchybar/sketchybarrc.mactile-example
```

Copy the relevant sections from this file into your existing `sketchybarrc`.

## How It Works

When enabled, MacTile triggers a custom sketchybar event (`mactile_space_change`) whenever:
- A virtual space is saved
- A virtual space is restored
- A virtual space becomes active/inactive
- A virtual space is cleared

MacTile automatically finds sketchybar in these locations:
- `/opt/homebrew/bin/sketchybar` (Homebrew on Apple Silicon)
- `/usr/local/bin/sketchybar` (Homebrew on Intel)
- `/run/current-system/sw/bin/sketchybar` (NixOS)
- Falls back to `which sketchybar` if not found in common paths

## Event and Environment Variables

MacTile triggers: `sketchybar --trigger mactile_space_change <variables>`

### Variables Passed

| Variable | Description | Example |
|----------|-------------|---------|
| `MACTILE_SPACE` | The space number that triggered the event (0-9), or -1 if no specific space | `3` |
| `MACTILE_SPACE_NAME` | Name of the triggered space (if set) | `"Code"` |
| `MACTILE_MONITOR` | Display ID of the monitor | `1` |
| `MACTILE_ACTION` | Action type (see below) | `"save"` |
| `MACTILE_APPS` | Comma-separated bundle IDs of apps in the space | `"com.apple.Safari,com.googlecode.iterm2"` |
| `MACTILE_APP_NAMES` | Comma-separated display names of apps | `"Safari,iTerm2"` |
| `MACTILE_APP_COUNT` | Number of unique apps in the space | `2` |

### Per-Space Variables

For each saved (non-empty) space, MacTile also sends:

| Variable | Description |
|----------|-------------|
| `MACTILE_SPACE_<N>_APPS` | App names for space N |
| `MACTILE_SPACE_<N>_NAME` | Custom name for space N |

This allows your scripts to render all spaces, not just the one that triggered the event.

### Action Types

| Action | When Triggered |
|--------|----------------|
| `save` | User saves a virtual space |
| `restore` | User restores a virtual space |
| `activate` | A space becomes active (windows match saved state) |
| `deactivate` | A space becomes inactive (windows changed) |
| `clear` | User clears/unsets a virtual space |

## Sketchybar Configuration

### Register the Event

In your `sketchybarrc`, register the MacTile event:

```bash
sketchybar --add event mactile_space_change
```

### Example: Space Indicators

Add items for each virtual space (0-9):

```bash
MACTILE_SPACES=(0 1 2 3 4 5 6 7 8 9)

for i in "${!MACTILE_SPACES[@]}"
do
  sid="${MACTILE_SPACES[i]}"
  sketchybar --add item mactile.space."$sid" left \
             --set mactile.space."$sid" \
                   updates=on \
                   icon="$sid" \
                   drawing=off \
                   script="$PLUGIN_DIR/mactile.sh" \
                   click_script="$PLUGIN_DIR/mactile_click.sh $sid" \
             --subscribe mactile.space."$sid" mactile_space_change
done
```

**Important:** Use `updates=on` (not `updates=when_shown`) so scripts run even for initially hidden items.

### Example: Space Name Display

Show the active space's name near the front app indicator:

```bash
sketchybar --add item mactile.space_name left \
           --set mactile.space_name \
                 updates=on \
                 drawing=off \
                 label.font="Hack Nerd Font:Bold:11.0" \
                 label.color=0xff888888 \
                 script="$PLUGIN_DIR/mactile_space_name.sh" \
           --subscribe mactile.space_name mactile_space_change
```

## Example Plugin Scripts

### mactile.sh - Space Indicator Script

This script updates individual space indicators with app icons:

```bash
#!/bin/bash

# Get the space number from the item name (e.g., "mactile.space.1" -> "1")
SPACE_NUM="${NAME##*.}"

# Get app names for THIS space using indirect variable expansion
SPACE_APPS_VAR="MACTILE_SPACE_${SPACE_NUM}_APPS"
eval "SPACE_APP_NAMES=\"\${$SPACE_APPS_VAR}\""

# If this space has no apps, hide it
if [ -z "$SPACE_APP_NAMES" ]; then
    sketchybar --set "$NAME" drawing=off
    exit 0
fi

# Space has apps - show it with appropriate styling
sketchybar --set "$NAME" drawing=on

# Check if this is the active space
if [ "$MACTILE_SPACE" = "$SPACE_NUM" ]; then
    # Active styling
    sketchybar --set "$NAME" \
        icon="$SPACE_NUM" \
        icon.color="0xffffffff" \
        background.color="0x40ffffff"
else
    # Inactive styling
    sketchybar --set "$NAME" \
        icon="$SPACE_NUM" \
        icon.color="0xff888888" \
        background.color="0x00000000"
fi
```

### mactile_space_name.sh - Active Space Name Script

```bash
#!/bin/bash

# Get the active space name
SPACE_NAME="$MACTILE_SPACE_NAME"

# Fallback: get from per-space variable
if [ -z "$SPACE_NAME" ] && [ -n "$MACTILE_SPACE" ]; then
    SPACE_NAME_VAR="MACTILE_SPACE_${MACTILE_SPACE}_NAME"
    eval "SPACE_NAME=\"\${$SPACE_NAME_VAR}\""
fi

# Show if there's an active space with a name
if [ -n "$SPACE_NAME" ] && [ "$MACTILE_SPACE" != "-1" ]; then
    sketchybar --set "$NAME" label="$SPACE_NAME" drawing=on
else
    sketchybar --set "$NAME" drawing=off
fi
```

### mactile_click.sh - Click Handler Script

Enable clicking on space indicators to restore/clear spaces:

```bash
#!/bin/bash

# Left-click: Restore, Right-click: Clear
SPACE_NUM="$1"
ACTION="restore"
[ "$BUTTON" = "right" ] && ACTION="clear"

# Send notification to MacTile via NSDistributedNotificationCenter
# (Uses a small Swift script to post the notification)
```

The click handler uses `NSDistributedNotificationCenter` to communicate back to MacTile:
- `com.mactile.MacTile.restoreSpace` - Restore a space
- `com.mactile.MacTile.clearSpace` - Clear a space

## App Icons with sketchybar-app-font

For app icons, use [sketchybar-app-font](https://github.com/kvndrsslr/sketchybar-app-font) which provides ligature-based icons.

1. Install the font
2. Set your label font to the app font
3. Use the `icon_map.sh` helper to convert app names to icon ligatures

Example in your mactile.sh:
```bash
source "$HOME/.config/sketchybar/helpers/icon_map.sh"

# Convert app name to icon
__icon_map "Safari"
echo "$icon_result"  # Outputs the Safari icon ligature
```

## IPC: Sketchybar → MacTile

MacTile listens for distributed notifications, allowing sketchybar (or any app) to trigger space restore/clear actions:

```swift
// Notification names
"com.mactile.MacTile.restoreSpace"  // Restore a space
"com.mactile.MacTile.clearSpace"    // Clear a space

// UserInfo dictionary
["space": Int]  // The space number (0-9)
```

These notifications are only processed when sketchybar integration is enabled in MacTile settings.

## Troubleshooting

### Indicators not showing
1. Ensure `updates=on` is set on your items (not `updates=when_shown`)
2. Check that items start with `drawing=off` - scripts will enable drawing when spaces have content
3. Verify the event is registered: `sketchybar --query mactile.space.0`

### Variables not accessible in scripts
Sketchybar passes event variables to scripts. Use `eval` for indirect variable access:
```bash
# This won't work:
echo "${!MACTILE_SPACE_1_APPS}"

# This works:
VAR="MACTILE_SPACE_1_APPS"
eval "VALUE=\"\${$VAR}\""
```

### Debug logging
Add debug output to your scripts:
```bash
echo "$(date): $NAME called" >> /tmp/mactile_debug.log
env | grep MACTILE >> /tmp/mactile_debug.log
```

## Custom Commands

For advanced users, MacTile supports custom sketchybar commands. Instead of the default trigger, MacTile will run your command with environment variables set:

- `MACTILE_SPACE`, `MACTILE_SPACE_NAME`, `MACTILE_MONITOR`, `MACTILE_ACTION`
- `MACTILE_APPS`, `MACTILE_APP_NAMES`, `MACTILE_APP_COUNT`
- `MACTILE_SPACE_<N>_APPS`, `MACTILE_SPACE_<N>_NAME` for all saved spaces

Configure in Settings → Virtual Spaces → Custom Sketchybar Command.
