#!/bin/bash

# Initialize the current directory
CURRENT_DIR=$(dirname "$(readlink -f "$0")")

# Directories
LOGS_DIR="$CURRENT_DIR/logs"
mkdir -p "$LOGS_DIR"

# Function to print section headers for clarity
print_section() {
    echo -e "\n\e[1;33m========== $1 ==========\e[0m"
}

# Change the default password
print_section "CHANGING DEFAULT PASSWORD"
echo "orangepi:orangead" | sudo chpasswd

# Configure timezone settings
print_section "SETTING TIMEZONE TO MONTREAL"
sudo timedatectl set-timezone America/Montreal
echo "Current timezone set to: $(timedatectl | grep "Time zone" | awk '{print $3}')"

# Execute the display configuration script
print_section "CONFIGURING DISPLAY"
"$CURRENT_DIR/util-scripts/display.sh"

# Configure the wifi
print_section "CONFIGURING WIFI"
"$CURRENT_DIR/util-scripts/wifi.sh"

# Schedule a daily reboot via crontab
print_section "SETTING UP DAILY REBOOT AT 3AM"
echo "0 3 * * * /sbin/reboot" | crontab -
crontab -l

# Setup systemd services (excluding slideshow-player.service)
print_section "SETTING UP SYSTEMD SERVICES"
for service in "$CURRENT_DIR"/systemd/*.service; do
    if [ -f "$service" ]; then
        service_name=$(basename "$service")
        
        if [ "$service_name" != "slideshow-player.service" ]; then
            sudo cp "$service" /etc/systemd/system/
            sudo systemctl enable "$service_name"
            sudo systemctl start "$service_name"
            echo "$service_name is $(sudo systemctl is-active "$service_name")"
        else
            echo "Skipping $service_name"
        fi
    fi
done

# Configure GNOME settings
print_section "CONFIGURING GNOME SETTINGS"

# Disable the Update Notifier
gsettings set com.ubuntu.update-notifier no-show-notifications true

# Disable Bluetooth by default
rfkill block bluetooth
gsettings set org.blueman.plugins.powermanager auto-power-on false
bluetooth_status=$(rfkill list bluetooth | grep -c "Soft blocked: yes")
[ "$bluetooth_status" -gt 0 ] && echo "Bluetooth is off" || echo "Bluetooth is on"

# TODO: Enable Remote Desktop and VNC
# grdctl rdp enable
# grdctl rdp set-credentials orangepi orangead
# grdctl rdp disable-view-only
# grdctl vnc enable
# grdctl vnc set-auth-method password
# grdctl vnc set-password orangead
# grdctl vnc disable-view-only
# grdctl status --show-credentials

# Configure the on-screen keyboard settings
gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true

# Configure power settings to prevent screen dimming and blanking
gsettings set org.gnome.settings-daemon.plugins.power idle-dim false
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0

# Update and Upgrade system packages
print_section "UPDATING SYSTEM"
sudo apt update
sudo apt upgrade --fix-missing -y

# Execute initialization scripts from the init-scripts directory
print_section "RUNNING INIT SCRIPTS"
for script in "$CURRENT_DIR"/init-scripts/*.sh; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        echo "Executing $script..."
        "$script"
    fi
done

print_section "SETUP COMPLETED"

