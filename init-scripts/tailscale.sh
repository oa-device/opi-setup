#!/bin/bash

echo "========== SETTING UP TAILSCALE =========="

# Check if Tailscale is installed
if ! command -v tailscale &> /dev/null; then
    echo "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    echo "Tailscale installed!"
else
    echo "Tailscale is already installed!"
fi

echo "========== TAILSCALE SETUP COMPLETE =========="