#!/bin/bash

source "$(dirname "$(readlink -f "$0")")/../helpers.sh" || {
    echo "Error: Could not source helpers.sh"
    exit 1
}

echo "---------- SETTING UP FIREWALL ----------"

# Check if UFW is installed
if ! command -v ufw &>/dev/null; then
	echo "Installing UFW..."
	sudo apt update
	sudo apt install ufw -y
	echo "UFW installed!"
else
	echo "UFW is already installed!"
fi

# Set default policies if not set
if [[ $(sudo ufw status verbose | grep -c "Default: deny (incoming), allow (outgoing)") -eq 0 ]]; then
	printf "y\n" | sudo ufw default deny incoming &>/dev/null
	printf "y\n" | sudo ufw default allow outgoing &>/dev/null
fi
print_color "green" "Default policies set:"
print_color "yellow" "- Incoming: denied (prevents unauthorized access)"
print_color "yellow" "- Outgoing: allowed (ensures device can access external services)"

# Check and set rules if not already set
rules=("22/tcp" "80/tcp" "443" "41641")
rule_explanations=("SSH access" "HTTP access" "HTTPS access" "Tailscale access")

for i in "${!rules[@]}"; do
	rule="${rules[$i]}"
	explanation="${rule_explanations[$i]}"
	if [[ $(sudo ufw status | grep -c "${rule}") -eq 0 ]]; then
		printf "y\n" | sudo ufw allow $rule &>/dev/null
		print_color "green" "Rule added: $rule \t ($explanation)"
	else
		print_color "yellow" "Rule existed: $rule \t ($explanation)"
	fi
done

# Enable UFW if not already enabled
if [[ $(sudo ufw status | grep -c "Status: active") -eq 0 ]]; then
	printf "y\n" | sudo ufw enable &>/dev/null
fi
print_color "green" "\e[1mUFW enabled!\e[0m"

# Print the current rules
print_color "yellow" "---------- CURRENT FIREWALL RULES ----------"
sudo ufw status verbose numbered | while IFS= read -r line; do
	print_color "green" "${line}"
done

echo "---------- FIREWALL SETUP COMPLETE ----------"
