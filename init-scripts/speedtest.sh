#!/bin/bash

echo "========== SETTING UP SPEEDTEST-CLI =========="

# Install speedtest-cli
echo "Adding Ookla repository..."
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash

echo "Installing speedtest-cli..."
sudo apt-get install -y speedtest

echo "Accepting Speedtest license agreement..."
speedtest --accept-license -L > /dev/null 2>&1

echo "========== SPEEDTEST-CLI SETUP COMPLETE =========="
