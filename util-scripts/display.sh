#!/bin/bash

echo "========== SETTING UP DISPLAY =========="

# Dynamically get the current directory of the script
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DISPLAY_CONFIG_FILE="$(dirname "$CURRENT_DIR")/config/display.conf"

# Read values from config file
source "$DISPLAY_CONFIG_FILE"

# Check if the display is connected and retrieve its name
DISPLAY_NAME=$(/usr/bin/python3 "${CURRENT_DIR}/gnome-randr.py" --current 2>/dev/null | awk '/associated physical monitors:/{getline; print $1; exit}')
if [ -z "$DISPLAY_NAME" ]; then
    echo "No display connected!"
    exit 1
fi

# Check available resolutions and rates
AVAILABLE_RESOLUTIONS=$(/usr/bin/python3 "${CURRENT_DIR}/gnome-randr.py" 2>/dev/null | awk -v display="$DISPLAY_NAME" 'flag && $1 ~ /^[0-9]+x[0-9]+/{print $1; next} $0 ~ display {flag=1; next} flag && $1 !~ /^[0-9]+x[0-9]+/{flag=0}')
AVAILABLE_RATES=$(/usr/bin/python3 "${CURRENT_DIR}/gnome-randr.py" 2>/dev/null | awk -v display="$DISPLAY_NAME" 'flag && $1 ~ /^[0-9]+x[0-9]+/{print $2; next} $0 ~ display {flag=1; next} flag && $1 !~ /^[0-9]+x[0-9]+/{flag=0}')

# Set the desired resolution and rate
if echo "$AVAILABLE_RESOLUTIONS" | grep -q "$PREFERRED_RESOLUTION"; then
    /usr/bin/python3 "${CURRENT_DIR}/gnome-randr.py" --output "$DISPLAY_NAME" --mode "$PREFERRED_RESOLUTION" --rate "$PREFERRED_RATE" --rotate "$ROTATE" --scale "$SCALE"
else
    # If the preferred resolution is not available, try an alternate one
    ALTERNATE_RESOLUTION="1920x1080"
    if echo "$AVAILABLE_RESOLUTIONS" | grep -q "$ALTERNATE_RESOLUTION"; then
        /usr/bin/python3 "${CURRENT_DIR}/gnome-randr.py" --output "$DISPLAY_NAME" --mode "$ALTERNATE_RESOLUTION" --rate "$PREFERRED_RATE" --rotate "$ROTATE" --scale 1
    else
        echo "No resolutions available!"
        exit 1
    fi
fi

echo "========== DISPLAY SETUP COMPLETE =========="
