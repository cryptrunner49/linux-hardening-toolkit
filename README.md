# 🐧🛡️ Linux Hardening Toolkit

## Overview

The **Linux Hardening Toolkit** is a powerful and easy-to-use script to enhance the security of your Linux systems.  
It applies a wide range of best practices for system hardening, service minimization, kernel protection, and package security.

Designed for **Debian**, **Ubuntu**, and **Fedora** systems.

---

## Features

✅ Harden system configuration (sysctl, limits, permissions)  
✅ Install essential security packages (e.g., Firejail, AppArmor, AIDE, Zeek, Suricata)  
✅ Disable unnecessary and vulnerable services  
✅ Blacklist unused and risky kernel modules  
✅ Runs multiple times without conflict 
✅ Logging of all operations to `/var/log/harden_linux.log`  
✅ Dry-run mode and Assume-yes automation  
✅ Colored terminal output for better readability  
✅ Compatible with **Ubuntu**, **Debian**, and **Fedora**

---

## Requirements

- Bash 4+
- `sudo` privileges
- Supported Linux distribution:
  - Ubuntu 20.04/22.04+
  - Debian 11+
  - Fedora 36+

---

## Usage

First, make the script executable:

```bash
chmod +x harden_linux.sh
```

Then, you can run it with different options:

| Command Example | Description |
|:---|:---|
| `sudo ./harden_linux.sh --all --assume-yes` | Apply full system hardening automatically |
| `sudo ./harden_linux.sh --install` | Only install security-related packages |
| `sudo ./harden_linux.sh --permissions` | Only fix system file permissions |
| `sudo ./harden_linux.sh --services` | Only disable unnecessary services |
| `sudo ./harden_linux.sh --dry-run --all` | Simulate all changes without applying them |
| `./harden_linux.sh --help` | Show help message |
| `./harden_linux.sh --version` | Display version information |

---

## Important Notes

- **Backups**: The script automatically backs up critical configuration files before modifying them.
- **Dry-Run**: Always recommended on production servers before applying changes.
- **Logs**: All actions are logged to `/var/log/harden_linux.log` for audit and troubleshooting.
