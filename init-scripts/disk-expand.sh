#!/bin/bash

echo "---------- EXPANDING FILESYSTEM ----------"

# Check if cloud-guest-utils is installed
if ! dpkg -l | grep -q cloud-guest-utils; then
    echo "Installing cloud-guest-utils..."
    sudo apt-get install -y cloud-guest-utils
fi

# Check if the filesystem is already expanded
if df -h | grep -q '/dev/mmcblk0p2'; then
    filesystem_size=$(df -h | grep '/dev/mmcblk0p2' | awk '{print $2}')
    filesystem_used=$(df -h | grep '/dev/mmcblk0p2' | awk '{print $3}')
    if [ "$filesystem_size" = "$filesystem_used" ]; then
        echo "Expanding filesystem..."
        sudo growpart /dev/mmcblk0 2
        sudo resize2fs /dev/mmcblk0p2
        echo "Filesystem expanded!"
    else
        echo "Filesystem is already expanded!"
    fi
else
    echo "Filesystem /dev/mmcblk0p2 does not exist!"
fi

echo "---------- FILESYSTEM EXPAND COMPLETE ----------"
