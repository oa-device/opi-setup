#!/bin/bash

# Function to print messages in color
print_color() {
	if [ $# -eq 1 ]; then
		# If only one argument is passed, print without color
		echo -e "$1"
	else
		local color=$1
		local text=$2
		case $color in
		"red")
			echo -e "\033[31m${text}\033[0m"
			;;
		"green")
			echo -e "\033[32m${text}\033[0m"
			;;
		"yellow")
			echo -e "\033[33m${text}\033[0m"
			;;
		*)
			echo -e "${text}"
			;;
		esac
	fi
}

# Function to print section headers for clarity in bold yellow text
print_section() {
	print_color "yellow" "\n\e[1m========== $1 ==========\e[0m"
}
