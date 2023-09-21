#!/bin/bash

# Get the current directory
CURRENT_DIR=$(dirname "$(readlink -f "$0")")

# Create logs directory if it doesn't exist
LOGS_DIR="$CURRENT_DIR/logs"
mkdir -p "$LOGS_DIR"

# Change default password
echo "orangepi:orangead" | sudo chpasswd

# Set timezone to Montreal
echo "========== SETTING TIMEZONE TO MONTREAL =========="
sudo timedatectl set-timezone America/Montreal
# Check current timezone
echo "Current timezone set to: $(timedatectl | grep "Time zone" | awk '{print $3}')"
echo "========== TIMEZONE SETTING COMPLETE =========="

# Update and Upgrade
echo "========== UPDATING SYSTEM =========="
sudo apt update
sudo apt upgrade -y
echo "========== SYSTEM UPDATE COMPLETE =========="

# Loop through each script in the init folder and execute it
for script in "$CURRENT_DIR"/init-scripts/*.sh; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        echo "Running $script"
        "$script"
        echo "Finished running $script"
    fi
done

# Run display.sh in the util-scripts folder
"$CURRENT_DIR/util-scripts/display.sh"

# Handle crontab for rebooting the system every day at 3am
echo "========== SETTING UP CRONTAB =========="
echo "0 3 * * * /sbin/reboot" | crontab -
echo "Current crontab entries:"
crontab -l
echo "========== CRONTAB SETUP COMPLETE =========="

# Handle systemd services other than `slideshow-player.service`
echo "========== SETTING UP SYSTEMD SERVICES =========="
for service in "$CURRENT_DIR"/systemd/*.service; do
    if [ -f "$service" ]; then
        # Get the base name of the service file
        service_name=$(basename "$service")
        
        # Skip processing if the service is slideshow-player.service
        if [ "$service_name" != "slideshow-player.service" ]; then
            # Copy the service file to /etc/systemd/system/
            sudo cp "$service" /etc/systemd/system/
            # Enable and start the service
            sudo systemctl enable "$service_name"
            sudo systemctl start "$service_name"
            
            # Check and print the status of the service
            service_status=$(sudo systemctl is-active "$service_name")
            echo "$service_name is $service_status"
        else
            echo "Skipping $service_name"
        fi
    fi
done
echo "========== SYSTEMD SERVICES SETUP COMPLETE =========="

# Handle GNOME settings
echo "========== SETTING UP GSETTINGS =========="
# Turn off Bluetooth by default
rfkill block bluetooth
gsettings set org.blueman.plugins.powermanager auto-power-on false
# Check if Bluetooth is off
bluetooth_status=$(rfkill list bluetooth | grep -c "Soft blocked: yes")
if [ "$bluetooth_status" -gt 0 ]; then
    echo "Bluetooth is off"
else
    echo "Bluetooth is on"
fi

# Enable Remote Desktop (TODO)

# Setting up Screen Keyboard
gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true

# Power control: Disable Dim Screen, set Screen Blank to Never
gsettings set org.gnome.settings-daemon.plugins.power idle-dim false
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
echo "========== GSETTINGS SETUP COMPLETE =========="

# Setup sudo crontab to disable USB cameras on boot, to prevent the camera from being used in chromium
# echo "========== SETTING UP SUDO CRONTAB =========="
# echo "@reboot sleep 3 && /bin/chmod 000 /dev/video0 && /bin/chmod 000 /dev/video1" | sudo crontab -
# echo "Current sudo crontab entries:"
# sudo crontab -l
# echo "========== SUDO CRONTAB SETUP COMPLETE =========="

echo
echo "Setup completed!"
