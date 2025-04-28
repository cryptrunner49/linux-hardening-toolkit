#!/bin/bash

set -e

VERSION="0.0.1"
SCRIPT_NAME=$(basename "$0")

# Detect distro and version
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu)
                DISTRO="ubuntu"
                VERSION_ID="${VERSION_ID%%.*}" # extract major version
                ;;
            debian)
                DISTRO="debian"
                ;;
            fedora)
                DISTRO="fedora"
                ;;
            *)
                echo "Unsupported distribution: $ID"
                exit 1
                ;;
        esac
    else
        echo "Cannot detect distribution."
        exit 1
    fi
}

# Set permissions for cron files
setup_permissions() {
    echo "Setting secure permissions on cron and at files..."
    sudo chmod 700 /etc/crontab
    sudo chmod 700 /etc/at.deny
    sudo chmod 700 /etc/cron.deny
    sudo chmod 700 /etc/cron.d
    sudo chmod 700 /etc/cron.daily
    sudo chmod 700 /etc/cron.hourly
    sudo chmod 700 /etc/cron.weekly
    sudo chmod 700 /etc/cron.monthly
}

# Copy sysctl security settings
copy_sysctl_config() {
    echo "Copying local-security.conf to /etc/sysctl.d/..."
    if [ -f ./local-security.conf ]; then
        sudo cp ./local-security.conf /etc/sysctl.d/local-security.conf
    else
        echo "Error: local-security.conf not found in current directory."
        exit 1
    fi
}

# Update limits.conf
update_limits_conf() {
    echo "Updating /etc/security/limits.conf..."
    local FILE="/etc/security/limits.conf"
    grep -qxF "* hard core 0" "$FILE" || echo "* hard core 0" | sudo tee -a "$FILE"
    grep -qxF "* soft core 0" "$FILE" || echo "* soft core 0" | sudo tee -a "$FILE"
}

# Install security packages
install_packages() {
    detect_distro

    echo "Installing packages for $DISTRO..."

    if [ "$DISTRO" = "fedora" ]; then
        sudo dnf autoremove -y
        sudo dnf install -y setools policycoreutils policycoreutils-python-utils setroubleshoot firejail \
                            chkrootkit rkhunter torbrowser-launcher proxychains-ng nmap git htop jq \
                            wireshark tcpdump aide suricata zeek-core zeekctl

    elif [ "$DISTRO" = "ubuntu" ]; then
        sudo apt update
        sudo apt autopurge -y
        
        # Add Zeek repository
        echo "Adding Zeek repository for Ubuntu..."
        echo "deb https://download.opensuse.org/repositories/security:/zeek/xUbuntu_${VERSION_ID}.04/ /" | sudo tee /etc/apt/sources.list.d/security:zeek.list
        curl -fsSL https://download.opensuse.org/repositories/security:zeek/xUbuntu_${VERSION_ID}.04/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/security_zeek.gpg > /dev/null
        
        sudo apt update
        sudo apt install -y apt-show-versions debsums firejail apparmor apparmor-profiles apparmor-profiles-extra apparmor-utils \
                            chkrootkit rkhunter tor torbrowser-launcher proxychains-ng nmap git htop jq \
                            wireshark tcpdump aide suricata zeek
        sudo aa-enforce /etc/apparmor.d/*
        sudo apt autopurge -y

    elif [ "$DISTRO" = "debian" ]; then
        sudo apt update
        sudo apt autopurge -y

        # Add Zeek repo manually if needed (assume Debian 12/11 behaves like Ubuntu 22.04 for Zeek)
        echo "Adding Zeek repository for Debian..."
        echo "deb https://download.opensuse.org/repositories/security:/zeek/xUbuntu_22.04/ /" | sudo tee /etc/apt/sources.list.d/security:zeek.list
        curl -fsSL https://download.opensuse.org/repositories/security:zeek/xUbuntu_22.04/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/security_zeek.gpg > /dev/null

        sudo apt update
        sudo apt install -y apt-show-versions debsums firejail apparmor apparmor-profiles apparmor-profiles-extra apparmor-utils \
                            chkrootkit rkhunter tor torbrowser-launcher proxychains-ng nmap git htop jq \
                            wireshark tcpdump aide suricata zeek
        sudo aa-enforce /etc/apparmor.d/*
        sudo apt autopurge -y
    fi
}

# Disable unnecessary services
disable_services() {
    echo "Disabling unnecessary system services..."
    local services=(
        abrtd kdump kea dnsmasq
        cups.socket cups.path cups cups-browsed
        avahi-daemon.socket avahi-daemon
        samba smb kerneloops wpa_supplicant
    )
    for service in "${services[@]}"; do
        sudo systemctl stop "$service" 2>/dev/null || true
        sudo systemctl disable "$service" 2>/dev/null || true
    done
}

# Block unused kernel modules
block_modules() {
    echo "Blocking unused kernel modules..."
    local blacklist_file="/etc/modprobe.d/blacklist-custom.conf"
    sudo touch "$blacklist_file"
    local modules=(dccp sctp rds tipc)
    for module in "${modules[@]}"; do
        grep -qxF "blacklist $module" "$blacklist_file" || echo "blacklist $module" | sudo tee -a "$blacklist_file"
    done
}

# Print usage
usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Options:
  --all                Run all hardening tasks
  --permissions        Set permissions on cron and at files
  --sysctl             Copy local security sysctl config
  --limits             Add '* hard core 0' and '* soft core 0' to limits.conf
  --install            Install security packages
  --services           Disable unnecessary system services
  --modules            Block unused kernel modules
  -h, --help           Show this help message
  -v, --version        Show version information
EOF
}

# Main dispatcher
main() {
    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi

    while [ "$1" != "" ]; do
        case "$1" in
            --all)
                setup_permissions
                copy_sysctl_config
                update_limits_conf
                install_packages
                disable_services
                block_modules
                ;;
            --permissions)
                setup_permissions
                ;;
            --sysctl)
                copy_sysctl_config
                ;;
            --limits)
                update_limits_conf
                ;;
            --install)
                install_packages
                ;;
            --services)
                disable_services
                ;;
            --modules)
                block_modules
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -v|--version)
                echo "$SCRIPT_NAME version $VERSION"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
        shift
    done
}

main "$@"
