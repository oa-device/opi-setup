#!/bin/bash

# Get the directory of the current script's directory and the root directory
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Rename the array to RELEASES
RELEASES=("prod" "preprod" "staging")

# Ask the user for the new hostname
read -p "Enter the new hostname: " new_hostname

# Change the hostname
sudo hostnamectl set-hostname "$new_hostname"

# Ask the user if they want a different IMEI than the hostname
read -p "The imei.txt file will be changed to match the new hostname.\nIf you want a different IMEI, enter it now (leave blank to keep as hostname): " new_imei

# If the user leaves it blank, set new_imei to new_hostname
new_imei=${new_imei:-$new_hostname}

# Loop through the releases and update imei.txt if the directory exists
for release in "${RELEASES[@]}"; do
    IMEI_FILE="$ROOT_DIR/$release/dist/Documents/imei.txt"
    if [ -d "$ROOT_DIR/$release" ] && [ -f "$IMEI_FILE" ]; then
        echo "$new_imei" > "$IMEI_FILE"
        echo "Updated IMEI for $release release."
    fi
done

# Kill all running Chromium processes
pkill chromium

# Remove Chromium's Singleton files
rm -rf /home/orangepi/.config/chromium/Singleton*
echo "Chromium lock files have been removed to make it work properly on next boot."

# Notify the user about the required reboot
read -p "A reboot is required. Do you want to reboot now? (Y/n): " reboot_response
reboot_response=${reboot_response:-y}
if [[ $reboot_response =~ ^[Yy]$ ]]; then
    sudo reboot
else
    echo "Please remember to reboot manually later."
fi
