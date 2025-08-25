#!/bin/bash

source "$(dirname "$(readlink -f "$0")")/../helpers.sh" || {
    echo "Error: Could not source helpers.sh"
    exit 1
}

echo "---------- SETTING UP HEALTH CHECK API ----------"

API_DIR="$ORANGEAD_ROOT_DIR/oaDeviceAPI"
VENV_DIR="$API_DIR/.venv"

# Function to check if a package is installed
is_package_installed() {
    dpkg -l "$1" &>/dev/null
}

# Function to check if Python package is installed in venv with correct version
is_python_package_installed() {
    local package=$1
    if [ ! -f "$VENV_DIR/bin/pip" ]; then
        echo "Debug: pip not found in venv"
        return 1
    fi
    
    # Convert package name to lowercase for comparison
    local package_lower=$(echo "$package" | tr '[:upper:]' '[:lower:]')
    
    # Get installed packages in lowercase
    local installed_packages
    installed_packages=$("$VENV_DIR/bin/pip" freeze | tr '[:upper:]' '[:lower:]')
    
    # Check if package exists (case-insensitive)
    if echo "$installed_packages" | grep -q "^${package_lower}=="; then
        return 0
    else
        echo "Debug: Package $package not found"
        return 1
    fi
}

# Function to install system dependencies
install_system_dependencies() {
    local packages=("gnome-screenshot" "dbus-x11" "python3-venv" "python3-pip" "python3-pillow")
    local need_install=0
    
    for pkg in "${packages[@]}"; do
        if ! is_package_installed "$pkg"; then
            need_install=1
            echo "Package $pkg needs to be installed"
        fi
    done
    
    if [ $need_install -eq 1 ]; then
        echo "Installing required system packages..."
        sudo apt-get update
        sudo apt-get install -y "${packages[@]}"
    else
        echo "All required system packages are already installed!"
    fi
}

# Function to set up Python environment
setup_python_environment() {
    # Create API directory if it doesn't exist
    mkdir -p "$API_DIR"
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "$VENV_DIR" ]; then
        echo "Creating Python virtual environment..."
        python3 -m venv "$VENV_DIR"
        "$VENV_DIR/bin/python" -m pip install --upgrade pip
    else
        echo "Virtual environment already exists"
    fi
    
    # Get list of required packages
    local required_packages=()
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        # Extract package name without version and trim whitespace
        package=$(echo "${line%[>=<]*}" | tr -d '[:space:]')
        [ -n "$package" ] && required_packages+=("$package")
    done < "$API_DIR/requirements.txt"
    
    # Check if any package needs to be installed
    local need_install=0
    local missing_packages=()
    
    for package in "${required_packages[@]}"; do
        if ! is_python_package_installed "$package"; then
            need_install=1
            missing_packages+=("$package")
        fi
    done
    
    if [ $need_install -eq 1 ]; then
        echo "Installing Python dependencies..."
        "$VENV_DIR/bin/pip" install -r "$API_DIR/requirements.txt"
    else
        echo "All Python dependencies are already installed!"
    fi
}

# Function to set up screenshots directory
setup_screenshots_dir() {
    if [ ! -d "/tmp/screenshots" ]; then
        echo "Setting up screenshots directory..."
        mkdir -p /tmp/screenshots
    fi
}

# Function to set up and start service
setup_service() {
    echo "Setting up systemd service..."
    sudo systemctl daemon-reload
    
    if ! systemctl is-enabled health-check-api.service &>/dev/null; then
        echo "Enabling health-check-api service..."
        sudo systemctl enable health-check-api.service
    fi
    
    echo "Restarting health-check-api service..."
    sudo systemctl restart health-check-api.service
    sleep 2  # Wait for service to start
    
    # Check service status
    if ! systemctl is-active health-check-api.service &>/dev/null; then
        echo "Service failed to start. Check logs at: $PLAYER_LOGS_DIR/health_check_api.log"
    else
        echo "Health Check API service is running"
    fi
}

# Main execution
install_system_dependencies
setup_python_environment
setup_screenshots_dir
setup_service

echo "---------- HEALTH CHECK API SETUP COMPLETE ----------" 