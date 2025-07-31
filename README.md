# Xiaomi AX3000T OpenWrt Configuration

Automated configuration script for Xiaomi AX3000T running OpenWrt.

## Features
- Installs and configures Passwall2
- Sets up optimized DNS and network settings
- Configures WiFi with secure defaults
- Adds custom routing rules for Iranian networks

## Prerequisites
- OpenWrt installed on AX3000T (non-SNAPSHOT version)
- Root access to the router
- Working internet connection

## Installation

### Option 1: Direct Download and Run
```bash
rm -f set.sh && wget https://raw.githubusercontent.com/sadraimam/ax3000t/refs/heads/main/set.sh && chmod 777 set.sh && sh set.sh
```

### Option 2: Pipe to Shell (Not Recommended for Security)
```bash
wget -qO- https://raw.githubusercontent.com/sadraimam/ax3000t/refs/heads/main/set.sh | sh
```

## Security Notice
Always review scripts before running them with root privileges. Option 1 is preferred as it allows inspection of the script before execution.

## Default Settings
- Default root password: 123456789 (Change after installation!)
- Timezone: Asia/Tehran
- DNS: Google DNS (8.8.4.4, 2001:4860:4860::8844)