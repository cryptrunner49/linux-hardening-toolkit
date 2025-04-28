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
✅ Logging of all operations to `/var/log/hardening.log`  
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
chmod +x harden.sh
```

Then, you can run it with different options:

| Command Example | Description |
|:---|:---|
| `sudo ./harden.sh --all --assume-yes` | Apply full system hardening automatically |
| `sudo ./harden.sh --install` | Only install security-related packages |
| `sudo ./harden.sh --permissions` | Only fix system file permissions |
| `sudo ./harden.sh --services` | Only disable unnecessary services |
| `sudo ./harden.sh --dry-run --all` | Simulate all changes without applying them |
| `./harden.sh --help` | Show help message |
| `./harden.sh --version` | Display version information |

---

## Important Notes

- **Backups**: The script automatically backs up critical configuration files before modifying them.
- **Dry-Run**: Always recommended on production servers before applying changes.
- **Logs**: All actions are logged to `/var/log/hardening.log` for audit and troubleshooting.

---

## License

This project is licensed under the MIT License.  
Feel free to use, modify, and contribute!

---

## 💬 Contributing

Have ideas for improvement? Found a bug?  
Feel free to open an issue or submit a pull request!  

Together, we make Linux safer for everyone. 🛡️🐧
