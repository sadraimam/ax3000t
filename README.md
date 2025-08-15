# Xiaomi AX3000T — OpenWrt + Passwall2 Auto Configuration

Automated configuration script for setting up Passwall2 on the Xiaomi AX3000T running OpenWrt.
Also compatible with similar OpenWrt-supported hardware.

## Features
- Installs and configures Passwall2 with recommended defaults.
- Sets up optimized DNS and network settings
- Configures WiFi with secure defaults
- Adds custom routing rules for Iranian networks

## Prerequisites
- OpenWrt installed (non-SNAPSHOT version)
- Root access to the router
- Working internet connection

## Installation

### Direct Run from ssh
```bash
rm -f set.sh && wget https://raw.githubusercontent.com/sadraimam/ax3000t/refs/heads/main/set.sh && chmod 777 set.sh && sh set.sh
```
### Run from RAM (Recommended, No Persistent Storage)
```bash
rm -f /tmp/set.sh && wget -O /tmp/set.sh https://raw.githubusercontent.com/sadraimam/ax3000t/refs/heads/main/set.sh && chmod +x /tmp/set.sh && sh /tmp/set.sh
```


## Default Settings
- Default root password: 123456789 (Change after installation!)
- Timezone: Asia/Tehran
- DNS: Google DNS (8.8.4.4, 2001:4860:4860::8844)
