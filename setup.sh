#!/bin/bash

source "$(dirname "$(readlink -f "$0")")/helpers.sh" || {
    echo "Error: Could not source helpers.sh"
    exit 1
}

configure_sudo_rights() {
    print_section "CONFIGURE SUDO RIGHTS FOR ORANGEPI USER"
    local binaries=(
        "/usr/bin/apt" "/usr/bin/apt-get" "/usr/bin/bash" "/usr/bin/curl"
        "/usr/bin/cp" "/usr/bin/growpart" "/usr/bin/mkdir" "/usr/bin/mv"
        "/usr/bin/nano" "/usr/bin/rm" "/usr/bin/sed" "/usr/bin/systemctl"
        "/usr/bin/tee" "/usr/bin/timedatectl" "/usr/sbin/chpasswd"
        "/usr/sbin/reboot" "/usr/sbin/resize2fs" "/usr/sbin/ufw"
    )
    local sudo_rights="orangepi ALL=(ALL) NOPASSWD: ${binaries[0]}"
    for binary in "${binaries[@]:1}"; do
        sudo_rights+=", $binary"
    done
    if [ -z "$(cat /etc/sudoers.d/orangepi 2>/dev/null)" ]; then
        echo "Sudo rights not yet configured for orangepi user. Configuring..."
        echo "$sudo_rights" | sudo tee /etc/sudoers.d/orangepi >/dev/null
        echo "Sudo rights granted for orangepi user."
    elif [ "$(cat /etc/sudoers.d/orangepi)" != "$sudo_rights" ]; then
        echo "Updating sudo rights for orangepi user..."
        echo "$sudo_rights" | sudo tee /etc/sudoers.d/orangepi >/dev/null
        echo "Sudo rights updated for orangepi user."
    else
        echo "Sudo rights already configured for orangepi user."
    fi
}

configure_path() {
    print_section "CONFIGURING PATH"
    if ! grep -q "export PATH=\"\$PATH:$PLAYER_UTIL_SCRIPTS_DIR\"" ~/.bashrc; then
        sed -i '/# If not running interactively, don'\''t do anything/i export PATH="$PATH:'"$PLAYER_UTIL_SCRIPTS_DIR"'"' ~/.bashrc
        echo -e "\033[1;31mThe PATH has been updated. \nPlease exit the terminal and ssh in again, or run '. ~/.bashrc' after this script finishes to apply the changes.\033[0m"
        [ -n "$SSH_TTY" ] && read -p "Press enter to continue" || echo "Non-interactive shell detected. Please manually source ~/.bashrc after the script completes."
    else
        echo "The PATH is already configured correctly."
    fi
}

change_default_password() {
    print_section "CHANGING DEFAULT PASSWORD"
    echo "orangepi:orangead" | sudo chpasswd
}

set_timezone() {
    print_section "SETTING TIMEZONE TO MONTREAL"
    sudo timedatectl set-timezone America/Montreal
    echo "Current timezone set to: $(timedatectl | grep 'Time zone' | awk '{print $3}')"
}

configure_display() {
    print_section "CONFIGURING DISPLAY"
    "$PLAYER_UTIL_SCRIPTS_DIR/display.sh"
}

configure_wifi() {
    print_section "CONFIGURING WIFI"
    "$PLAYER_UTIL_SCRIPTS_DIR/wifi.sh"
}

schedule_auto_update_and_reboot() {
    print_section "AUTO UPDATE AND REBOOT DAILY AT 3AM"
    echo "0 3 * * * $PLAYER_UTIL_SCRIPTS_DIR/oasync; /sbin/reboot" | crontab -
    echo "Current crontab setting:"
    crontab -l | sed 's/^/\t/'
}

setup_systemd_services() {
    print_section "SETTING UP SYSTEMD SERVICES"
    for service in "$PLAYER_SYSTEMD_DIR"/*.service; do
        local service_name=$(basename "$service")

        if [ -f "$service" ] && [[ "$service_name" != "slideshow-player.service" && "$service_name" != "chromium-log-monitor.service" ]]; then
            sudo cp "$service" /etc/systemd/system/
            replace_placeholders "/etc/systemd/system/$service_name"
            sudo systemctl daemon-reload
            sudo systemctl enable --now "$service_name"
            print_service_status "$service_name"
        fi
    done
}

disable_update_notifications() {
    print_section "DISABLING UPDATE NOTIFICATIONS"
    local gsettings_cmd="gsettings set com.ubuntu.update-notifier"
    $gsettings_cmd no-show-notifications true
    $gsettings_cmd show-apport-crashes false
    $gsettings_cmd show-livepatch-status-icon false
    $gsettings_cmd notify-ubuntu-advantage-available false
    $gsettings_cmd regular-auto-launch-interval 365

    gsettings set com.ubuntu.update-manager check-dist-upgrades false
    gsettings set com.ubuntu.update-manager check-new-release-ignore true
    gsettings set com.ubuntu.update-manager first-run false
    gsettings set com.ubuntu.update-manager show-details false
    gsettings set com.ubuntu.update-manager window-height 1
    gsettings set com.ubuntu.update-manager window-width 1

    # Remove update-manager from the list of applications that can show notifications
    local current_apps=$(gsettings get org.gnome.desktop.notifications application-children)
    if [[ $current_apps == "@as []" ]]; then
        echo "No applications in the notification list."
    else
        local new_apps=$(echo "$current_apps" | sed "s/'update-manager',*//g" | sed "s/,\s*,/,/g" | sed "s/^,\s*//g" | sed "s/,\s*$//g" | sed "s/^\[//g" | sed "s/\]$//g")
        if [[ -z "$new_apps" ]]; then
            gsettings set org.gnome.desktop.notifications application-children "[]"
        else
            gsettings set org.gnome.desktop.notifications application-children "[$new_apps]"
        fi
    fi

    sudo sed -i 's/^APT::Periodic::Update-Package-Lists "1";/APT::Periodic::Update-Package-Lists "0";/' /etc/apt/apt.conf.d/20auto-upgrades
    sudo sed -i 's/^APT::Periodic::Unattended-Upgrade "1";/APT::Periodic::Unattended-Upgrade "0";/' /etc/apt/apt.conf.d/20auto-upgrades
    sudo sed -i 's/^APT::Periodic::Update-Package-Lists "1";/APT::Periodic::Update-Package-Lists "0";/' /etc/apt/apt.conf.d/10periodic
    sudo sed -i 's/^APT::Periodic::Download-Upgradeable-Packages "1";/APT::Periodic::Download-Upgradeable-Packages "0";/' /etc/apt/apt.conf.d/10periodic
    sudo sed -i 's/^APT::Periodic::Unattended-Upgrade "1";/APT::Periodic::Unattended-Upgrade "0";/' /etc/apt/apt.conf.d/10periodic
    sudo sed -i 's/^APT::Periodic::AutocleanInterval "1";/APT::Periodic::AutocleanInterval "0";/' /etc/apt/apt.conf.d/10periodic

    sudo sed -i 's/^APT::Periodic::Enable ".*";/APT::Periodic::Enable "0";/' /etc/apt/apt.conf.d/02-orangepi-periodic
    sudo sed -i 's/^APT::Periodic::Update-Package-Lists ".*";/APT::Periodic::Update-Package-Lists "0";/' /etc/apt/apt.conf.d/02-orangepi-periodic
    sudo sed -i 's/^APT::Periodic::Unattended-Upgrade ".*";/APT::Periodic::Unattended-Upgrade "0";/' /etc/apt/apt.conf.d/02-orangepi-periodic
    sudo sed -i 's/^APT::Periodic::AutocleanInterval ".*";/APT::Periodic::AutocleanInterval "0";/' /etc/apt/apt.conf.d/02-orangepi-periodic

    sudo sed -i 's/^DPkg::Post-Invoke {/#&/' /etc/apt/apt.conf.d/99update-notifier
    sudo sed -i 's/^APT::Update::Post-Invoke-Success {/#&/' /etc/apt/apt.conf.d/99update-notifier

    # Replace the entire content of 50unattended-upgrades
    cat <<EOF | sudo tee /etc/apt/apt.conf.d/50unattended-upgrades >/dev/null
// Automatically upgrade packages from these (origin:archive) pairs
Unattended-Upgrade::Allowed-Origins {
    // "${distro_id}:${distro_codename}";
    // "${distro_id}:${distro_codename}-security";
    // "${distro_id}ESMApps:${distro_codename}-apps-security";
    // "${distro_id}ESM:${distro_codename}-infra-security";
};

// List of packages to not update (regexp are supported)
Unattended-Upgrade::Package-Blacklist {
    // "vim";
    // "libc6";
    // "libc6-dev";
    // "libc6-i686";
};

// This option controls whether the development release of Ubuntu will be
// upgraded automatically. Valid values are "true", "false", and "auto".
Unattended-Upgrade::DevRelease "false";

// Do automatic removal of unused packages after the upgrade
// (equivalent to apt-get autoremove)
Unattended-Upgrade::Remove-Unused-Kernel-Packages "false";
Unattended-Upgrade::Remove-New-Unused-Dependencies "false";
Unattended-Upgrade::Remove-Unused-Dependencies "false";

// Automatically reboot *WITHOUT CONFIRMATION* if
// the file /var/run/reboot-required is found after the upgrade
Unattended-Upgrade::Automatic-Reboot "false";

// Automatically reboot even if there are users currently logged in
// when Unattended-Upgrade::Automatic-Reboot is set to true
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";

// If automatic reboot is enabled and needed, reboot at the specific
// time instead of immediately
//Unattended-Upgrade::Automatic-Reboot-Time "02:00";

// Use apt bandwidth limit feature, this example limits the download
// speed to 70kb/sec
//Acquire::http::Dl-Limit "70";

// Enable logging to syslog. Default is False
Unattended-Upgrade::SyslogEnable "false";

// Specify syslog facility. Default is daemon
// Unattended-Upgrade::SyslogFacility "daemon";

// Download and install upgrades only on AC power
// (i.e. skip or gracefully stop updates on battery)
Unattended-Upgrade::OnlyOnACPower "false";

// Download and install upgrades only on non-metered connection
// (i.e. skip or gracefully stop updates on a metered connection)
Unattended-Upgrade::Skip-Updates-On-Metered-Connections "true";
EOF

    sudo systemctl disable update-notifier-download.timer
    sudo systemctl stop update-notifier-download.timer
    sudo systemctl disable update-notifier-motd.timer
    sudo systemctl stop update-notifier-motd.timer
    sudo systemctl disable apt-daily.timer
    sudo systemctl stop apt-daily.timer
    sudo systemctl disable apt-daily-upgrade.timer
    sudo systemctl stop apt-daily-upgrade.timer

    # Disable Ubuntu Pro messages
    sudo pro config set apt_news=false

    # Configure OrangePi MOTD
    sudo sed -i 's/^MOTD_DISABLE=".*"/MOTD_DISABLE="header tips updates"/' /etc/default/orangepi-motd
    sudo sed -i 's/^PRIMARY_DIRECTION=".*"/PRIMARY_DIRECTION="off"/' /etc/default/orangepi-motd

    echo "Update-manager settings:"
    gsettings list-recursively com.ubuntu.update-manager | sed 's/^/\t/'
    echo "Update-notifier settings:"
    gsettings list-recursively com.ubuntu.update-notifier | sed 's/^/\t/'
    echo "Current timer states:"
    systemctl list-timers --all --no-pager
    echo "OrangePi MOTD configuration:"
    grep -E '^MOTD_DISABLE=|^PRIMARY_DIRECTION=' /etc/default/orangepi-motd | sed 's/^/\t/'
    echo "50unattended-upgrades configuration:"
    grep -vE '^//|^[[:space:]]*$' /etc/apt/apt.conf.d/50unattended-upgrades | sed 's/^/\t/'
}

disable_gnome_notifications() {
    print_section "DISABLING GNOME NOTIFICATIONS"
    gsettings set org.gnome.desktop.notifications show-banners false
    gsettings set org.gnome.desktop.notifications show-in-lock-screen false

    # Disable specific application notifications
    local apps_to_disable=(
        'update-manager'
        'balena-etcher-electron'
        'org-gnome-nautilus'
        'gnome-network-panel'
        'org.gnome.Evolution-alarm-notify'
        'org.gnome.Calendar'
        'org.gnome.Software'
    )

    for app in "${apps_to_disable[@]}"; do
        gsettings set org.gnome.desktop.notifications.application:/org/gnome/desktop/notifications/application/$app/ enable false
    done

    # Update the application-children list
    local current_apps=$(gsettings get org.gnome.desktop.notifications application-children)
    if [[ $current_apps == "@as []" ]]; then
        echo "No applications in the notification list."
    else
        local new_apps=""
        for app in ${current_apps//,/ }; do
            if [[ ! " ${apps_to_disable[@]} " =~ " ${app//\'/} " ]]; then
                new_apps+="$app,"
            fi
        done
        new_apps=${new_apps%,} # Remove trailing comma
        if [[ -z "$new_apps" ]]; then
            gsettings set org.gnome.desktop.notifications application-children "[]"
        else
            gsettings set org.gnome.desktop.notifications application-children "[$new_apps]"
        fi
    fi

    # Disable network manager notifications
    gsettings set org.gnome.nm-applet disable-connected-notifications true
    gsettings set org.gnome.nm-applet disable-disconnected-notifications true
    gsettings set org.gnome.nm-applet disable-vpn-notifications true

    echo "GNOME notification settings:"
    gsettings list-recursively org.gnome.desktop.notifications | sed 's/^/\t/'
    echo "Network Manager notification settings:"
    gsettings list-recursively org.gnome.nm-applet | sed 's/^/\t/'
}

configure_gnome_settings() {
    print_section "CONFIGURING GNOME SETTINGS"
    rfkill block bluetooth
    gsettings set org.blueman.plugins.powermanager auto-power-on false
    local bluetooth_status=$(rfkill list bluetooth | grep -c "Soft blocked: yes")
    [ "$bluetooth_status" -gt 0 ] && echo "Bluetooth: off" || echo "Bluetooth: on"

    gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true
    local keyboard_status=$(gsettings get org.gnome.desktop.a11y.applications screen-keyboard-enabled)
    [ "$keyboard_status" = "true" ] && echo "On-screen keyboard: on" || echo "On-screen keyboard: off"

    gsettings set org.gnome.settings-daemon.plugins.power idle-dim false
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
    echo "Power settings:"
    gsettings list-recursively org.gnome.settings-daemon.plugins.power | sed 's/^/\t/'

    # Disable screen lock
    gsettings set org.gnome.desktop.screensaver lock-enabled false
    gsettings set org.gnome.desktop.lockdown disable-lock-screen true

    # Disable automatic suspend
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'

    # Disable screen dimming
    gsettings set org.gnome.settings-daemon.plugins.power idle-brightness 100

    echo "Screen lock and power management settings:"
    gsettings list-recursively org.gnome.desktop.screensaver | sed 's/^/\t/'
    gsettings list-recursively org.gnome.desktop.lockdown | sed 's/^/\t/'
    gsettings list-recursively org.gnome.settings-daemon.plugins.power | sed 's/^/\t/'
}

cleanup_keyring_files() {
    print_section "CLEANING UP KEYRING FILES"
    local keyring_dir="$HOME/.local/share/keyrings"
    find "$keyring_dir" -type f -name 'Default_keyring*.keyring' ! -name 'Default_keyring.keyring' -exec mv {} {}.bak \;
    echo "Current keyring files in the directory after cleanup:"
    ls "$keyring_dir" | grep 'Default_keyring*.keyring' | sed 's/^/\t/'
}

update_keyring_for_vnc() {
    print_section "UPDATING KEYRING FILE FOR VNC SETTINGS"
    local keyring_file="$HOME/.local/share/keyrings/Default_keyring.keyring"
    if [ -f "$keyring_file" ]; then
        local vnc_entry=$(grep "org.gnome.RemoteDesktop.VncPassword" "$keyring_file")

        if [[ -z "$vnc_entry" ]]; then
            local new_index=$(($(grep -oP "\[\K([0-9]+)(?=\])" "$keyring_file" | sort -nr | head -n1) + 1))
            echo -e "\n[${new_index}]\nitem-type=0\ndisplay-name=GNOME Remote Desktop VNC password\nsecret=orangead\n\n[${new_index}:attribute0]\nname=xdg:schema\ntype=string\nvalue=org.gnome.RemoteDesktop.VncPassword" >>"$keyring_file"
            echo "VNC entry added to the keyring file."
        elif ! grep -q "secret=orangead" <<<"$vnc_entry"; then
            local vnc_display_name_line=$(grep -n "display-name=GNOME Remote Desktop VNC password" "$keyring_file" | cut -d: -f1)
            local vnc_secret_line=$((vnc_display_name_line + 1))
            sed -i "${vnc_secret_line}s/secret=.*/secret=orangead/" "$keyring_file"
            echo "VNC entry updated in the keyring file."
        else
            echo "VNC entry is already up-to-date in the keyring file."
        fi
    else
        echo "Keyring file not found."
    fi
}

enable_gnome_remote_desktop_service() {
    print_section "ENABLE GNOME REMOTE DESKTOP SERVICE"
    systemctl --user enable gnome-remote-desktop
    systemctl --user start gnome-remote-desktop
    systemctl --user --no-pager status gnome-remote-desktop
}

enable_vnc() {
    print_section "ENABLE VNC"
    grdctl vnc enable
    grdctl vnc set-auth-method password
    grdctl vnc disable-view-only
    grdctl status --show-credentials
}

update_system() {
    print_section "UPDATING SYSTEM"
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update
    sudo apt-get upgrade --fix-missing -y -o Dpkg::Options::="--force-confnew"
}

install_required_packages() {
    print_section "INSTALLING REQUIRED PACKAGES"
    for script in "$PLAYER_INIT_SCRIPTS_DIR"/*.sh; do
        if [ -f "$script" ] && [ -x "$script" ]; then
            local relative_path="${script#$PLAYER_ROOT_DIR/}"
            echo "Executing $relative_path..."
            "$script"
        fi
    done
}

# Main Execution
configure_sudo_rights
configure_path
change_default_password
set_timezone
configure_display
configure_wifi
schedule_auto_update_and_reboot
setup_systemd_services
disable_update_notifications
disable_gnome_notifications
configure_gnome_settings
cleanup_keyring_files
update_keyring_for_vnc
enable_gnome_remote_desktop_service
enable_vnc
update_system
install_required_packages
print_section "SETUP COMPLETED"
