# Xiaomi AX3000T OpenWrt Passwall2

Passwall2 Automated configuration script for Xiaomi AX3000T running OpenWrt.

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

### Remote ssh and Run
```bash
rm -f set.sh && wget https://raw.githubusercontent.com/sadraimam/ax3000t/refs/heads/main/set.sh && chmod 777 set.sh && sh set.sh
```

## Default Settings
- Default root password: 123456789 (Change after installation!)
- Timezone: Asia/Tehran
- DNS: Google DNS (8.8.4.4, 2001:4860:4860::8844)
