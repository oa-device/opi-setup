#!/bin/bash

# Define the hostname of the machine
HOSTNAME=$(hostname)

# Define the root directory for the Orangead projects
ORANGEAD_ROOT_DIR="$HOME/Orangead"

# Define the root directory for the player project
PLAYER_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define other directories relative to the player root directory
PLAYER_RELEASES_DIR="$PLAYER_ROOT_DIR/releases"
PLAYER_LOGS_DIR="$PLAYER_ROOT_DIR/logs"
PLAYER_CONFIG_DIR="$PLAYER_ROOT_DIR/config"
PLAYER_SYSTEMD_DIR="$PLAYER_ROOT_DIR/systemd"
PLAYER_INIT_SCRIPTS_DIR="$PLAYER_ROOT_DIR/init-scripts"
PLAYER_UTIL_SCRIPTS_DIR="$PLAYER_ROOT_DIR/util-scripts"
PLAYER_HELPER_SCRIPTS_DIR="$PLAYER_ROOT_DIR/helper-scripts"

# Function to source all scripts in the helper-scripts directory
source_helper_scripts() {
	for script in "$PLAYER_HELPER_SCRIPTS_DIR"/*.sh; do
		if [ -f "$script" ]; then
			source "$script" || {
				echo "Error: Could not source $script"
				exit 1
			}
		fi
	done
}
source_helper_scripts

# Load unified API configuration
load_unified_api_config() {
    local config_file="$PLAYER_CONFIG_DIR/unified_api.conf"
    if [ -f "$config_file" ]; then
        source "$config_file"
    fi
}

# ========================================
# DEVICE DETECTION & ENVIRONMENT FLAGS
# ========================================

# Function to detect if running on an actual OrangePi device
is_orangead_device() {
    # Primary detection: Orange Pi device tree model
    if [ -f "/sys/firmware/devicetree/base/model" ]; then
        local device_model=$(cat /sys/firmware/devicetree/base/model 2>/dev/null | tr -d '\0')
        if echo "$device_model" | grep -qi "orange.*pi"; then
            return 0  # true - this is an Orange Pi device
        fi
    fi
    
    # Secondary detection: OrangeAd deployment environment
    # User is 'orangepi' AND has Orangead project directory
    if [[ "$USER" == "orangepi" ]] && [ -d "$HOME/Orangead" ]; then
        return 0  # true - this is an OrangeAd device environment
    fi
    
    # Tertiary detection: Rockchip kernel with orangepi compatible string
    if uname -r | grep -q "rockchip"; then
        if [ -f "/sys/firmware/devicetree/base/compatible" ]; then
            local compatible=$(cat /sys/firmware/devicetree/base/compatible 2>/dev/null | tr -d '\0')
            if echo "$compatible" | grep -qi "orangepi"; then
                return 0  # true - this is an Orange Pi device
            fi
        fi
    fi
    
    # Legacy detection for backwards compatibility
    if [ -d "/opt/orangead" ] || 
       [ -f "/etc/orangead-device" ] ||
       [[ "$USER" == "orangead" ]]; then
        return 0  # true - legacy orangead markers
    fi
    
    return 1  # false - this is development environment
}

# Function to check if we should manage oaDeviceAPI
should_manage_device_api() {
    # Load configuration first
    load_unified_api_config
    
    # Check emergency disable first
    if [ "$EMERGENCY_DISABLE" = "true" ]; then
        return 1  # disabled by emergency flag
    fi
    
    # Only manage on actual devices, not in development
    if is_orangead_device; then
        # Check rollout stage
        case "$ROLLOUT_STAGE" in
            disabled)
                return 1  # disabled
                ;;
            pilot)
                # Enable for dev branch or force flag
                if [ "$FORCE_UNIFIED_API" = "true" ] || [ "$(git symbolic-ref --short HEAD 2>/dev/null)" = "dev" ]; then
                    return 0  # enabled for pilot
                else
                    return 1  # not in pilot
                fi
                ;;
            production)
                # Check if enabled (default true unless explicitly disabled)
                if [ "$ENABLE_UNIFIED_API" != "false" ]; then
                    return 0  # enabled for production
                else
                    return 1  # disabled
                fi
                ;;
            *)
                # Default behavior - check legacy files
                local feature_flag_file="$PLAYER_CONFIG_DIR/enable_unified_api"
                if [ -f "$feature_flag_file" ] || [ "$FORCE_UNIFIED_API" = "true" ]; then
                    return 0  # true - manage device API
                elif [ ! -f "$PLAYER_CONFIG_DIR/disable_unified_api" ]; then
                    return 0  # true - manage device API (default enabled)
                fi
                ;;
        esac
    fi
    return 1  # false - skip device API management
}

# Function to get device API directory
get_device_api_dir() {
    echo "$ORANGEAD_ROOT_DIR/oaDeviceAPI"
}

# Function to check if device API is available
is_device_api_available() {
    local api_dir=$(get_device_api_dir)
    [ -d "$api_dir" ] && [ -f "$api_dir/main.py" ]
}