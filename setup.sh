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

# Configure the on-screen keyboard settings
gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true

# Configure power settings to prevent screen dimming and blanking
gsettings set org.gnome.settings-daemon.plugins.power idle-dim false
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0

# Keep grdctl code commented as a reference
# grdctl rdp enable
# grdctl rdp set-credentials orangepi orangead
# grdctl rdp disable-view-only
# grdctl vnc enable
# grdctl vnc set-auth-method password
# grdctl vnc set-password orangead
# grdctl vnc disable-view-only
# grdctl status --show-credentials

# Check and clean for repeated keyring files
KEYRING_DIR="/home/orangepi/.local/share/keyrings"
print_section "CLEANING UP KEYRING FILES"
# Remove repeated keyring files
find "$KEYRING_DIR" -type f -name 'Default_keyring*.keyring' ! -name 'Default_keyring.keyring' -exec rm {} \;
# Log the final state of keyring files
echo "Current keyring files in the directory after cleanup:"
ls "$KEYRING_DIR" | grep 'Default_keyring*.keyring'

# Check and update keyring file for VNC settings
print_section "UPDATING KEYRING FILE FOR VNC SETTINGS"
KEYRING_FILE="$KEYRING_DIR/Default_keyring.keyring"
if [ -f "$KEYRING_FILE" ]; then
    # Determine whether an update is needed
    vnc_entry=$(grep "org.gnome.RemoteDesktop.VncPassword" "$KEYRING_FILE")

    if [[ -z "$vnc_entry" ]]; then
        # If the entry does not exist, add it
        new_index=$(( $(grep -oP "\[\K([0-9]+)(?=\])" "$KEYRING_FILE" | sort -nr | head -n1) + 1 ))
        echo -e "\n[${new_index}]\nitem-type=0\ndisplay-name=GNOME Remote Desktop VNC password\nsecret=orangead\n\n[${new_index}:attribute0]\nname=xdg:schema\ntype=string\nvalue=org.gnome.RemoteDesktop.VncPassword" >> "$KEYRING_FILE"
        echo "VNC entry added to the keyring file."
    elif ! grep -q "secret=orangead" <<< "$vnc_entry"; then
        # Update the existing entry if the secret is different
        vnc_block=$(grep -n "\[.*\]" "$KEYRING_FILE" | grep -B1 "org.gnome.RemoteDesktop.VncPassword" | head -1 | cut -d: -f1)
        sed -i "${vnc_block},${vnc_block_number:attribute0}/{s/secret=.*/secret=orangead/}" "$KEYRING_FILE"
        echo "VNC entry updated in the keyring file."
    else
        echo "VNC entry is already up-to-date in the keyring file."
    fi
else
    echo "Keyring file not found."
fi


# Check if gnome-remote-desktop is service running on port 5900 and start it if not
print_section "CONFIGURING GNOME REMOTE DESKTOP SERVICE"
systemctl --user start gnome-remote-desktop
systemctl --user status gnome-remote-desktop

# Enable VNC
print_section "CONFIGURING VNC"
grdctl vnc enable
grdctl vnc set-auth-method password
grdctl vnc disable-view-only
grdctl status --show-credentials

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

