#!/bin/bash

# Functions
prompt_for_directory_choice() {
    echo "Which directory do you want to use?"
    echo "1. Production"
    echo "2. Pre-production"
    echo "3. Staging"
    read -p "Enter your choice (1-3): " choice
    case $choice in
        1) WORKING_DIR="$CURRENT_DIR/prod";;
        2) WORKING_DIR="$CURRENT_DIR/preprod";;
        3) WORKING_DIR="$CURRENT_DIR/staging";;
        *) echo "Invalid choice. Exiting."; exit 1;;
    esac
}

extract_release_file() {
    local RELEASE_FILE="$RELEASES_DIR/$ENV_NAME.tar.gz"
    if [[ -f "$RELEASE_FILE" ]]; then
        mkdir "$WORKING_DIR"
        tar -xzf "$RELEASE_FILE" -C "$WORKING_DIR"
        echo "Extracted $ENV_NAME.tar.gz to $WORKING_DIR."
    else
        echo "Error: $RELEASE_FILE not found in $RELEASES_DIR. Exiting."
        exit 1
    fi
}

update_slideshow_script() {
    [[ ! -x "$SLIDESHOW_SCRIPT" ]] && chmod +x "$SLIDESHOW_SCRIPT" && echo "Made slideshow-player script executable"
    
    grep -qF "google-chrome-stable" "$SLIDESHOW_SCRIPT" && sed -i 's/google-chrome-stable/chromium-browser/g' "$SLIDESHOW_SCRIPT" && echo "Replaced google-chrome-stable with chromium-browser in $SLIDESHOW_SCRIPT"
    
    grep -qF "export DISPLAY=:0.0" "$SLIDESHOW_SCRIPT" || { sed -i "/chromium-browser --new-window/i export DISPLAY=:0.0" "$SLIDESHOW_SCRIPT"; echo "Added 'export DISPLAY=:0.0' to $SLIDESHOW_SCRIPT"; }
    
    grep -qF "disable-application-cache" "$SLIDESHOW_SCRIPT" || { sed -i "/chromium-browser --new-window/c\chromium-browser --new-window $CHROMIUM_ARGUMENTS --start-fullscreen --app=http://localhost:8080/?platform=device &" "$SLIDESHOW_SCRIPT"; echo "Added chromium-browser arguments to $SLIDESHOW_SCRIPT"; }
}

configure_hostname_and_imei() {
    local CURRENT_IMEI="$HOSTNAME"
    local CHANGED_HOSTNAME=0
    
    # Using a combination of text effects to make the prompt stand out
    echo -e "\n\e[1;33m=================================================="
    echo -e "IMPORTANT: HOSTNAME & IMEI CONFIGURATION"
    echo -e "=================================================="
    echo -e "Current HOSTNAME/IMEI is set to: \e[1;31m$CURRENT_IMEI\e[0m."
    echo -e "\e[1;32mIf needed, please provide a new HOSTNAME/IMEI (press Enter to keep the current one).\e[0m"
    
    read -p "Enter a new HOSTNAME/IMEI: " NEW_HOSTNAME_IMEI
    
    # If the user inputs a new HOSTNAME/IMEI, update the hostname
    if [[ ! -z "$NEW_HOSTNAME_IMEI" ]]; then
        sudo hostnamectl set-hostname "$NEW_HOSTNAME_IMEI"
        pkill chromium
        rm -rf /home/orangepi/.config/chromium/Singleton*
        CHANGED_HOSTNAME=1
        CURRENT_IMEI="$NEW_HOSTNAME_IMEI"
    fi
    
    echo "$CURRENT_IMEI" > "$IMEI_FILE"
    echo -e "HOSTNAME set to: \e[1;31m$CURRENT_IMEI\e[0m"
    echo -e "IMEI set to: \e[1;31m$CURRENT_IMEI\e[0m in $IMEI_FILE"
    echo -e "\e[1;33m==================================================\e[0m\n"
    
    return $CHANGED_HOSTNAME
}

# Main Execution
HOSTNAME=$(hostname)
CURRENT_DIR=$(dirname "$(readlink -f "$0")")
RELEASES_DIR="$CURRENT_DIR/releases"
LOGS_DIR="$CURRENT_DIR/logs"
mkdir -p "$LOGS_DIR"

prompt_for_directory_choice

ENV_NAME=$(basename "$WORKING_DIR")
SLIDESHOW_SCRIPT="$WORKING_DIR/dist/linux/slideshow-player"
IMEI_FILE="$WORKING_DIR/dist/Documents/imei.txt"
CHROMIUM_ARGUMENTS="--no-first-run --hide-crash-restore-bubble --aggressive-cache-discard --disable-application-cache --media-cache-size=1 --disk-cache-size=1"

# Remove existing directory and extract the new release
[[ -d "$WORKING_DIR" ]] && rm -rf "$WORKING_DIR" && echo "Removed existing $ENV_NAME directory."
extract_release_file

# Slideshow script updates
update_slideshow_script

REBOOT_REQUIRED=0
# Configure Hostname and IMEI
configure_hostname_and_imei
REBOOT_REQUIRED=$?

# Call the release-change script
"$CURRENT_DIR/util-scripts/release-change.sh" "$choice"

if [[ $REBOOT_REQUIRED -eq 1 ]]; then
    read -p "A reboot is required due to hostname change. Do you want to reboot now? (Y/n): " reboot_response
    reboot_response=${reboot_response:-y}
    if [[ $reboot_response =~ ^[Yy]$ ]]; then
        sudo reboot
    else
        echo "Please remember to reboot manually later."
    fi
fi

echo "Setup complete."
