#!/bin/bash

echo "========== SETTING UP CHROMIUM =========="

echo "Installing Chromium browser..."
sudo apt install -y chromium-browser
echo "Setting Chromium as the default browser..."
xdg-settings set default-web-browser chromium-browser.desktop
echo "Chromium is now the default browser!"

echo "========== CHROMIUM SETUP COMPLETE =========="