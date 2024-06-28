#!/bin/bash

echo "---------- SETTING UP CHROMIUM ----------"

# Function to install or update Chromium
install_or_update_chromium() {
    echo "Installing/updating Chromium browser..."
    sudo apt-get install -y chromium-browser
    echo "Setting Chromium as the default browser..."
    xdg-settings set default-web-browser chromium-browser.desktop
    echo "Chromium is now the default browser!"
}

# Function to check if Chromium is installed
is_chromium_installed() {
    command -v chromium-browser &>/dev/null
}

# Function to check if Chromium is upgradable
is_chromium_upgradable() {
    apt list --upgradable 2>/dev/null | grep -q chromium-browser
}

# Main logic
if is_chromium_installed; then
    if is_chromium_upgradable; then
        install_or_update_chromium
    else
        echo "Chromium is already at the latest version!"
    fi
else
    install_or_update_chromium
fi

echo "---------- CHROMIUM SETUP COMPLETE ----------"
