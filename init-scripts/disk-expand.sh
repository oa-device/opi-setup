#!/bin/bash

echo "========== EXPANDING FILESYSTEM =========="

echo "Installing cloud-guest-utils..."
sudo apt-get install -y cloud-guest-utils
echo "Expanding filesystem..."
sudo growpart /dev/mmcblk0 2
sudo resize2fs /dev/mmcblk0p2
echo "Filesystem expanded!"

echo "========== FILESYSTEM EXPAND COMPLETE =========="