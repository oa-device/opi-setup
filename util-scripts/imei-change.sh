#!/bin/bash

# Source the config file using an absolute path
source "$(dirname "$(readlink -f "$0")")/../path-config.sh"

# Define the RELEASES array
RELEASES=("prod" "preprod" "staging")

# Ask the user for the new IMEI
read -p "Enter the new IMEI (leave blank to skip updating): " new_imei

# Check if the input is blank and exit if it is
if [ -z "$new_imei" ]; then
    echo "No IMEI provided. Exiting without any changes."
    exit 0
fi

# Loop through the releases and update imei.txt if the directory exists
for release in "${RELEASES[@]}"; do
    IMEI_FILE="$PLAYER_ROOT_DIR/$release/dist/Documents/imei.txt"
    if [ -d "$PLAYER_ROOT_DIR/$release" ] && [ -f "$IMEI_FILE" ]; then
        echo "$new_imei" >"$IMEI_FILE"
        echo "Updated IMEI for $release release."
    fi
done

echo "IMEI update completed."
