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
        # Set up WiFi security only if a password is provided
        if [ -n "$password" ]; then
            nmcli con modify "$con_name" wifi-sec.key-mgmt wpa-psk
            nmcli con modify "$con_name" wifi-sec.psk "$password"
        else
            echo -e "\nWARNING: $con_name does not require a password, but may need extra interaction.\n"
            nmcli con modify "$con_name" wifi-sec.key-mgmt none
        fi
        nmcli con modify "$con_name" connection.autoconnect yes
        nmcli con modify "$con_name" connection.autoconnect-priority "$priority"
        echo "WiFi credentials updated for $con_name"
    else
        echo "Failed to add new connection for $con_name."
    fi
}

# Function to list available WiFi networks and handle user selection
list_wifi_networks() {
    echo -e "\nAvailable WiFi networks:"

    # Capture the output of 'nmcli dev wifi' in a temporary file
    TEMP_FILE=$(mktemp)
    script -q -c "nmcli dev wifi" "$TEMP_FILE" > /dev/null

    # Remove the first and last lines which are added by 'script' command
    sed -i '1d;$d' "$TEMP_FILE"

    # Store the original output with ANSI codes (colored output)
    # Remove the first and last line of the original output
    local original_output=$(sed '1d;$d' "$TEMP_FILE")

    # Now remove ANSI escape codes for processing
    sed -i 's/\x1B\[[0-9;]*[JKmsu]//g' "$TEMP_FILE"

    # Extract and display the header (now the first line in the file)
    local header=$(nmcli dev wifi | head -n 1)
    echo -e "        $header"

    # Display the list of networks with line numbers
    echo "$original_output" | cat -n
}

# Check and setup default WiFi connection
echo "Checking for default WiFi connection..."
create_or_update_wifi "$DEFAULT_SSID" "$DEFAULT_PASSWORD" "$DEFAULT_CON_NAME" "$DEFAULT_CONNECTION_PRIORITY"

# List available WiFi networks
list_wifi_networks

echo -e "\nEnter the number of your WiFi network or 'n' to enter a new SSID:"
read -r choice

if [[ $choice =~ ^[0-9]+$ ]]; then
    # Retrieve the SSID from the cleaned output, assuming SSID is the 2nd column
    SSID_SELECTED=$(awk 'NR=='$((choice + 1))'{print $2}' "$TEMP_FILE")
else
    echo "Enter new SSID:"
    read -r USER_SSID
fi

# Ask for the WiFi password
read -p "Enter WiFi Password for $SSID_SELECTED: " USER_PASSWORD
echo ""

# Update WiFi with user provided details
create_or_update_wifi "$SSID_SELECTED" "$USER_PASSWORD" "$SSID_SELECTED" 100

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
