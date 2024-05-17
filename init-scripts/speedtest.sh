#!/bin/bash

echo "========== SETTING UP SPEEDTEST-CLI =========="

# Check if speedtest is installed
if ! command -v speedtest &> /dev/null; then
    echo "Adding Ookla repository..."
    curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash

    echo "Installing speedtest-cli..."
    sudo apt-get install -y speedtest
else
    echo "speedtest-cli is already installed!"
fi

# Accept Speedtest license agreement
echo "Accepting Speedtest license agreement..."
timeout 0.5s speedtest --accept-license > /dev/null 2>&1 || true

echo "========== SPEEDTEST-CLI SETUP COMPLETE =========="