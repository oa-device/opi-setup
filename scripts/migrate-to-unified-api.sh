#!/bin/bash
# Migration script for opi-setup to use unified oaDeviceAPI
# This script migrates from embedded API to unified oaDeviceAPI submodule

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPI_SETUP_ROOT="$(dirname "$SCRIPT_DIR")"
UNIFIED_API_DIR="$OPI_SETUP_ROOT/oaDeviceAPI"
LEGACY_API_DIR="$OPI_SETUP_ROOT/api"
SERVICE_NAME="health-check-api.service"
SYSTEMD_DIR="/etc/systemd/system"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        exit 1
    fi
}

# Backup current configuration
backup_current_setup() {
    local backup_dir="$OPI_SETUP_ROOT/backup-$(date +%Y%m%d-%H%M%S)"
    
    log_info "Creating backup at $backup_dir"
    mkdir -p "$backup_dir"
    
    # Backup legacy API if it exists
    if [[ -d "$LEGACY_API_DIR" ]]; then
        cp -r "$LEGACY_API_DIR" "$backup_dir/api-legacy"
        log_success "Legacy API backed up"
    fi
    
    # Backup systemd service
    if [[ -f "$SYSTEMD_DIR/$SERVICE_NAME" ]]; then
        sudo cp "$SYSTEMD_DIR/$SERVICE_NAME" "$backup_dir/$SERVICE_NAME.backup"
        log_success "Systemd service backed up"
    fi
    
    echo "$backup_dir"
}

# Stop existing services
stop_legacy_services() {
    log_info "Stopping legacy services"
    
    if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
        sudo systemctl stop "$SERVICE_NAME"
        log_success "Legacy health-check-api service stopped"
    else
        log_warning "Legacy service was not running"
    fi
}

# Setup unified API
setup_unified_api() {
    log_info "Setting up unified oaDeviceAPI"
    
    # Clone or update unified API
    if [[ ! -d "$UNIFIED_API_DIR" ]]; then
        log_info "Cloning oaDeviceAPI repository"
        git clone https://github.com/oa-device/oaDeviceAPI.git "$UNIFIED_API_DIR"
    else
        log_info "Updating existing oaDeviceAPI repository"
        cd "$UNIFIED_API_DIR"
        git pull origin main
        cd "$OPI_SETUP_ROOT"
    fi
    
    # Install Python dependencies
    log_info "Installing Python dependencies"
    if command -v python3 >/dev/null 2>&1; then
        cd "$UNIFIED_API_DIR"
        python3 -m pip install -r requirements.txt --user
        cd "$OPI_SETUP_ROOT"
        log_success "Dependencies installed"
    else
        log_error "Python3 not found. Please install Python3 first."
        exit 1
    fi
}

# Configure environment
configure_environment() {
    log_info "Configuring environment for OrangePi"
    
    # Create .env file for unified API
    cat > "$UNIFIED_API_DIR/.env" << EOF
# oaDeviceAPI Configuration for OrangePi
OAAPI_HOST=0.0.0.0
OAAPI_PORT=9090
TAILSCALE_SUBNET=100.64.0.0/10
LOG_LEVEL=INFO

# OrangePi specific settings
SCREENSHOT_DIR=/tmp/screenshots
ORANGEPI_DISPLAY_CONFIG=/etc/orangead/display.conf
ORANGEPI_PLAYER_SERVICE=slideshow-player.service

# Platform override (auto-detection should work, but can be forced)
# PLATFORM_OVERRIDE=orangepi
EOF

    # Create screenshots directory
    mkdir -p /tmp/screenshots
    chmod 755 /tmp/screenshots
    
    log_success "Environment configured"
}

# Update systemd service
update_systemd_service() {
    log_info "Updating systemd service configuration"
    
    # Create updated systemd service
    sudo tee "$SYSTEMD_DIR/$SERVICE_NAME" > /dev/null << EOF
[Unit]
Description=OrangeAd Unified Device API (OrangePi)
After=network.target
Wants=network.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$UNIFIED_API_DIR
ExecStart=/usr/bin/python3 $UNIFIED_API_DIR/main.py
EnvironmentFile=$UNIFIED_API_DIR/.env

# Logging
StandardOutput=append:$UNIFIED_API_DIR/logs/deviceapi.log
StandardError=append:$UNIFIED_API_DIR/logs/deviceapi_error.log

# Create logs directory if it doesn't exist
ExecStartPre=/bin/mkdir -p $UNIFIED_API_DIR/logs
ExecStartPre=/bin/chown $USER:$USER $UNIFIED_API_DIR/logs

# Restart policy
Restart=always
RestartSec=10
StartLimitInterval=60
StartLimitBurst=3

# Security settings
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$UNIFIED_API_DIR/logs
ReadWritePaths=/tmp

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable service
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
    
    log_success "Systemd service updated"
}

# Start unified service
start_unified_service() {
    log_info "Starting unified Device API service"
    
    sudo systemctl start "$SERVICE_NAME"
    
    # Wait for service to be ready
    local retries=10
    local delay=3
    
    for ((i=1; i<=retries; i++)); do
        if curl -s http://localhost:9090/platform >/dev/null 2>&1; then
            log_success "Unified Device API service is running"
            return 0
        fi
        
        log_info "Waiting for service to start... (attempt $i/$retries)"
        sleep $delay
    done
    
    log_error "Service failed to start within expected time"
    return 1
}

# Validate migration
validate_migration() {
    log_info "Validating migration"
    
    # Check service status
    if ! sudo systemctl is-active --quiet "$SERVICE_NAME"; then
        log_error "Service is not active"
        return 1
    fi
    
    # Check API endpoints
    local health_response
    health_response=$(curl -s http://localhost:9090/health | jq -r '.status' 2>/dev/null || echo "error")
    
    if [[ "$health_response" == "online" ]]; then
        log_success "Health endpoint responding correctly"
    else
        log_error "Health endpoint not responding correctly"
        return 1
    fi
    
    # Check platform detection
    local platform_response
    platform_response=$(curl -s http://localhost:9090/platform | jq -r '.platform' 2>/dev/null || echo "unknown")
    
    if [[ "$platform_response" == "orangepi" ]]; then
        log_success "Platform detection working correctly"
    else
        log_warning "Platform detected as: $platform_response (expected: orangepi)"
    fi
    
    # Check OrangePi-specific endpoints
    if curl -s http://localhost:9090/screenshots/history >/dev/null 2>&1; then
        log_success "OrangePi-specific endpoints available"
    else
        log_warning "OrangePi-specific endpoints may not be working"
    fi
    
    return 0
}

# Cleanup legacy files (optional)
cleanup_legacy() {
    if [[ -d "$LEGACY_API_DIR" ]]; then
        log_info "Legacy API directory found at $LEGACY_API_DIR"
        read -p "Do you want to remove the legacy API directory? (y/N): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$LEGACY_API_DIR"
            log_success "Legacy API directory removed"
        else
            log_info "Legacy API directory kept for reference"
        fi
    fi
}

# Display migration summary
display_summary() {
    echo
    echo "=========================================="
    echo "      Migration Summary"
    echo "=========================================="
    echo "✅ Unified oaDeviceAPI deployed"
    echo "✅ Service configuration updated"  
    echo "✅ Environment configured for OrangePi"
    echo "✅ Service started and validated"
    echo
    echo "API Endpoints:"
    echo "  • Health: http://localhost:9090/health"
    echo "  • Platform: http://localhost:9090/platform"
    echo "  • Screenshots: http://localhost:9090/screenshots/*"
    echo "  • Actions: http://localhost:9090/actions/*"
    echo
    echo "Service Management:"
    echo "  • Status: sudo systemctl status $SERVICE_NAME"
    echo "  • Restart: sudo systemctl restart $SERVICE_NAME"
    echo "  • Logs: journalctl -u $SERVICE_NAME -f"
    echo
    echo "Configuration:"
    echo "  • Environment: $UNIFIED_API_DIR/.env"
    echo "  • Service: $SYSTEMD_DIR/$SERVICE_NAME"
    echo "  • API Code: $UNIFIED_API_DIR"
    echo "=========================================="
}

# Main execution
main() {
    log_info "Starting migration to unified oaDeviceAPI"
    
    check_root
    
    # Create backup
    local backup_dir
    backup_dir=$(backup_current_setup)
    
    # Stop legacy services
    stop_legacy_services
    
    # Setup unified API
    setup_unified_api
    configure_environment
    update_systemd_service
    
    # Start and validate
    if start_unified_service; then
        if validate_migration; then
            log_success "Migration completed successfully!"
            cleanup_legacy
            display_summary
        else
            log_error "Migration validation failed"
            log_info "Backup available at: $backup_dir"
            exit 1
        fi
    else
        log_error "Failed to start unified service"
        log_info "Backup available at: $backup_dir"
        exit 1
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi