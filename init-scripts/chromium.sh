#!/bin/bash

echo "========== SETTING UP CHROMIUM =========="

# Check if Chromium is upgradable
chromium_upgradable=$(apt list --upgradable 2>/dev/null | grep chromium-browser)

# If Chromium is not installed or it's upgradable
if ! command -v chromium-browser &> /dev/null || [ -n "$chromium_upgradable" ]; then
    echo "Installing/updating Chromium browser..."
    sudo apt-get install -y chromium-browser
    echo "Setting Chromium as the default browser..."
    xdg-settings set default-web-browser chromium-browser.desktop
    echo "Chromium is now the default browser!"
else
    echo "Chromium is already at the latest version!"
fi

echo "========== CHROMIUM SETUP COMPLETE =========="