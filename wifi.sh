#!/bin/bash

echo "========== SETTING UP WIFI =========="

SSID=$(hostname)
PASSWORD="994HYuuu94"
CON_NAME="OrangePi_WiFi"

echo "Updating WiFi Credentials with nmcli..."
# Check if the connection already exists, if it does, delete it
if nmcli con show | grep -q "$CON_NAME"; then
    nmcli con delete "$CON_NAME"
fi

# Add a new connection with the provided credentials
if nmcli con add con-name "$CON_NAME" ifname wlan0 type wifi ssid "$SSID"; then
    # Only continue if the connection was successfully created
    nmcli con modify "$CON_NAME" wifi-sec.key-mgmt wpa-psk
    nmcli con modify "$CON_NAME" wifi-sec.psk "$PASSWORD"
    nmcli con modify "$CON_NAME" connection.autoconnect yes
    echo "WiFi credentials updated with nmcli!"
else
    echo "Failed to add new connection."
fi

echo "========== WIFI SETUP COMPLETE =========="