#!/bin/bash

# Source the config file
source "$(dirname "$(readlink -f "$0")")/path-config.sh"

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

set_choice_based_on_current_release() {
    local CURRENT_RELEASE=$1
    case "$CURRENT_RELEASE" in
    "prod") echo 1 ;;
    "preprod") echo 2 ;;
    "staging") echo 3 ;;
    esac
}

prompt_for_directory_choice() {
    local CURRENT_RELEASE=$(get_current_release)
    echo "Which directory do you want to use?"
    echo "1. Production"
    echo "2. Pre-production"
    echo "3. Staging"
    if [[ -n "$CURRENT_RELEASE" ]]; then
        echo -e "The current release is \e[1;33m$CURRENT_RELEASE\e[0m.\n"
        if [[ -z "$SSH_TTY" ]]; then
            echo -e "\e[1;31mNon-interactive shell or SSH connection detected, using the current release.\e[0m"
            choice=$(set_choice_based_on_current_release "$CURRENT_RELEASE")
        else
            read -t 10 -p "Press Enter to continue using this release, or enter a number (1-3) to choose a different directory: " choice
            if [[ -z "$choice" ]]; then
                echo -e "\n\e[1;31mNo input received within 10 seconds, using the current release.\e[0m"
                choice=$(set_choice_based_on_current_release "$CURRENT_RELEASE")
            else
                case "$choice" in
                1) CURRENT_RELEASE="prod" ;;
                2) CURRENT_RELEASE="preprod" ;;
                3) CURRENT_RELEASE="staging" ;;
                *) echo "Invalid choice. Please enter a valid choice (1-3):" ;;
                esac
            fi
        fi
        WORKING_DIR="$PLAYER_ROOT_DIR/$CURRENT_RELEASE"
        return
    else
        while true; do
            read -p "Enter your choice (1-3): " choice
            case $choice in
            1)
                WORKING_DIR="$PLAYER_ROOT_DIR/prod"
                break
                ;;
            2)
                WORKING_DIR="$PLAYER_ROOT_DIR/preprod"
                break
                ;;
            3)
                WORKING_DIR="$PLAYER_ROOT_DIR/staging"
                break
                ;;
            *) echo "Invalid choice. Please enter a valid choice (1-3):" ;;
            esac
        done
    fi
}

extract_release_file() {
    local RELEASE_FILE="$PLAYER_RELEASES_DIR/$ENV_NAME.tar.gz"
    if [[ -f "$RELEASE_FILE" ]]; then
        mkdir "$WORKING_DIR"
        tar -xzf "$RELEASE_FILE" -C "$WORKING_DIR"
        echo "Extracted $ENV_NAME.tar.gz to $WORKING_DIR."
    else
        echo "Error: $RELEASE_FILE not found in $PLAYER_RELEASES_DIR. Exiting."
        exit 1
    fi
}

update_slideshow_script() {
    [[ ! -x "$SLIDESHOW_SCRIPT" ]] && chmod +x "$SLIDESHOW_SCRIPT" && echo "Made slideshow-player script executable"

    grep -qF "google-chrome-stable" "$SLIDESHOW_SCRIPT" && sed -i 's/google-chrome-stable/chromium-browser/g' "$SLIDESHOW_SCRIPT" && echo "Replaced google-chrome-stable with chromium-browser in $SLIDESHOW_SCRIPT"

    grep -qF "export DISPLAY=:0.0" "$SLIDESHOW_SCRIPT" || {
        sed -i "/chromium-browser --new-window/i export DISPLAY=:0.0" "$SLIDESHOW_SCRIPT"
        echo "Added 'export DISPLAY=:0.0' to $SLIDESHOW_SCRIPT"
    }

    grep -qF "disable-application-cache" "$SLIDESHOW_SCRIPT" || {
        sed -i "/chromium-browser --new-window/c\chromium-browser --new-window $CHROMIUM_ARGUMENTS --start-fullscreen --app=http://localhost:8080/?platform=device &" "$SLIDESHOW_SCRIPT"
        echo "Added chromium-browser arguments to $SLIDESHOW_SCRIPT"
    }
}

generate_imei_file() {
    local CURRENT_IMEI="$HOSTNAME"

    echo -e "\n\e[1;33m=================================================="
    echo -e "IMPORTANT: IMEI CONFIGURATION"
    echo -e "=================================================="
    echo -e "Current IMEI is set to: \e[1;31m$CURRENT_IMEI\e[0m."
    echo -e "\e[1;32mIf needed, please provide a new IMEI (press Enter to keep the current one).\e[0m"

    if [[ -z "$SSH_TTY" ]]; then
        echo -e "\e[1;31mNon-interactive shell or SSH connection detected, using the current IMEI\e[0m."
        NEW_IMEI="$CURRENT_IMEI"
    else
        read -t 10 -p "Enter a new IMEI: " NEW_IMEI
        if [[ -z "$NEW_IMEI" ]]; then
            echo -e "\e[1;31mNo input received within 10 seconds, using the current IMEI\e[0m."
            NEW_IMEI="$CURRENT_IMEI"
        fi
    fi

    echo "$NEW_IMEI" >"$IMEI_FILE"
    echo -e "IMEI set to: \e[1;31m$NEW_IMEI\e[0m in $IMEI_FILE"
    echo -e "\e[1;33m==================================================\e[0m\n"
}

grant_chromium_camera_access() {
    POLICY_FILE="/etc/chromium-browser/policies/managed/oa_camera_policy.json"

    # Ensure the policy directory exists
    sudo mkdir -p /etc/chromium-browser/policies/managed

    # Create or update the policy file
    sudo bash -c "cat > $POLICY_FILE <<EOL
{
  \"URLAllowlist\": [\"http://localhost:8080\"],
  \"VideoCaptureAllowedUrls\": [\"http://localhost:8080\"]
}
EOL"
    echo "Policy file created at $POLICY_FILE to allow camera access for localhost:8080 in incognito mode."
}

# Main Execution
HOSTNAME=$(hostname)
mkdir -p "$PLAYER_LOGS_DIR"

prompt_for_directory_choice

ENV_NAME=$(basename "$WORKING_DIR")
SLIDESHOW_SCRIPT="$WORKING_DIR/dist/linux/slideshow-player"
IMEI_FILE="$WORKING_DIR/dist/Documents/imei.txt"
CHROMIUM_ARGUMENTS=" --incognito --enable-logging --v=1 --autoplay-policy=no-user-gesture-required --no-first-run --hide-crash-restore-bubble --aggressive-cache-discard --disable-application-cache --media-cache-size=1 --disk-cache-size=1"

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
"$PLAYER_UTIL_SCRIPTS_DIR/release-change.sh" "$choice"

echo "Setup complete."
