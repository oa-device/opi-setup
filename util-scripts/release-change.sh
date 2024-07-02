#!/bin/bash

source "$(dirname "$(readlink -f "$0")")/../helpers.sh" || {
    echo "Error: Could not source helpers.sh"
    exit 1
}

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
case "$choice" in
1) WORKING_DIR="$PLAYER_ROOT_DIR/prod" ;;
2) WORKING_DIR="$PLAYER_ROOT_DIR/preprod" ;;
3) WORKING_DIR="$PLAYER_ROOT_DIR/staging" ;;
*)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac

# Ensure the service files exist before copying
if [ ! -f "$PLAYER_SYSTEMD_DIR/slideshow-player.service" ] || [ ! -f "$PLAYER_SYSTEMD_DIR/chromium-log-monitor.service" ]; then
    echo "Error: One or more service files do not exist in $PLAYER_SYSTEMD_DIR"
    exit 1
fi

# Copy the service files to /etc/systemd/system/ and manage their states
sudo cp "$PLAYER_SYSTEMD_DIR/slideshow-player.service" /etc/systemd/system/
sudo cp "$PLAYER_SYSTEMD_DIR/chromium-log-monitor.service" /etc/systemd/system/

# Replace placeholders in the service files
replace_placeholders "/etc/systemd/system/slideshow-player.service"
replace_placeholders "/etc/systemd/system/chromium-log-monitor.service"

# Replace the loaded slideshow-player.service with the chosen release
sudo sed -i "s|ExecStart=.*|ExecStart=$WORKING_DIR/dist/linux/slideshow-player|" /etc/systemd/system/slideshow-player.service

sudo systemctl daemon-reload
sudo systemctl disable slideshow-player.service
sudo systemctl disable chromium-log-monitor.service
sudo systemctl enable slideshow-player.service
sudo systemctl enable chromium-log-monitor.service
sudo systemctl restart slideshow-player.service

# Print the status of the services
print_service_status "slideshow-player.service"
print_service_status "chromium-log-monitor.service"
