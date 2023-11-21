#!/bin/bash

echo "========== SETTING UP WIFI =========="

# Default wifi settings
DEFAULT_SSID="orangead_wifi"
DEFAULT_PASSWORD="orangead_wifi"
DEFAULT_CON_NAME="OrangeAd_Debug_Wifi"
DEFAULT_CONNECTION_PRIORITY=999

# Function to create or update a WiFi connection
create_or_update_wifi() {
    local ssid="$1"
    local password="$2"
    local con_name="$3"
    local priority="$4"

    # Check if the connection already exists, if it does, delete it
    if nmcli con show | grep -q "$con_name"; then
        nmcli con delete "$con_name"
    fi

    # Add a new connection with the provided credentials
    if nmcli con add con-name "$con_name" ifname wlan0 type wifi ssid "$ssid"; then
        nmcli con modify "$con_name" wifi-sec.key-mgmt wpa-psk
        nmcli con modify "$con_name" wifi-sec.psk "$password"
        nmcli con modify "$con_name" connection.autoconnect yes
        nmcli con modify "$con_name" connection.autoconnect-priority "$priority"
        echo "WiFi credentials updated for $con_name"
    else
        echo "Failed to add new connection for $con_name."
    fi
}

# Check and setup default WiFi connection
echo "Checking for default WiFi connection..."
create_or_update_wifi "$DEFAULT_SSID" "$DEFAULT_PASSWORD" "$DEFAULT_CON_NAME" "$DEFAULT_CONNECTION_PRIORITY"

# List available SSIDs and allow user to choose
echo "Available WiFi networks:"
nmcli dev wifi | awk '{print NR-1 " - " $0}' | tail -n +2
echo "Enter the number of your WiFi network or 'n' to enter a new SSID:"
read -r choice

if [[ $choice =~ ^[0-9]+$ ]]; then
    USER_SSID=$(nmcli dev wifi | awk 'NR=='$((choice + 1))'{print $2}')
else
    echo "Enter new SSID:"
    read -r USER_SSID
fi

# Ask for the WiFi password
read -s -p "Enter WiFi Password for $USER_SSID: " USER_PASSWORD
echo ""

# Update WiFi with user provided details
create_or_update_wifi "$USER_SSID" "$USER_PASSWORD" "$USER_SSID" 100

# Lower the priority of all Ethernet connections starting with "Wired connection"
echo "========== SETTING UP ETHERNET PRIORITY =========="

# Loop through each "Wired connection" and set their metric higher than WiFi
while IFS= read -r ETH_CON_NAME; do
    if [[ ! -z "$ETH_CON_NAME" ]]; then
        nmcli con modify "$ETH_CON_NAME" ipv4.route-metric 700
        nmcli con modify "$ETH_CON_NAME" ipv6.route-metric 700
        echo "Lowered priority for Ethernet connection: $ETH_CON_NAME"
    fi
done < <(nmcli -t -f NAME con show | grep "^Wired connection")

echo "========== WIFI SETUP COMPLETE =========="
