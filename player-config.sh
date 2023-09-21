#!/bin/bash

# Get the current directory
CURRENT_DIR=$(dirname "$(readlink -f "$0")")
RELEASES_DIR="$CURRENT_DIR/releases"
# Choose which directory to use
echo "Which directory do you want to use?"
echo "1. Production"
echo "2. Pre-production"
echo "3. Staging"
read -p "Enter your choice (1-3): " choice
# Set the directory based on the choice
if [[ $choice == 1 ]]; then
    WORKING_DIR="$CURRENT_DIR/prod"
    elif [[ $choice == 2 ]]; then
    WORKING_DIR="$CURRENT_DIR/preprod"
    elif [[ $choice == 3 ]]; then
    WORKING_DIR="$CURRENT_DIR/staging"
else
    echo "Invalid choice. Exiting."
    exit 1
fi

# Set variables
HOSTNAME=$(hostname)
SLIDESHOW_SCRIPT="$WORKING_DIR/dist/linux/slideshow-player"
IMEI_FILE="$WORKING_DIR/dist/Documents/imei.txt"
LOGS_DIR="$CURRENT_DIR/logs"

# Create logs directory if it doesn't exist
mkdir -p "$LOGS_DIR"

# Check if the directory exists
if [[ ! -d "$WORKING_DIR" ]]; then
    env_name=$(basename "$WORKING_DIR")
    echo "Directory $env_name does not exist. Extracting."
    
    # Create the directory
    mkdir "$WORKING_DIR"
    
    # Extract the tar.gz file from the releases folder
    tar_file="$RELEASES_DIR/$env_name.tar.gz"
    if [[ -f "$tar_file" ]]; then
        tar -xzf "$tar_file" -C "$WORKING_DIR"
        echo "Extracted $env_name.tar.gz to $WORKING_DIR."
    else
        echo "Error: $tar_file not found in $RELEASES_DIR. Exiting."
        exit 1
    fi
fi

# Make the slideshow-player script executable if it isn't
if [[ ! -x "$SLIDESHOW_SCRIPT" ]]; then
    chmod +x "$SLIDESHOW_SCRIPT"
    echo "Made slideshow-player script executable."
fi
# Check if google-chrome-stable is mentioned in the script and replace with chromium-browser
if grep -qF "google-chrome-stable" "$SLIDESHOW_SCRIPT"; then
    sed -i 's/google-chrome-stable/chromium-browser/g' "$SLIDESHOW_SCRIPT"
    echo "Replaced google-chrome-stable with chromium-browser in $SLIDESHOW_SCRIPT."
fi
# Check if "export DISPLAY=:0.0" is in the script and if not, add it
if ! grep -qF "export DISPLAY=:0.0" "$SLIDESHOW_SCRIPT"; then
    # Inserting the export line before launching chromium-browser.
    sed -i "/chromium-browser --new-window/i export DISPLAY=:0.0" "$SLIDESHOW_SCRIPT"
    echo "Added 'export DISPLAY=:0.0' to $SLIDESHOW_SCRIPT."
fi
# Check if a specific chromium-browser argument is present. If not, add all arguments
CHROMIUM_ARGUMENTS="--no-first-run --hide-crash-restore-bubble --aggressive-cache-discard --disable-application-cache --media-cache-size=1 --disk-cache-size=1"
if ! grep -qF "disable-application-cache" "$SLIDESHOW_SCRIPT"; then
    sed -i "/chromium-browser --new-window/c\chromium-browser --new-window $CHROMIUM_ARGUMENTS --start-fullscreen --app=http://localhost:8080/?platform=device &" "$SLIDESHOW_SCRIPT"
    echo "Added chromium-browser arguments to $SLIDESHOW_SCRIPT."
fi

# Check if hostname ends with a 4-digit number
if [[ $HOSTNAME =~ [0-9]{4}$ ]]; then
    CONTENT="$HOSTNAME"
else
    CONTENT="opitemplate"
fi
# Check if imei.txt exists in the `Documents` directory and create it if it doesn't
if [[ ! -f "$IMEI_FILE" ]]; then
    echo "$CONTENT" > "$IMEI_FILE"
    echo "Created $IMEI_FILE with content: $CONTENT."
fi

# Call the release-change script
"$CURRENT_DIR/util-scripts/release-change.sh" "$choice"

echo "Setup complete."
