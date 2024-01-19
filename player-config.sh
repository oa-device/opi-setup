#!/bin/bash

# Functions
get_current_release() {
    local SERVICE_FILE="/etc/systemd/system/slideshow-player.service"
    if [[ -f "$SERVICE_FILE" ]]; then
        local CURRENT_RELEASE_PATH=$(grep -oP '(?<=ExecStart=).*(?=/dist/linux/slideshow-player)' "$SERVICE_FILE")
        if [[ -n "$CURRENT_RELEASE_PATH" ]]; then
            local CURRENT_RELEASE=$(basename "$CURRENT_RELEASE_PATH")
            echo "$CURRENT_RELEASE"
        fi
    fi
}

prompt_for_directory_choice() {
    local CURRENT_RELEASE=$(get_current_release)
    echo "Which directory do you want to use?"
    echo "1. Production"
    echo "2. Pre-production"
    echo "3. Staging"
    if [[ -n "$CURRENT_RELEASE" ]]; then
        echo -e "The current release is \e[1;33m$CURRENT_RELEASE\e[0m.\n"
        if ! read -t 10 -p "Press Enter to continue using this release, or enter a number (1-3) to choose a different directory: " choice; then
            echo -e "\n\e[1;31mNo input received within 10 seconds, using the current release.\e[0m"
        fi
        if [[ -z "$choice" ]]; then
            WORKING_DIR="$CURRENT_RELEASE"
            case "$CURRENT_RELEASE" in
                "prod") choice=1;;
                "preprod") choice=2;;
                "staging") choice=3;;
            esac
            return
        fi
    else
        read -p "Enter your choice (1-3): " choice
    fi
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

generate_imei_file() {
    local CURRENT_IMEI="$HOSTNAME"
    
    # Using a combination of text effects to make the prompt stand out
    echo -e "\n\e[1;33m=================================================="
    echo -e "IMPORTANT: IMEI CONFIGURATION"
    echo -e "=================================================="
    echo -e "Current IMEI is set to: \e[1;31m$CURRENT_IMEI\e[0m."
    echo -e "\e[1;32mIf needed, please provide a new IMEI (press Enter to keep the current one).\e[0m"
    
    if ! read -t 10 -p "Enter a new IMEI: " NEW_IMEI; then
        echo -e "\e[1;31mNo input received within 10 seconds, using the current IMEI\e[0m."
        NEW_IMEI="$CURRENT_IMEI"
    elif [[ -z "$NEW_IMEI" ]]; then
        NEW_IMEI="$CURRENT_IMEI"
    fi
    
    echo "$NEW_IMEI" > "$IMEI_FILE"
    echo -e "IMEI set to: \e[1;31m$NEW_IMEI\e[0m in $IMEI_FILE"
    echo -e "\e[1;33m==================================================\e[0m\n"
}

grant_chromium_camera_access() {
    PREFERENCES_FILE="$HOME/.config/chromium/Default/Preferences"
    
    # Ensure that the chromium-browser is not running when modifying this file.
    pkill chromium

    if [[ ! -f "$PREFERENCES_FILE" ]]; then
        echo "Chromium Preferences file not found. Starting chromium-browser to create it..."
        export DISPLAY=:0.0
        chromium-browser --disable-session-crashed-bubble --disable-infobars > /dev/null 2>&1 &
        echo "Waiting for Chromium to create the Preferences file..."
        while [[ ! -f "$PREFERENCES_FILE" ]]; do
            sleep 1  # Wait for 1 second before checking again
        done
        pkill chromium  # Kill Chromium so we can modify the Preferences file
    fi

    # Backup the original Preferences file.
    cp "$PREFERENCES_FILE" "${PREFERENCES_FILE}.backup"

    # Use jq to set camera permission for localhost:8080 without last_modified
    jq '.profile.content_settings.exceptions.media_stream_camera += {"http://localhost:8080,*": {"setting": 1}}' "$PREFERENCES_FILE" > "${PREFERENCES_FILE}.tmp" && mv "${PREFERENCES_FILE}.tmp" "$PREFERENCES_FILE"
    echo "Granted camera permission for localhost:8080 in $PREFERENCES_FILE"
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
CHROMIUM_ARGUMENTS=" --enable-logging --v=1 --autoplay-policy=no-user-gesture-required --no-first-run --hide-crash-restore-bubble --aggressive-cache-discard --disable-application-cache --media-cache-size=1 --disk-cache-size=1"

# Processes name purposely truncated to 15 characters to match systemd service name
pkill slideshow-playe
pkill chromium-log-mo

# If the directory exists, remove it
if [[ -d "$WORKING_DIR" ]]; then
    rm -rf "$WORKING_DIR"
    echo "Removed existing $ENV_NAME directory."
fi

# Extract the new release
extract_release_file

# Slideshow script updates
update_slideshow_script

# Grant chromium-browser camera access for localhost:8080
grant_chromium_camera_access

# Generate IMEI file
generate_imei_file

# Call the release-change script
"$CURRENT_DIR/util-scripts/release-change.sh" "$choice"

echo "Setup complete."
