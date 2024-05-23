# Define the root directory for the Orangead projects
ORANGEAD_ROOT_DIR="$HOME/Orangead"

# Define the root directory for the player project
PLAYER_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define other directories relative to the player root directory
PLAYER_RELEASES_DIR="$PLAYER_ROOT_DIR/releases"
PLAYER_LOGS_DIR="$PLAYER_ROOT_DIR/logs"
PLAYER_CONFIG_DIR="$PLAYER_ROOT_DIR/config"
PLAYER_INIT_SCRIPTS_DIR="$PLAYER_ROOT_DIR/init-scripts"
PLAYER_SYSTEMD_DIR="$PLAYER_ROOT_DIR/systemd"
PLAYER_UTIL_SCRIPTS_DIR="$PLAYER_ROOT_DIR/util-scripts"

# Function to replace placeholders in service files
replace_placeholders() {
	local service_file=$1
	sudo sed -i "s|%PLAYER_ROOT_DIR%|$PLAYER_ROOT_DIR|g" "$service_file"
	sudo sed -i "s|%PLAYER_RELEASES_DIR%|$PLAYER_RELEASES_DIR|g" "$service_file"
	sudo sed -i "s|%PLAYER_LOGS_DIR%|$PLAYER_LOGS_DIR|g" "$service_file"
	sudo sed -i "s|%PLAYER_CONFIG_DIR%|$PLAYER_CONFIG_DIR|g" "$service_file"
	sudo sed -i "s|%PLAYER_INIT_SCRIPTS_DIR%|$PLAYER_INIT_SCRIPTS_DIR|g" "$service_file"
	sudo sed -i "s|%PLAYER_SYSTEMD_DIR%|$PLAYER_SYSTEMD_DIR|g" "$service_file"
	sudo sed -i "s|%PLAYER_UTIL_SCRIPTS_DIR%|$PLAYER_UTIL_SCRIPTS_DIR|g" "$service_file"
}

# Function to print the status of the service
print_service_status() {
	local service_name=$1
	local active_state
	local sub_state

	active_state=$(systemctl show -p ActiveState --value "$service_name")
	sub_state=$(systemctl show -p SubState --value "$service_name")

	echo "$service_name is $active_state ($sub_state)"
}
