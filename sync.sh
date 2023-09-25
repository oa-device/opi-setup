#!/bin/bash

# Set default values
DEFAULT_USERNAME="orangepi"
DEFAULT_DEST_DIR="/home/orangepi/player"

# Ask for the remote device username
read -p "Enter remote device username (default: $DEFAULT_USERNAME): " USERNAME
USERNAME=${USERNAME:-$DEFAULT_USERNAME}

# Ask for the remote device IP
read -p "Enter remote device IP: " IP

# Determine the directory of the script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# If both username and IP are given, run the rsync command
if [ -n "$USERNAME" ] && [ -n "$IP" ]; then
    # Set the destination path
    DEST="$USERNAME@$IP:$DEFAULT_DEST_DIR"
    
    # Run the rsync command with --delete option and exclusions
    rsync -av -e ssh --progress \
    --delete \
    --exclude='.DS_Store' \
    --exclude='.git/' \
    --exclude='.gitignore' \
    --exclude='sync.sh' \
    --exclude='prod/' \
    --exclude='preprod/' \
    --exclude='staging/' \
    --exclude='logs/display_setup.log' \
    --exclude='logs/slideshow_log.log' \
    --exclude='logs/hide_cursor.log' \
    "$DIR/" "$DEST"
else
    echo "Both username and IP must be provided!"
    exit 1
fi
