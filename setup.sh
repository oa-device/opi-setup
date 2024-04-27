#!/bin/bash

# Initialize the current directory
ROOT_DIR=$(dirname "$(readlink -f "$0")")

# Directories
LOGS_DIR="$ROOT_DIR/logs"
mkdir -p "$LOGS_DIR"

# Function to print section headers for clarity
print_section() {
    echo -e "\n\e[1;33m========== $1 ==========\e[0m"
}


print_section "CONFIGURE SUDO RIGHTS FOR ORANGEPI USER"
BINARIES=(
    "/usr/bin/apt"
    "/usr/bin/apt-get"
    "/usr/bin/cp"
    "/usr/bin/growpart"
    "/usr/bin/mkdir"
    "/usr/bin/mv"
    "/usr/bin/nano"
    "/usr/bin/rm"
    "/usr/bin/sed"
    "/usr/bin/systemctl"
    "/usr/bin/tee"
    "/usr/bin/timedatectl"
    "/usr/sbin/chpasswd"
    "/usr/sbin/reboot"
    "/usr/sbin/resize2fs"
)
SUDO_RIGHTS="orangepi ALL=(ALL) NOPASSWD: ${BINARIES[0]}"
for binary in "${BINARIES[@]:1}"; do
    SUDO_RIGHTS+=", $binary"
done
if [ -z "$(cat /etc/sudoers.d/orangepi 2>/dev/null)" ]; then
    echo "Sudo rights not yet configured for orangepi user. Configuring..."
    echo $SUDO_RIGHTS | sudo tee /etc/sudoers.d/orangepi > /dev/null
    echo "Sudo rights granted for orangepi user."
elif [ "$(cat /etc/sudoers.d/orangepi)" != "$SUDO_RIGHTS" ]; then
    echo "Updating sudo rights for orangepi user..."
    sudo mv /etc/sudoers.d/orangepi /home/orangepi/orangepi_sudo.bak
    echo $SUDO_RIGHTS | sudo tee /etc/sudoers.d/orangepi > /dev/null
    echo "Sudo rights updated for orangepi user."
else
    echo "Sudo rights already configured for orangepi user."
fi


print_section "CONFIGURING ALIASES"
if ! grep -Fxq 'export PATH="$PATH:/home/orangepi/player/util-scripts"' ~/.bashrc
then
    sed -i '/# If not running interactively, don'\''t do anything/i export PATH="$PATH:/home/orangepi/player/util-scripts"' ~/.bashrc
    echo -e "\033[1;31mThe PATH has been updated. \nPlease exit the terminal and ssh in again, or run '. ~/.bashrc' after this script finishes to apply the changes.\033[0m"
    read -p "Press enter to continue"
else
    echo "The PATH is already configured correctly."
fi


print_section "CHANGING DEFAULT PASSWORD"
echo "orangepi:orangead" | sudo chpasswd


print_section "SETTING TIMEZONE TO MONTREAL"
sudo timedatectl set-timezone America/Montreal
echo "Current timezone set to: $(timedatectl | grep "Time zone" | awk '{print $3}')"


print_section "CONFIGURING DISPLAY"
"$ROOT_DIR/util-scripts/display.sh"


print_section "CONFIGURING WIFI"
"$ROOT_DIR/util-scripts/wifi.sh"


print_section "SETTING UP DAILY REBOOT AT 3AM"
echo "0 3 * * * /sbin/reboot" | crontab -
echo "Current crontab setting:"
crontab -l | sed 's/^/\t/'


print_section "SETTING UP SYSTEMD SERVICES"
# slideshow-player.service and chromium-log-monitor.service will be handled separately in player-config.sh
for service in "$ROOT_DIR"/systemd/*.service; do
    service_name=$(basename "$service")
    
    if [ -f "$service" ] && [ "$service_name" != "slideshow-player.service" ] && [ "$service_name" != "chromium-log-monitor.service" ]; then
        sudo cp "$service" /etc/systemd/system/
        sudo systemctl daemon-reload
        sudo systemctl enable --now "$service_name"
        echo "$service_name is $(sudo systemctl is-active "$service_name")"
    fi
done


print_section "DISABLING UPDATE NOTIFICATIONS"
# Disable update-notifier
gsettings set com.ubuntu.update-notifier no-show-notifications true
# Disable check for major release upgrades
gsettings set com.ubuntu.update-manager check-dist-upgrades false
# Ignore new releases
gsettings set com.ubuntu.update-manager check-new-release-ignore true
# Ensure update-manager does not run on first launch, which might trigger notifications
gsettings set com.ubuntu.update-manager first-run false

# Disable automatic updates in the background via unattended-upgrades
sudo sed -i 's/^APT::Periodic::Update-Package-Lists "1";/APT::Periodic::Update-Package-Lists "0";/g' /etc/apt/apt.conf.d/20auto-upgrades
sudo sed -i 's/^APT::Periodic::Unattended-Upgrade "1";/APT::Periodic::Unattended-Upgrade "0";/g' /etc/apt/apt.conf.d/20auto-upgrades

# Stop the periodic update checks for package lists, new upgrades, and autoclean intervals
sudo sed -i 's/^APT::Periodic::Update-Package-Lists "1";/APT::Periodic::Update-Package-Lists "0";/g' /etc/apt/apt.conf.d/10periodic
sudo sed -i 's/^APT::Periodic::Download-Upgradeable-Packages "1";/APT::Periodic::Download-Upgradeable-Packages "0";/g' /etc/apt/apt.conf.d/10periodic
sudo sed -i 's/^APT::Periodic::AutocleanInterval "1";/APT::Periodic::AutocleanInterval "0";/g' /etc/apt/apt.conf.d/10periodic

# Adjusting settings in the 02-orangepi-periodic file
sudo sed -i 's/^APT::Periodic::Enable ".*";/APT::Periodic::Enable "0";/' /etc/apt/apt.conf.d/02-orangepi-periodic
sudo sed -i 's/^APT::Periodic::Update-Package-Lists ".*";/APT::Periodic::Update-Package-Lists "0";/' /etc/apt/apt.conf.d/02-orangepi-periodic
sudo sed -i 's/^APT::Periodic::Unattended-Upgrade ".*";/APT::Periodic::Unattended-Upgrade "0";/' /etc/apt/apt.conf.d/02-orangepi-periodic
sudo sed -i 's/^APT::Periodic::AutocleanInterval ".*";/APT::Periodic::AutocleanInterval "0";/' /etc/apt/apt.conf.d/02-orangepi-periodic

# Disable dpkg post-invoke action for update-notifier
sudo sed -i 's/^DPkg::Post-Invoke {/#&/' /etc/apt/apt.conf.d/99update-notifier
# Disable APT update post-invoke success action for update-notifier
sudo sed -i 's/^APT::Update::Post-Invoke-Success {/#&/' /etc/apt/apt.conf.d/99update-notifier

# Log the final state of the update-manager settings
echo "Update-manager settings:"
gsettings list-recursively com.ubuntu.update-manager | sed 's/^/\t/'
echo "Update-notifier settings:"
gsettings list-recursively com.ubuntu.update-notifier | sed 's/^/\t/'


print_section "CONFIGURING GNOME SETTINGS"
# Disable Bluetooth by default
rfkill block bluetooth
gsettings set org.blueman.plugins.powermanager auto-power-on false
bluetooth_status=$(rfkill list bluetooth | grep -c "Soft blocked: yes")
[ "$bluetooth_status" -gt 0 ] && echo "Bluetooth: off" || echo "Bluetooth: on"

# Configure the on-screen keyboard settings
gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true
keyboard_status=$(gsettings get org.gnome.desktop.a11y.applications screen-keyboard-enabled)
[ "$keyboard_status" = "true" ] && echo "On-screen keyboard: on" || echo "On-screen keyboard: off"

# Configure power settings to prevent screen dimming and blanking
gsettings set org.gnome.settings-daemon.plugins.power idle-dim false
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
echo "Power settings:"
gsettings list-recursively org.gnome.settings-daemon.plugins.power | sed 's/^/\t/'


print_section "CLEANING UP KEYRING FILES"
KEYRING_DIR="/home/orangepi/.local/share/keyrings"
# Rename keyring files by appending .bak extension
find "$KEYRING_DIR" -type f -name 'Default_keyring*.keyring' ! -name 'Default_keyring.keyring' -exec mv {} {}.bak \;
# Log the final state of keyring files
echo "Current keyring files in the directory after cleanup:"
ls "$KEYRING_DIR" | grep 'Default_keyring*.keyring' | sed 's/^/\t/'


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
        vnc_display_name_line=$(grep -n "display-name=GNOME Remote Desktop VNC password" "$KEYRING_FILE" | cut -d: -f1)
        vnc_secret_line=$((vnc_display_name_line + 1))  # The secret line follows the display-name line

        # Update the secret within the found block
        sed -i "${vnc_secret_line}s/secret=.*/secret=orangead/" "$KEYRING_FILE"
        echo "VNC entry updated in the keyring file."
    else
        echo "VNC entry is already up-to-date in the keyring file."
    fi
else
    echo "Keyring file not found."
fi


print_section "ENABLE GNOME REMOTE DESKTOP SERVICE"
systemctl --user enable gnome-remote-desktop
systemctl --user start gnome-remote-desktop
systemctl --user  --no-pager status gnome-remote-desktop


print_section "ENABLE VNC"
grdctl vnc enable
grdctl vnc set-auth-method password
grdctl vnc disable-view-only
grdctl status --show-credentials


print_section "UPDATING SYSTEM"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get upgrade --fix-missing -y -o Dpkg::Options::="--force-confnew"

print_section "RUNNING INIT SCRIPTS"
for script in "$ROOT_DIR"/init-scripts/*.sh; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        echo "Executing $script..."
        "$script"
    fi
done

print_section "SETUP COMPLETED"

