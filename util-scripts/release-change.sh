#!/bin/bash

# Get the directory of the current script's directory and the root directory
UTIL_SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
ROOT_DIR=$(dirname "$UTIL_SCRIPT_DIR")

# Get the choice as an argument, or ask the user if not provided
if [ -z "$1" ]; then
    echo "Which directory do you want to use?"
    echo "1. Production"
    echo "2. Pre-production"
    echo "3. Staging"
    read -p "Enter your choice (1-3): " choice
else
    choice="$1"
fi

# Compute the WORKING_DIR based on the choice.
if [[ $choice == 1 ]]; then
    WORKING_DIR="$ROOT_DIR/prod"
    elif [[ $choice == 2 ]]; then
    WORKING_DIR="$ROOT_DIR/preprod"
    elif [[ $choice == 3 ]]; then
    WORKING_DIR="$ROOT_DIR/staging"
else
    echo "Invalid choice. Exiting."
    exit 1
fi

# Copy the service files to /etc/systemd/system/ and manage their states
sudo cp "$ROOT_DIR/systemd/slideshow-player.service" /etc/systemd/system/
sudo cp "$ROOT_DIR/systemd/chromium-log-monitor.service" /etc/systemd/system/

# Replace the loaded slideshow-player.service with the chosen release
sudo sed -i "s|ExecStart=.*|ExecStart=$WORKING_DIR/dist/linux/slideshow-player|" /etc/systemd/system/slideshow-player.service

sudo systemctl daemon-reload
sudo systemctl disable slideshow-player.service
sudo systemctl disable chromium-log-monitor.service
sudo systemctl enable slideshow-player.service
sudo systemctl enable chromium-log-monitor.service
sudo systemctl restart slideshow-player.service

# Check and print the status of the services
slideshow_status=$(sudo systemctl is-active slideshow-player.service)
chromium_log_status=$(sudo systemctl is-active chromium-log-monitor.service)
echo "slideshow-player.service is $slideshow_status"
echo "chromium-log-monitor.service is $chromium_log_status"
