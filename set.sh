#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo "Running as root..."
sleep 2
clear

SNNAP=`grep -o SNAPSHOT /etc/openwrt_release | sed -n '1p'`
if [ "$SNNAP" == "SNAPSHOT" ]; then
    echo -e "${YELLOW} SNAPSHOT Version Detected ! ${NC}"
    echo -e "${RED} Snapshot not Supported. ! ${NC}"
    exit 1
else           
    echo -e "${GREEN} Updating Packages ... ${NC}"
fi

# Add Passwall Feeds
uci set system.@system[0].zonename='Asia/Tehran'
uci set system.@system[0].timezone='<+0330>-3:30'
uci set network.wan.peerdns="0"
uci set network.wan6.peerdns="0"
uci set network.wan.dns='8.8.4.4'
uci set network.wan6.dns='2001:4860:4860::8888'
uci commit system
uci commit network
/sbin/reload_config

# Add Passwall Feeds
wget -O /tmp/passwall.pub https://master.dl.sourceforge.net/project/openwrt-passwall-build/passwall.pub
opkg-key add /tmp/passwall.pub
>/etc/opkg/customfeeds.conf

read release arch << EOF
$(. /etc/openwrt_release ; echo ${DISTRIB_RELEASE%.*} $DISTRIB_ARCH)
EOF

for feed in passwall_luci passwall_packages passwall2; do
  echo "src/gz $feed https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$release/$arch/$feed" >> /etc/opkg/customfeeds.conf
done

opkg update

# Function to install from tmp
install_tmp() {
  pkg="$1"
  
  # Check if package is already installed
  if opkg list-installed | grep -q "^$pkg - "; then
    echo -e "${GREEN}$pkg is already installed. Skipping.${NC}"
    return 0
  fi

  echo -e "${YELLOW}Installing $pkg ...${NC}"
  cd /tmp || return 1
  rm -f ${pkg}_*.ipk  # Clean up any previous downloads

  # Download with retry logic
  retry=3
  while [ $retry -gt 0 ]; do
    opkg download "$pkg"
    # Check if download succeeded (exit code 0 AND file exists)
    if [ $? -eq 0 ] && ls ${pkg}_*.ipk >/dev/null 2>&1; then
      break
    fi
    retry=$((retry - 1))
    if [ $retry -gt 0 ]; then
      echo -e "${RED}Download failed for $pkg. ${retry} attempts remaining. Retrying...${NC}"
      sleep 5
    fi
  done

  # Final verification after download attempts
  if ! ls ${pkg}_*.ipk >/dev/null 2>&1; then
    echo -e "${RED}Failed to download $pkg after multiple attempts${NC}"
    return 1
  fi

  # Install package
  ipk_file=$(ls -t ${pkg}_*.ipk | head -n1)
  opkg install "$ipk_file"
  install_status=$?
  
  # Cleanup regardless of installation status
  rm -f ${pkg}_*.ipk
  
  if [ $install_status -ne 0 ]; then
    echo -e "${RED}Installation failed for $pkg${NC}"
  else
    echo -e "${GREEN}Successfully installed $pkg${NC}"
  fi
  
  sleep 2
  return $install_status
}

# Main Install Sequence
opkg remove dnsmasq
install_tmp dnsmasq-full
install_tmp wget-ssl
install_tmp unzip
install_tmp luci-app-passwall2
install_tmp kmod-nft-socket
install_tmp kmod-nft-tproxy
install_tmp kmod-inet-diag
install_tmp kmod-netlink-diag
install_tmp kmod-tun
install_tmp ipset
install_tmp sing-box
install_tmp hysteria

### Verify Installation ###
RESULT5=`ls /usr/lib/opkg/info/dnsmasq-full.control`
if [ "$RESULT5" == "/usr/lib/opkg/info/dnsmasq-full.control" ]; then
echo -e "${GREEN} dnsmasq-full : OK ! ${NC}"
 else
 echo -e "${YELLOW} dnsmasq-full : NOT INSTALLED X ${NC}"
fi

RESULT5=`ls /etc/init.d/passwall2`
if [ "$RESULT5" == "/etc/init.d/passwall2" ]; then
echo -e "${GREEN} Passwall2 : OK ! ${NC}"
 else
 echo -e "${YELLOW} Passwall2 : NOT INSTALLED X ${NC}"
fi

RESULT=`ls /usr/bin/xray`
if [ "$RESULT" == "/usr/bin/xray" ]; then
echo -e "${GREEN} XRAY : OK ! ${NC}"
 else
 echo -e "${YELLOW} XRAY : NOT INSTALLED X ${NC}"
fi

RESULT=`ls /usr/bin/sing-box`
if [ "$RESULT" == "/usr/bin/sing-box" ]; then
echo -e "${GREEN} Sing-box : OK ! ${NC}"
 else
 echo -e "${YELLOW} Sing-box : NOT INSTALLED X ${NC}"
fi

RESULT=`ls /usr/bin/hysteria`
if [ "$RESULT" == "/usr/bin/hysteria" ]; then
echo -e "${GREEN} Hysteria : OK ! ${NC}"
 else
 echo -e "${YELLOW} Hysteria : NOT INSTALLED X ${NC}"
fi

# Optional Patch
cd /tmp
wget -q https://raw.githubusercontent.com/sadraimam/passwall/refs/heads/main/iam.zip && unzip -o iam.zip -d /
cd
echo -e "${YELLOW}** Passwall Patched ** ${NC}"


# Passwall2 Settings
uci set system.@system[0].zonename='Asia/Tehran'
uci set system.@system[0].timezone='<+0330>-3:30'

uci set passwall2.@global_forwarding[0]=global_forwarding
uci set passwall2.@global_forwarding[0].tcp_no_redir_ports='disable'
uci set passwall2.@global_forwarding[0].udp_no_redir_ports='disable'
uci set passwall2.@global_forwarding[0].tcp_redir_ports='1:65535'
uci set passwall2.@global_forwarding[0].udp_redir_ports='1:65535'
uci set passwall2.@global[0].remote_dns='8.8.4.4'

# Delete unused rules
uci delete passwall2.GooglePlay
uci delete passwall2.Netflix
uci delete passwall2.OpenAI
uci delete passwall2.China
uci delete passwall2.QUIC
uci delete passwall2.Proxy
uci delete passwall2.UDP
uci delete passwall2.@global_subscribe[0].filter_discard_list

uci set passwall2.myshunt.Direct='_direct'
uci set passwall2.myshunt.DirectGame='_direct'
uci set passwall2.myshunt.remarks='MainShunt'

uci set passwall2.Direct=shunt_rules
uci set passwall2.Direct.network='tcp,udp'
uci set passwall2.Direct.remarks='IRAN'
uci set passwall2.Direct.ip_list='geoip:ir
0.0.0.0/8
10.0.0.0/8
100.64.0.0/10
127.0.0.0/8
169.254.0.0/16
172.16.0.0/12
192.0.0.0/24
192.0.2.0/24
192.88.99.0/24
192.168.0.0/16
198.19.0.0/16
198.51.100.0/24
203.0.113.0/24
224.0.0.0/4
240.0.0.0/4
255.255.255.255/32
::/128
::1/128
::ffff:0:0:0/96
64:ff9b::/96
100::/64
2001::/32
2001:20::/28
2001:db8::/32
2002::/16
fc00::/7
fe80::/10
ff00::/8'
uci set passwall2.Direct.domain_list='regexp:^.+\.ir$
geosite:category-ir'

uci commit passwall2
uci commit system
echo -e "${GREEN}** Passwall Configured ** ${NC}"

# DNS Rebind Fix
uci set dhcp.@dnsmasq[0].rebind_domain='www.ebanksepah.ir my.irancell.ir'
uci commit
echo -e "${GREEN}** DNS Rebind Fixed ** ${NC}"

echo -e "${MAGENTA}** Installation Completed ** ${NC}"
rm -f passwall2x.sh passwallx.sh
/sbin/reload_config

# Set Wifi
uci set wireless.radio0.cell_density='0'
uci set wireless.default_radio0.encryption='sae-mixed'
uci set wireless.default_radio0.key='123456789'
uci set wireless.default_radio0.ocv='0'
uci set wireless.radio0.disabled='0'
uci set wireless.radio1.cell_density='0'
uci set wireless.default_radio1.encryption='sae-mixed'
uci set wireless.default_radio1.key='123456789'
uci set wireless.default_radio1.ocv='0'
uci set wireless.radio1.disabled='0'
uci commit wireless
wifi reload
echo -e "${GREEN}** Wifi Configured ** ${NC}"

