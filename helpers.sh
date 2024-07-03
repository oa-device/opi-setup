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
