#!/bin/bash

# Get the directory of the current script's directory and the root directory
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
ROOT_DIR=$(dirname "$SCRIPT_DIR")

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
    IMEI_FILE="$ROOT_DIR/$release/dist/Documents/imei.txt"
    if [ -d "$ROOT_DIR/$release" ] && [ -f "$IMEI_FILE" ]; then
        echo "$new_imei" > "$IMEI_FILE"
        echo "Updated IMEI for $release release."
    fi
done

echo "IMEI update completed."
