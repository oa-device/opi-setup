#!/bin/bash

# Get the directory of the current script's directory and the root directory
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
ROOT_DIR=$(dirname "$SCRIPT_DIR")

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

# Generate systemd service file
cat > "$ROOT_DIR/systemd/slideshow-player.service" << EOF
[Unit]
Description=Run slideshow-player at startup
After=graphical.target

[Service]
Type=simple
User=orangepi
Environment=DISPLAY=:0
ExecStartPre=/bin/sleep 5
ExecStart=$WORKING_DIR/dist/linux/slideshow-player
Restart=on-failure
RestartSec=5
StandardOutput=file:$ROOT_DIR/logs/slideshow_log.log
StandardError=file:$ROOT_DIR/logs/slideshow_log.log

[Install]
WantedBy=graphical.target
EOF

# Copy the service file to /etc/systemd/system/
sudo cp "$ROOT_DIR/systemd/slideshow-player.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable slideshow-player.service
sudo systemctl start slideshow-player.service
# Check and print the status of the service
service_status=$(sudo systemctl is-active slideshow-player.service)
echo "slideshow-player.service is $service_status"