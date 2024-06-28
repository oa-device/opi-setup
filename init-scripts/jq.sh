#!/bin/bash

echo "---------- SETTING UP JQ FOR EDITING CHROMIUM PREFERENCE ----------"

# Check if jq is installed
if ! command -v jq &>/dev/null; then
    echo "Installing jq..."
    sudo apt-get install -y jq
else
    echo "jq is already installed!"
fi

echo "---------- JQ FOR EDITING CHROMIUM PREFERENCE SETUP COMPLETE ----------"
