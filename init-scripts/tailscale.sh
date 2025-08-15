#!/bin/bash

# Enhanced Tailscale Setup for OrangePi
# Integrates with Ansible automation while maintaining standalone functionality

set -e

print_header() {
    echo "╔════════════════════════════════════════════════════╗"
    echo "║              OrangePi Tailscale Setup              ║"
    echo "╚════════════════════════════════════════════════════╝"
}

print_section() {
    echo "---------- $1 ----------"
}

print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "success" ]; then
        echo "✅ $message"
    elif [ "$status" = "error" ]; then
        echo "❌ $message"
    elif [ "$status" = "warning" ]; then
        echo "⚠️  $message"
    else
        echo "ℹ️  $message"
    fi
}

# Configuration
TAILSCALE_AUTH_KEY="${TAILSCALE_AUTH_KEY:-}"
DEVICE_HOSTNAME="${DEVICE_HOSTNAME:-$(hostname)}"
TAILSCALE_TAGS="${TAILSCALE_TAGS:-tag:oa-orangepi,tag:oa-device}"

print_header
print_section "CHECKING TAILSCALE INSTALLATION"

# Check if Tailscale is installed
if ! command -v tailscale &>/dev/null; then
    print_status "info" "Tailscale not found. Installing..."
    
    # Install Tailscale using the official script
    if curl -fsSL https://tailscale.com/install.sh | sh; then
        print_status "success" "Tailscale installed successfully"
    else
        print_status "error" "Failed to install Tailscale"
        exit 1
    fi
else
    print_status "success" "Tailscale is already installed"
    
    # Show current version
    echo "Current version: $(tailscale version --short)"
fi

print_section "CONFIGURING TAILSCALE SERVICE"

# Enable and start the service
if sudo systemctl enable --now tailscaled; then
    print_status "success" "Tailscale service enabled and started"
else
    print_status "error" "Failed to start Tailscale service"
    exit 1
fi

# Wait for service to be ready
sleep 2

print_section "CHECKING CONNECTION STATUS"

# Check if already connected
if tailscale status &>/dev/null; then
    print_status "success" "Tailscale is already connected"
    echo "Current status:"
    tailscale status --self
    
    print_section "CONNECTION INFORMATION"
    echo "📱 Device name: $(tailscale status --json | jq -r '.Self.DNSName' | sed 's/\..*//')"
    echo "🌐 IP address: $(tailscale ip -4 2>/dev/null || echo 'N/A')"
    echo "🏷️  Tags: $(tailscale status --json | jq -r '.Self.Tags[]?' 2>/dev/null | tr '\n' ',' | sed 's/,$//' || echo 'None')"
    
else
    print_status "warning" "Tailscale not connected"
    
    if [ -n "$TAILSCALE_AUTH_KEY" ]; then
        print_section "CONNECTING WITH AUTH KEY"
        
        # Build connection command
        CONNECT_CMD="tailscale up --authkey=$TAILSCALE_AUTH_KEY --hostname=$DEVICE_HOSTNAME"
        
        if [ -n "$TAILSCALE_TAGS" ]; then
            CONNECT_CMD="$CONNECT_CMD --advertise-tags=$TAILSCALE_TAGS"
        fi
        
        # Add common OrangePi-specific options
        CONNECT_CMD="$CONNECT_CMD --accept-routes --ssh"
        
        print_status "info" "Connecting with hostname: $DEVICE_HOSTNAME"
        print_status "info" "Using tags: $TAILSCALE_TAGS"
        
        if eval "$CONNECT_CMD"; then
            print_status "success" "Tailscale connected successfully!"
            
            # Wait for connection to stabilize
            sleep 3
            
            print_section "CONNECTION VERIFICATION"
            echo "📱 Device name: $DEVICE_HOSTNAME"
            echo "🌐 IP address: $(tailscale ip -4)"
            
            # Test connectivity
            if tailscale ping $DEVICE_HOSTNAME >/dev/null 2>&1; then
                print_status "success" "Self-ping test passed"
            else
                print_status "warning" "Self-ping test failed (may be normal)"
            fi
            
        else
            print_status "error" "Failed to connect to Tailscale"
            echo ""
            echo "💡 Manual connection:"
            echo "   sudo tailscale up --authkey=YOUR_AUTH_KEY --hostname=$DEVICE_HOSTNAME"
            exit 1
        fi
    else
        print_status "warning" "No auth key provided"
        echo ""
        echo "💡 To connect manually:"
        echo "   1. Get an auth key from https://login.tailscale.com/admin/settings/keys"
        echo "   2. Run: sudo tailscale up --authkey=YOUR_AUTH_KEY --hostname=$DEVICE_HOSTNAME"
        echo "   3. Or set TAILSCALE_AUTH_KEY environment variable and re-run this script"
    fi
fi

print_section "CREATING MANAGEMENT UTILITIES"

# Create a simple status script in the util-scripts directory
UTIL_SCRIPT_DIR="$(dirname "$(readlink -f "$0")")/../util-scripts"
if [ -d "$UTIL_SCRIPT_DIR" ]; then
    cat > "$UTIL_SCRIPT_DIR/oatailscale" << 'EOF'
#!/bin/bash
# OrangePi Tailscale Management Utility

case "${1:-status}" in
    "status"|"")
        echo "🍊 Tailscale Status:"
        tailscale status --self
        echo ""
        echo "🌐 Network Information:"
        echo "IP Address: $(tailscale ip -4 2>/dev/null || echo 'Not connected')"
        ;;
    "ping")
        target="${2:-$(hostname)}"
        echo "🏓 Testing connectivity to $target..."
        if tailscale ping "$target" >/dev/null 2>&1; then
            echo "✅ $target is reachable"
        else
            echo "❌ $target is not reachable"
        fi
        ;;
    "restart")
        echo "🔄 Restarting Tailscale..."
        sudo systemctl restart tailscaled
        sleep 3
        tailscale status --self
        ;;
    "help")
        echo "OrangePi Tailscale Management"
        echo "Usage: oatailscale [command]"
        echo ""
        echo "Commands:"
        echo "  status    Show status (default)"
        echo "  ping      Test connectivity"
        echo "  restart   Restart service"
        echo "  help      Show this help"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use 'oatailscale help' for usage"
        ;;
esac
EOF
    chmod +x "$UTIL_SCRIPT_DIR/oatailscale"
    print_status "success" "Created oatailscale utility"
fi

echo ""
print_section "TAILSCALE SETUP COMPLETE"
print_status "success" "Configuration finished successfully"
echo ""
echo "🎯 Next steps:"
echo "• Use 'oatailscale' to check status"
echo "• Device should appear in Tailscale admin console"
echo "• Test connectivity from other devices on your tailnet"
