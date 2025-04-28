#!/usr/bin/env bash

set -euo pipefail

# Constants
VERSION="2.0.0"
SCRIPT_NAME=$(basename "$0")

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
NC="\e[0m"

LOG_FILE="/var/log/harden_linux.log"

ASSUME_YES=0
DRY_RUN=0

# Setup logging
exec > >(tee -a "$LOG_FILE") 2>&1

# Utility functions
print_success() { echo -e "${GREEN}[OK] $*${NC}"; }
print_error()   { echo -e "${RED}[ERROR] $*${NC}" >&2; }
print_warn()    { echo -e "${YELLOW}[WARN] $*${NC}"; }

backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        sudo cp "$file" "${file}.bak.$(date +%F_%T)"
        print_warn "Backup created: ${file}.bak.$(date +%F_%T)"
    fi
}

run_cmd() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[Dry-Run] %q ' "$@"
        echo
    else
        "$@"
    fi
}

ask_yes_no() {
    local prompt="$1"
    if [ "$ASSUME_YES" -eq 1 ]; then
        return 0
    fi
    read -rp "$prompt [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu)
                DISTRO="ubuntu"
                VERSION_ID="${VERSION_ID%%.*}"
                ;;
            debian)
                DISTRO="debian"
                ;;
            fedora)
                DISTRO="fedora"
                ;;
            *)
                print_error "Unsupported distribution: $ID"
                exit 1
                ;;
        esac
        print_success "Detected distro: $DISTRO"
    else
        print_error "Cannot detect distribution."
        exit 1
    fi
}

setup_permissions() {
    print_success "Setting secure permissions on cron and at files..."
    local files=(
        /etc/crontab
        /etc/at.deny
        /etc/cron.deny
        /etc/cron.d
        /etc/cron.daily
        /etc/cron.hourly
        /etc/cron.weekly
        /etc/cron.monthly
    )
    for file in "${files[@]}"; do
        [ -e "$file" ] && run_cmd "sudo chmod 700 \"$file\""
    done
}

copy_sysctl_config() {
    print_success "Copying local-security.conf to /etc/sysctl.d/..."
    if [ -f ./local-security.conf ]; then
        backup_file "/etc/sysctl.d/local-security.conf"
        run_cmd "sudo cp ./local-security.conf /etc/sysctl.d/local-security.conf"
        run_cmd "sudo sysctl --system"
    else
        print_error "local-security.conf not found."
        exit 1
    fi
}

update_limits_conf() {
    print_success "Updating /etc/security/limits.conf..."
    local FILE="/etc/security/limits.conf"
    backup_file "$FILE"

    grep -qxF "* hard core 0" "$FILE" || echo "* hard core 0" | sudo tee -a "$FILE" >/dev/null
    grep -qxF "* soft core 0" "$FILE" || echo "* soft core 0" | sudo tee -a "$FILE" >/dev/null
}

install_packages() {
    detect_distro

    if [ "$DISTRO" = "fedora" ]; then
        run_cmd "sudo dnf autoremove -y"
        run_cmd "sudo dnf install -y setools policycoreutils policycoreutils-python-utils setroubleshoot firejail chkrootkit rkhunter torbrowser-launcher proxychains-ng nmap git htop jq wireshark tcpdump aide suricata zeek-core zeekctl"

    elif [ "$DISTRO" = "ubuntu" ]; then
        run_cmd "sudo apt update"
        run_cmd "sudo apt autopurge -y"

        print_success "Adding Zeek repository for Ubuntu..."
        run_cmd "echo 'deb https://download.opensuse.org/repositories/security:/zeek/xUbuntu_${VERSION_ID}.04/ /' | sudo tee /etc/apt/sources.list.d/security:zeek.list"
        run_cmd "curl -fsSL https://download.opensuse.org/repositories/security:zeek/xUbuntu_${VERSION_ID}.04/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/security_zeek.gpg > /dev/null"

        run_cmd "sudo apt update"
        run_cmd "sudo apt install -y apt-show-versions debsums firejail apparmor apparmor-profiles apparmor-profiles-extra apparmor-utils chkrootkit rkhunter tor torbrowser-launcher proxychains-ng nmap git htop jq wireshark tcpdump aide suricata zeek"
        run_cmd "sudo aa-enforce /etc/apparmor.d/*"
        run_cmd "sudo apt autopurge -y"

    elif [ "$DISTRO" = "debian" ]; then
        run_cmd "sudo apt update"
        run_cmd "sudo apt autopurge -y"

        print_success "Adding Zeek repository for Debian..."
        run_cmd "echo 'deb https://download.opensuse.org/repositories/security:/zeek/xUbuntu_22.04/ /' | sudo tee /etc/apt/sources.list.d/security:zeek.list"
        run_cmd "curl -fsSL https://download.opensuse.org/repositories/security:zeek/xUbuntu_22.04/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/security_zeek.gpg > /dev/null"

        run_cmd "sudo apt update"
        run_cmd "sudo apt install -y apt-show-versions debsums firejail apparmor apparmor-profiles apparmor-profiles-extra apparmor-utils chkrootkit rkhunter tor torbrowser-launcher proxychains-ng nmap git htop jq wireshark tcpdump aide suricata zeek"
        run_cmd "sudo aa-enforce /etc/apparmor.d/*"
        run_cmd "sudo apt autopurge -y"
    fi
}

disable_services() {
    print_success "Disabling unnecessary system services..."
    local services=(
        abrtd kdump kea dnsmasq cups.socket cups.path cups cups-browsed avahi-daemon.socket avahi-daemon samba smb kerneloops wpa_supplicant
    )
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "^$service"; then
            run_cmd "sudo systemctl stop \"$service\""
            run_cmd "sudo systemctl disable \"$service\""
        fi
    done
}

block_modules() {
    print_success "Blocking unused kernel modules..."
    local blacklist_file="/etc/modprobe.d/blacklist-custom.conf"
    sudo touch "$blacklist_file"

    local modules=(dccp sctp rds tipc)
    for module in "${modules[@]}"; do
        grep -qxF "blacklist $module" "$blacklist_file" || echo "blacklist $module" | sudo tee -a "$blacklist_file" >/dev/null
    done
}

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Options:
  --all                Run all hardening tasks
  --permissions        Set secure permissions
  --sysctl             Copy local security sysctl config
  --limits             Update limits.conf
  --install            Install security packages
  --services           Disable unnecessary system services
  --modules            Block unused kernel modules
  --dry-run            Simulate actions without applying
  --assume-yes         Assume yes for all prompts
  -h, --help           Show this help
  -v, --version        Show version
EOF
}

main() {
    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            --all) setup_permissions; copy_sysctl_config; update_limits_conf; install_packages; disable_services; block_modules ;;
            --permissions) setup_permissions ;;
            --sysctl) copy_sysctl_config ;;
            --limits) update_limits_conf ;;
            --install) install_packages ;;
            --services) disable_services ;;
            --modules) block_modules ;;
            --dry-run) DRY_RUN=1 ;;
            --assume-yes) ASSUME_YES=1 ;;
            -h|--help) usage; exit 0 ;;
            -v|--version) echo "$SCRIPT_NAME version $VERSION"; exit 0 ;;
            *) print_error "Unknown option: $1"; usage; exit 1 ;;
        esac
        shift
    done
}

main "$@"
