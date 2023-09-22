#!/bin/bash

echo "========== SETTING UP BACKGROUND IMAGES =========="

# Determine current directory dynamically
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Copy all .jpg images to the Pictures folder
find "$CURRENT_DIR" -maxdepth 1 -type f -iname "*.jpg" -exec cp {} "$HOME/Pictures/" \;

# Get the first .jpg image found in the Pictures folder for setting as background
BACKGROUND_IMAGE=$(find "$HOME/Pictures" -maxdepth 1 -type f -iname "*.jpg" | head -n 1)

if [[ -z "$BACKGROUND_IMAGE" ]]; then
    echo "No .jpg images found in the Pictures directory!"
    exit 1
else
    echo "Setting $BACKGROUND_IMAGE as the desktop background..."
    
    # Set the image as the background
    gsettings set org.gnome.desktop.background picture-uri "file://${BACKGROUND_IMAGE}"
    
    if [[ $? -eq 0 ]]; then
        echo "Background successfully updated!"
    else
        echo "There was an error setting the background image."
    fi
fi

echo "========== BACKGROUND IMAGES SETUP COMPLETE =========="
