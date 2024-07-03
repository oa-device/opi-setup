#!/bin/bash

source "$(dirname "$(readlink -f "$0")")/../helpers.sh" || {
	echo "Error: Could not source helpers.sh"
	exit 1
}

echo "---------- SETTING UP FIREWALL ----------"

install_ufw() {
	if ! command -v ufw &>/dev/null; then
		echo "Installing UFW..."
		sudo apt update
		sudo apt install ufw -y
		echo "UFW installed!"
	else
		echo "UFW is already installed!"
	fi
}

set_default_policies() {
	if [[ $(sudo ufw status verbose | grep -c "Default: deny (incoming), allow (outgoing)") -eq 0 ]]; then
		printf "y\n" | sudo ufw default deny incoming &>/dev/null
		printf "y\n" | sudo ufw default allow outgoing &>/dev/null
	fi
	print_color "green" "Default policies set:"
	print_color "yellow" "- Incoming: denied (prevents unauthorized access)"
	print_color "yellow" "- Outgoing: allowed (ensures device can access external services)"
}

set_firewall_rules() {
	local rules=("22/tcp" "80/tcp" "443" "41641/udp" "3478/udp")
	local rule_explanations=("SSH access" "HTTP access" "HTTPS/WebSocket access" "Tailscale direct connection" "STUN protocol")

	for i in "${!rules[@]}"; do
		local rule="${rules[$i]}"
		local explanation="${rule_explanations[$i]}"
		if [[ $(sudo ufw status | grep -c "${rule}") -eq 0 ]]; then
			printf "y\n" | sudo ufw allow "$rule" &>/dev/null
			printf -v output "Rule added: %-15s (%s)" "$rule" "$explanation"
			print_color "green" "$output"
		else
			printf -v output "Rule existed: %-15s (%s)" "$rule" "$explanation"
			print_color "yellow" "$output"
		fi
	done
}

set_rate_limiting() {
	if [[ $(sudo ufw status | grep -c "22/tcp (LIMIT)") -eq 0 ]]; then
		printf "y\n" | sudo ufw limit 22/tcp &>/dev/null
		print_color "green" "Rate limiting set for SSH (port 22)."
	else
		print_color "yellow" "Rate limiting already set for SSH (port 22)."
	fi
}

remove_ipv6_rules() {
	local ipv6_rules
	ipv6_rules=$(sudo ufw status numbered | grep '(v6)' | awk -F'[][]' '{print $2}' | tac)

	for rule_num in $ipv6_rules; do
		sudo ufw --force delete "$rule_num" &>/dev/null
	done

	print_color "green" "All IPv6 rules have been removed."
}

enable_ufw() {
	if [[ $(sudo ufw status | grep -c "Status: active") -eq 0 ]]; then
		printf "y\n" | sudo ufw enable &>/dev/null
		print_color "green" "\e[1mUFW enabled!\e[0m"
	else
		print_color "green" "UFW is already enabled!"
	fi
}

enable_logging() {
	sudo ufw logging on &>/dev/null
	print_color "green" "UFW logging enabled."
}

print_current_rules() {
	print_color "yellow" "---------- CURRENT FIREWALL RULES ----------"
	sudo ufw status verbose | while IFS= read -r line; do
		print_color "green" "${line}"
	done
}

# Main Execution
install_ufw
set_default_policies
set_firewall_rules
set_rate_limiting
remove_ipv6_rules
enable_logging
enable_ufw
print_current_rules

echo "---------- FIREWALL SETUP COMPLETE ----------"
