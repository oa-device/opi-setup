#!/bin/bash

echo "========== SETTING UP TAILSCALE =========="

# Install Tailscale
echo "Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh
echo "Tailscale installed!"

echo "========== TAILSCALE SETUP COMPLETE =========="