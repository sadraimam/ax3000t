#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# root check
if [ "$(id -u)" -ne 0 ]; then
  echo -e "${RED}This script must be run as root. Exiting.${NC}"
  exit 1
else
  echo -e "${GREEN}Running as root...${NC}"
  clear
fi

# Snapshot check
if grep -q SNAPSHOT /etc/openwrt_release; then
    echo -e "${YELLOW}SNAPSHOT Version Detected!${NC}"
    echo -e "${RED}Snapshot builds are not supported.${NC}"
    exit 1
else
    echo -e "${GREEN}Configuring System...${NC}"
fi

# Detect IPv6 availability
HAS_IPV6=0
if ip -6 addr show scope global | grep -q 'inet6'; then
    HAS_IPV6=1
    echo -e "${GREEN}IPv6 detected. IPv6 configuration will be applied.${NC}"
else
    echo -e "${YELLOW}No IPv6 detected. Skipping IPv6, DNS, DHCP, and Passwall IPv6 configs.${NC}"
    # Disable IPv6 firewall rules
    uci set firewall.@defaults[0].disable_ipv6=1
    uci commit firewall
fi

# Initialize Network (IPv4 always, IPv6 only if detected)
uci del network.wan.dns 2>/dev/null
uci set network.wan.peerdns="0"
uci add_list network.wan.dns="8.8.4.4"
uci add_list network.wan.dns="1.1.1.1"

if [ $HAS_IPV6 -eq 1 ]; then
    uci del network.wan6.dns 2>/dev/null
    uci set network.wan6.peerdns="0"
    uci add_list network.wan6.dns="2001:4860:4860::8844"
    uci add_list network.wan6.dns="2606:4700:4700::1111"
fi
uci commit network
/sbin/reload_config >/dev/null
echo -e "${GREEN}Network Initialized!${NC}"

# Wait for WAN before NTP sync
echo -e "${YELLOW}Waiting for WAN to be ready...${NC}"
until ping -c1 -W1 8.8.8.8 >/dev/null 2>&1; do
    sleep 2
done
echo -e "${GREEN}WAN is up.${NC}"

# Initialize Time/Date
uci set system.@system[0].zonename='Asia/Tehran'
uci set system.@system[0].timezone='<+0330>-3:30'
uci delete system.ntp.server
uci add_list system.ntp.server='ir.pool.ntp.org'
uci add_list system.ntp.server='0.openwrt.pool.ntp.org'
uci add_list system.ntp.server='1.openwrt.pool.ntp.org'
uci commit system
/etc/init.d/sysntpd restart
echo -e "${GREEN}Time/Date Initialized!${NC}"

echo -e "${YELLOW}Syncing time with NTP...${NC}"
ntpd -n -q -p ir.pool.ntp.org || {
  echo -e "${RED}NTP sync failed! Retrying with global pool...${NC}"
  ntpd -n -q -p 0.openwrt.pool.ntp.org || {
    echo -e "${RED}NTP sync failed again. Please check DNS/network.${NC}"
  }
}
echo -e "${CYAN}$(date)${NC}"

# Add Passwall Feeds with key validation
TMP_KEY="/tmp/passwall.pub"
wget -O "$TMP_KEY" https://master.dl.sourceforge.net/project/openwrt-passwall-build/passwall.pub
if grep -q "BEGIN PUBLIC KEY" "$TMP_KEY"; then
    opkg-key add "$TMP_KEY"
    echo -e "${GREEN}Passwall key added successfully.${NC}"
else
    echo -e "${RED}Passwall key validation failed! Exiting.${NC}"
    rm -f "$TMP_KEY"
    exit 1
fi
rm -f "$TMP_KEY"

> /etc/opkg/customfeeds.conf
read release arch <<EOF
$(. /etc/openwrt_release; echo ${DISTRIB_RELEASE%.*} $DISTRIB_ARCH)
EOF
for feed in passwall_luci passwall_packages passwall2; do
  echo "src/gz $feed https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$release/$arch/$feed" >> /etc/opkg/customfeeds.conf
done
echo -e "${GREEN}Feed Updated!${NC}"

# Wait for opkg lock before update
while pgrep opkg >/dev/null 2>&1; do
    echo -e "${YELLOW}Waiting for opkg lock...${NC}"
    sleep 2
done
echo -e "${YELLOW}Updating Packages...${NC}"
opkg update

# Function to install from tmp (safer package handling)
install_tmp() {
  pkg="$1"
  if opkg list-installed | grep -q "^$pkg - "; then
    echo -e "${GREEN}$pkg is already installed. Skipping.${NC}"
    return 0
  fi
  echo -e "${YELLOW}Installing $pkg ...${NC}"
  cd /tmp || return 1
  rm -f ${pkg}_*.ipk
  retry=3
  while [ $retry -gt 0 ]; do
    opkg download "$pkg"
    ipk_file=$(find . -maxdepth 1 -type f -name "${pkg}_*.ipk" | head -n1)
    if [ -n "$ipk_file" ]; then
      opkg install "$ipk_file" && rm -f "$ipk_file" && return 0
    fi
    retry=$((retry - 1))
    if [ $retry -gt 0 ]; then
      echo -e "${RED}Download failed for $pkg. ${retry} attempts remaining. Retrying...${NC}"
      sleep 5
    fi
  done
  echo -e "${RED}Failed to install $pkg after multiple attempts.${NC}"
  return 1
}

# Main Install Sequence
opkg remove dnsmasq
install_tmp dnsmasq-full
install_tmp wget-ssl
install_tmp luci-app-passwall2
install_tmp ipset
install_tmp kmod-tun
install_tmp kmod-nft-tproxy
install_tmp kmod-nft-socket
install_tmp sing-box
install_tmp hysteria

# (Rest of your script remains unchanged)
