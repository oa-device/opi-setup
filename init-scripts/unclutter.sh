#!/bin/bash

echo "========== SETTING UP HIDE CURSOR =========="

# Install unclutter
echo "Installing unclutter..."
sudo apt install -y unclutter

# Add lines to .bashrc if they don't exist
BASHRC="$HOME/.bashrc"

# Check for 'export DISPLAY=:0.0'
grep -qxF 'export DISPLAY=:0.0' "$BASHRC" || echo -e "\nexport DISPLAY=:0.0" >> "$BASHRC"
# Check for 'unclutter &'
grep -qxF 'unclutter &' "$BASHRC" || echo "unclutter &" >> "$BASHRC"

echo "========== HIDE CURSOR SETUP COMPLETE =========="