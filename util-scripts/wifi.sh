#!/bin/bash

echo "---------- SETTING UP WIFI ----------"

if [[ -z "$SSH_TTY" ]]; then
    echo "Running in a non-interactive SSH shell. Skipping process."
    exit 0
fi

# Default WiFi settings
DEFAULT_SSID="orangead_wifi"
DEFAULT_PASSWORD="orangead_wifi"
DEFAULT_CON_NAME="OrangeAd_Debug_Wifi"
DEFAULT_CONNECTION_PRIORITY=999

create_or_update_wifi() {
    local ssid="$1"
    local password="$2"
    local con_name="$3"
    local priority="$4"

    # Delete existing connection if it exists
    nmcli con show | grep -q "$con_name" && nmcli con delete "$con_name"

    # Add new connection
    if [ -n "$password" ]; then
        nmcli con add con-name "$con_name" ifname wlan0 type wifi ssid "$ssid"
        nmcli con modify "$con_name" wifi-sec.key-mgmt wpa-psk
        nmcli con modify "$con_name" wifi-sec.psk "$password"
    else
        nmcli --ask dev wifi connect "$con_name"
    fi

    # Configure autoconnect and priority
    nmcli con modify "$con_name" connection.autoconnect yes
    nmcli con modify "$con_name" connection.autoconnect-priority "$priority"

    echo "WiFi credentials updated for $con_name"
}

list_wifi_networks() {
    echo -e "\nAvailable WiFi networks:"

    TEMP_FILE=$(mktemp)
    script -q -c "nmcli dev wifi" "$TEMP_FILE" >/dev/null

    sed -i '1d;$d' "$TEMP_FILE"
    local original_output=$(sed '1d;$d' "$TEMP_FILE")

    local header=$(nmcli dev wifi | head -n 1)
    echo -e "        $header"

    echo "$original_output" | cat -n
}

extract_ssid() {
    local line_number="$1"
    local ssid=$(sed -n "${line_number}p" "$TEMP_FILE")

    if [[ $ssid =~ [0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}[[:space:]]+(.+)Infra ]]; then
        ssid="${BASH_REMATCH[2]}"
        ssid=$(echo "$ssid" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    else
        echo "Failed to extract SSID."
        return 1
    fi

    echo "$ssid"
}

configure_default_wifi() {
    echo "Checking for default WiFi connection..."
    create_or_update_wifi "$DEFAULT_SSID" "$DEFAULT_PASSWORD" "$DEFAULT_CON_NAME" "$DEFAULT_CONNECTION_PRIORITY"
}

configure_wifi_network() {
    echo -e "\n\e[1;31mIf no input is made within 30 seconds, the script will skip the WiFi setup.\e[0m"
    echo "Enter the number of your WiFi network, type 'n' to enter a new SSID, or hit Enter to skip:"
    read -t 30 -r choice

    if [[ $? -ne 0 ]]; then
        echo "Skipping WiFi setup due to timeout."
        return
    fi

    if [[ $choice =~ ^[0-9]+$ ]]; then
        SSID_SELECTED=$(extract_ssid $((choice + 1)))
        if [[ $? -ne 0 ]]; then
            echo "Error extracting SSID. Please try again."
            return
        fi

        read -p "Enter WiFi Password for \"$SSID_SELECTED\": " USER_PASSWORD
        echo ""
        create_or_update_wifi "$SSID_SELECTED" "$USER_PASSWORD" "$SSID_SELECTED" 100
    elif [[ $choice == "n" ]]; then
        read -p "Enter new SSID: " SSID_SELECTED
        read -p "Enter WiFi Password for \"$SSID_SELECTED\": " USER_PASSWORD
        echo ""
        create_or_update_wifi "$SSID_SELECTED" "$USER_PASSWORD" "$SSID_SELECTED" 100
    else
        echo "Skipping WiFi setup."
    fi
}

set_ethernet_priority() {
    echo "---------- SETTING UP ETHERNET PRIORITY ----------"
    nmcli -t -f NAME con show | grep "^Wired connection" | while read -r ETH_CON_NAME; do
        if [[ -n "$ETH_CON_NAME" ]]; then
            nmcli con modify "$ETH_CON_NAME" ipv4.route-metric 700
            nmcli con modify "$ETH_CON_NAME" ipv6.route-metric 700
            echo "Lowered priority for Ethernet connection: $ETH_CON_NAME"
        fi
    done
}

# Main Execution
configure_default_wifi
list_wifi_networks
configure_wifi_network
set_ethernet_priority

echo "---------- WIFI SETUP COMPLETE ----------"
