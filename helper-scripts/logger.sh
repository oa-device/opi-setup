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
