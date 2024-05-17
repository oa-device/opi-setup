#!/bin/bash

echo "========== SETTING UP HIDE CURSOR =========="

# Check if unclutter is installed
if ! command -v unclutter &> /dev/null; then
    echo "Installing unclutter..."
    sudo apt-get install -y unclutter
    echo "unclutter installed!"
else
    echo "unclutter is already installed!"
fi

echo "========== HIDE CURSOR SETUP COMPLETE =========="