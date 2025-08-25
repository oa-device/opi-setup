#!/bin/bash

# Function to log messages both to the terminal and the log file
log_message() {
    local log_file=$1
    local level=$2
    local message=$3
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $level: $message" | tee -a "$log_file"
}

# Function to log errors
log_error() {
    log_message "$1" "ERROR" "$2"
}

# Function to log info
log_info() {
    log_message "$1" "INFO" "$2"
}

# Specialized logging functions for unified API operations
log_unified_api() {
    local level="$1"
    local message="$2"
    local log_file="${3:-$OASYNC_LOG_FILE}"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local hostname=$(hostname)
    
    echo "[$timestamp] [$hostname] [UNIFIED-API] [$level] $message" >> "$log_file"
}

log_api_info() {
    log_unified_api "INFO" "$1" "$2"
}

log_api_warn() {
    log_unified_api "WARN" "$1" "$2"
}

log_api_error() {
    log_unified_api "ERROR" "$1" "$2"
}

log_api_debug() {
    if [ "$API_LOG_LEVEL" = "DEBUG" ]; then
        log_unified_api "DEBUG" "$1" "$2"
    fi
}

# Function to log device detection results
log_device_detection() {
    local log_file="${1:-$OASYNC_LOG_FILE}"
    
    log_api_debug "=== DEVICE DETECTION ANALYSIS ===" "$log_file"
    log_api_debug "Hostname: $(hostname)" "$log_file"
    log_api_debug "User: $USER" "$log_file"
    log_api_debug "PWD: $PWD" "$log_file"
    log_api_debug "System: $(uname -s)" "$log_file"
    log_api_debug "Kernel: $(uname -r)" "$log_file"
    log_api_debug "ORANGEAD_ROOT_DIR: $ORANGEAD_ROOT_DIR" "$log_file"
    
    # Primary detection: Device tree model
    if [ -f "/sys/firmware/devicetree/base/model" ]; then
        local device_model=$(cat /sys/firmware/devicetree/base/model 2>/dev/null | tr -d '\0')
        log_api_debug "Device Tree Model: $device_model" "$log_file"
        if echo "$device_model" | grep -qi "orange.*pi"; then
            log_api_debug "Device Tree Detection: POSITIVE (Orange Pi found)" "$log_file"
        else
            log_api_debug "Device Tree Detection: NEGATIVE (Orange Pi not found)" "$log_file"
        fi
    else
        log_api_debug "Device Tree Model: NOT AVAILABLE" "$log_file"
    fi
    
    # Secondary detection: OrangeAd environment
    log_api_debug "User check: $USER == orangepi? $([[ "$USER" == "orangepi" ]] && echo 'YES' || echo 'NO')" "$log_file"
    log_api_debug "Orangead directory: $HOME/Orangead exists? $([ -d "$HOME/Orangead" ] && echo 'YES' || echo 'NO')" "$log_file"
    if [[ "$USER" == "orangepi" ]] && [ -d "$HOME/Orangead" ]; then
        log_api_debug "OrangeAd Environment Detection: POSITIVE (orangepi user + Orangead dir)" "$log_file"
    else
        log_api_debug "OrangeAd Environment Detection: NEGATIVE" "$log_file"
    fi
    
    # Tertiary detection: Rockchip + orangepi compatible
    if uname -r | grep -q "rockchip"; then
        log_api_debug "Rockchip Kernel: YES" "$log_file"
        if [ -f "/sys/firmware/devicetree/base/compatible" ]; then
            local compatible=$(cat /sys/firmware/devicetree/base/compatible 2>/dev/null | tr -d '\0')
            log_api_debug "Device Tree Compatible: $compatible" "$log_file"
            if echo "$compatible" | grep -qi "orangepi"; then
                log_api_debug "Rockchip+OrangePi Detection: POSITIVE" "$log_file"
            else
                log_api_debug "Rockchip+OrangePi Detection: NEGATIVE (no orangepi in compatible)" "$log_file"
            fi
        else
            log_api_debug "Rockchip+OrangePi Detection: NEGATIVE (no compatible file)" "$log_file"
        fi
    else
        log_api_debug "Rockchip Kernel: NO" "$log_file"
    fi
    
    # Legacy detection
    local legacy_markers=""
    [ -d "/opt/orangead" ] && legacy_markers="$legacy_markers /opt/orangead"
    [ -f "/etc/orangead-device" ] && legacy_markers="$legacy_markers /etc/orangead-device"
    [[ "$USER" == "orangead" ]] && legacy_markers="$legacy_markers user:orangead"
    
    if [ -n "$legacy_markers" ]; then
        log_api_debug "Legacy Detection: POSITIVE ($legacy_markers)" "$log_file"
    else
        log_api_debug "Legacy Detection: NEGATIVE" "$log_file"
    fi
    
    # Final result
    if is_orangead_device; then
        log_api_info "FINAL DETECTION RESULT: DEVICE ENVIRONMENT" "$log_file"
    else
        log_api_info "FINAL DETECTION RESULT: DEVELOPMENT ENVIRONMENT" "$log_file"
    fi
    log_api_debug "=== END DEVICE DETECTION ===" "$log_file"
}