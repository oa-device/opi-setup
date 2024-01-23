#!/bin/bash

# Set default values
DEFAULT_USERNAME="orangepi"
DEFAULT_DEST_DIR="/home/orangepi/player"

# If command-line arguments are provided, use them. Otherwise, ask for input.
if [ -n "$1" ]; then
    USERNAME=$1
else
    read -p "Enter remote device username (default: $DEFAULT_USERNAME): " USERNAME
    USERNAME=${USERNAME:-$DEFAULT_USERNAME}
fi

if [ -n "$2" ]; then
    IP=$2
else
    read -p "Enter remote device IP: " IP
fi

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
    --exclude='dev.sh' \
    --exclude='prod/' \
    --exclude='preprod/' \
    --exclude='staging/' \
    --exclude='logs/*' \
    --include='logs/.placeholder' \
    "$DIR/" "$DEST"
else
    echo "Both username and IP must be provided!"
    exit 1
fi
