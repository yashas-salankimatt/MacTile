#!/bin/bash

# Front App Plugin for Sketchybar
# Shows the name of the currently focused application

if [ "$SENDER" = "front_app_switched" ]; then
    sketchybar --set "$NAME" label="$INFO"
fi
