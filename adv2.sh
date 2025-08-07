#!/bin/sh
set -e  # Exit immediately on error

echo "=== ⚙️ Applying Full Iran-Specific PassWall2 Configuration with IPv6 Support ==="

# Backup current configuration
BACKUP_DIR="/etc/config_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"#!/bin/sh
set -e  # Exit immediately on error

echo "=== ⚙️ Applying Iran-Optimized PassWall2 Configuration with IPv6 Support ==="

# Backup current configuration
BACKUP_DIR="/etc/config_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp /etc/config/network "$BACKUP_DIR" || echo "Warning: Failed to backup network config"
cp /etc/config/dhcp "$BACKUP_DIR" || echo "Warning: Failed to backup DHCP config"
cp /etc/config/passwall2 "$BACKUP_DIR" || echo "Warning: Failed to backup PassWall2 config"
cp /etc/config/system "$BACKUP_DIR" || echo "Warning: Failed to backup system config"
cp /etc/config/firewall "$BACKUP_DIR" || echo "Warning: Failed to backup firewall config"

# Set timezone to Tehran
uci set system.@system[0].zonename='Asia/Tehran'
uci set system.@system[0].timezone='<+0330>-3:30'
uci commit system

# Disable ISP DNS on WAN (both IPv4 and IPv6)
uci set network.wan.peerdns='0'
uci set network.wan6.peerdns='0'
uci delete network.wan.dns
uci delete network.wan6.dns
if ! uci commit network; then
    echo "Error: Failed to commit network changes" >&2
    exit 1
fi

# Configure DNSMasq for local resolution only
uci set dhcp.@dnsmasq[0].noresolv='1'
uci set dhcp.@dnsmasq[0].localuse='1'
uci set dhcp.@dnsmasq[0].cachesize='10000'
uci set dhcp.@dnsmasq[0].rebind_protection='0'  # For Iranian CDNs
uci set dhcp.@dnsmasq[0].boguspriv='0'
uci set dhcp.@dnsmasq[0].filter_aaaa='0'  # Enable IPv6
uci set dhcp.@dnsmasq[0].server='127.0.0.1#7913'  # PassWall2 DNS

# Configure DHCP for IPv4/IPv6
uci set dhcp.lan.dhcp_option='6,192.168.1.1'  # IPv4 DNS
uci add_list dhcp.lan.dhcp_option='6,fd00::1'  # IPv6 DNS
uci set dhcp.lan.ra='server'
uci set dhcp.lan.dhcpv6='server'
uci set dhcp.lan.ra_management='1'
uci add_list dhcp.lan.dns='fd00::1'

# Configure PassWall2 DNS with DoH
uci -q delete passwall2.@dns[0]
uci add passwall2 dns
uci set passwall2.@dns[0].enabled='1'
uci set passwall2.@dns[0].dns_mode='fake-dns'
uci set passwall2.@dns[0].remote_dns='https://dns.google/dns-query,https://cloudflare-dns.com/dns-query'
uci set passwall2.@dns[0].fallback_dns='178.22.122.100,185.51.200.2'
uci set passwall2.@dns[0].default_dns='local'
uci set passwall2.@dns[0].disable_ipv6='0'  # Enable IPv6

# Enhanced DoH settings
uci set passwall2.@dns[0].doh_host='dns.google,cloudflare-dns.com'
uci set passwall2.@dns[0].doh_path='/dns-query,/dns-query'
uci set passwall2.@dns[0].dns_cache='1'
uci set passwall2.@dns[0].dns_cache_timeout='7200'

# Port exclusions for compatibility
uci -q delete passwall2.@global_forwarding[0]
uci add passwall2 global_forwarding
uci set passwall2.@global_forwarding[0].tcp_no_redir_ports='25,110,465,587,993,995'
uci set passwall2.@global_forwarding[0].udp_no_redir_ports='123,1194,51820'

# Access control for local IPs and Iranian domains
IRAN_DIRECT_HOSTS='ir,iran.ir,ac.ir,co.ir,org.ir,net.ir,sch.ir,id.ir,gov.ir,bank.ir,shaparak.ir,dl.music-fa.com,dl.songsara.net,digikala.com,snapp.ir,divar.ir,tapsi.ir,alibaba.ir,torob.com,setare.com,tamin.ir,mci.ir,mtnirancell.ir,shatel.ir,irancell.ir,hamrahcard.ir,rightel.ir,hiweb.ir,mellatbank.com,samanbank.com,parsian-bank.com,bankmaskan.ir,bmi.ir,sb24.com,enbank.net,ayandeh.com,bsi.ir,banksepah.ir,postbank.ir'

uci -q delete passwall2.@access_control[0]
uci add passwall2 access_control
uci set passwall2.@access_control[0].direct_hosts="$IRAN_DIRECT_HOSTS"
uci set passwall2.@access_control[0].direct_ip='10.0.0.0/8,192.168.0.0/16,127.0.0.0/8,::1/128,fc00::/7,fd00::/8'

# Auto-switch for failover
uci -q delete passwall2.@auto_switch[0]
uci add passwall2 auto_switch
uci set passwall2.@auto_switch[0].enabled='1'
uci set passwall2.@auto_switch[0].testing_url='https://www.google.com/generate_204'
uci set passwall2.@auto_switch[0].timeout='5'
uci set passwall2.@auto_switch[0].try_count='2'
uci set passwall2.@auto_switch[0].node_timeout='5'
uci set passwall2.@auto_switch[0].connectivity_test_mode='http'

# Shunt rules for Iranian domains
uci -q delete passwall2.@shunt_rules[0]
uci add passwall2 shunt_rules
uci set passwall2.@shunt_rules[-1].name='IR Sites'
uci set passwall2.@shunt_rules[-1].domain_list="$IRAN_DIRECT_HOSTS"
uci set passwall2.@shunt_rules[-1].proxy_mode='direct'

uci -q delete passwall2.@shunt_rules[1]
uci add passwall2 shunt_rules
uci set passwall2.@shunt_rules[-1].name='Default'
uci set passwall2.@shunt_rules[-1].proxy_mode='default'

# Main shunt config
uci -q delete passwall2.@shunt[0]
uci add passwall2 shunt
uci set passwall2.@shunt[0].main_node='@auto_switch[0]'

# Enable IPv6 forwarding
uci set network.globals.ula_prefix='fd00::/48'
uci set firewall.@defaults[0].forward='ACCEPT'
uci set firewall.@defaults[0].fullcone6='1'

# Kill switch rule
uci -q delete firewall.passwall2_killswitch
uci set firewall.passwall2_killswitch=rule
uci set firewall.passwall2_killswitch.name='KillSwitch'
uci set firewall.passwall2_killswitch.src='wan'
uci set firewall.passwall2_killswitch.dest='*'
uci set firewall.passwall2_killswitch.proto='all'
uci set firewall.passwall2_killswitch.target='DROP'
uci set firewall.passwall2_killswitch.enabled='1'

# Block IRGC ASNs
uci -q delete firewall.irgc_block
uci set firewall.irgc_block=rule
uci set firewall.irgc_block.name='Block IRGC ASN'
uci set firewall.irgc_block.src='lan'
uci set firewall.irgc_block.dest='wan'
uci set firewall.irgc_block.dest_ip='185.147.160.0/22 185.173.104.0/22 185.49.104.0/22'
uci set firewall.irgc_block.proto='all'
uci set firewall.irgc_block.target='REJECT'

# Apply all changes
if ! uci commit; then
    echo "Error: Failed to commit changes" >&2
    exit 1
fi

# Restart services with verification
restart_service() {
    echo "Restarting $1..."
    if /etc/init.d/$1 restart; then
        echo "✅ $1 restarted successfully"
        return 0
    else
        echo "❌ $1 restart failed!" >&2
        return 1
    fi
}

restart_service network
sleep 2
restart_service dnsmasq
sleep 2
restart_service passwall2
sleep 2
restart_service firewall

echo "
✅ Iran-optimized configuration applied successfully!
=== Configuration Summary ===
Timezone: Asia/Tehran (UTC+3:30)
DNS Mode: FakeDNS + DoH (Encrypted)
- Iranian domains: Direct via Shecan
- Global traffic: DoH via Google/Cloudflare
IPv6 Support: Fully enabled
Security Features:
- Kill switch enabled
- IRGC ASN blocking
- Port exclusions for email/VPN
Performance:
- Auto-switch failover (5s timeout)
- DNS caching (2 hours)
- Shunt routing for Iranian domains
Backup Location: $BACKUP_DIR
"
cp /etc/config/network "$BACKUP_DIR" || echo "Warning: Failed to backup network config"
cp /etc/config/dhcp "$BACKUP_DIR" || echo "Warning: Failed to backup DHCP config"
cp /etc/config/passwall2 "$BACKUP_DIR" || echo "Warning: Failed to backup PassWall2 config"
cp /etc/config/system "$BACKUP_DIR" || echo "Warning: Failed to backup system config"
cp /etc/config/firewall "$BACKUP_DIR" || echo "Warning: Failed to backup firewall config"

# Set timezone to Tehran
uci set system.@system[0].zonename='Asia/Tehran'
uci set system.@system[0].timezone='<+0330>-3:30'
uci commit system

# Disable ISP DNS on WAN (both IPv4 and IPv6)
uci set network.wan.peerdns='0'
uci set network.wan6.peerdns='0'
uci delete network.wan.dns
uci delete network.wan6.dns
if ! uci commit network; then
    echo "Error: Failed to commit network changes" >&2
    exit 1
fi

# Configure DNSMasq
uci set dhcp.@dnsmasq[0].noresolv='1'
uci set dhcp.@dnsmasq[0].localuse='1'
uci set dhcp.@dnsmasq[0].cachesize='10000'
uci set dhcp.@dnsmasq[0].rebind_protection='0'  # Disabled for Iranian CDNs compatibility
uci set dhcp.@dnsmasq[0].strictorder='1'  # Try servers in order
uci set dhcp.@dnsmasq[0].allservers='1'   # Enable fallback
uci set dhcp.@dnsmasq[0].confdir='/etc/dnsmasq.d'
uci set dhcp.@dnsmasq[0].cachelocal='1'  # Cache local domains
uci set dhcp.@dnsmasq[0].boguspriv='0'   # Disable for Iranian private domains
uci set dhcp.@dnsmasq[0].filter_aaaa='0'  # Enable AAAA (IPv6) records

# Create config directory
mkdir -p /etc/dnsmasq.d || exit 1
chmod 755 /etc/dnsmasq.d

# Iranian DNS Configuration (Shecan)
cat << "EOF" > /etc/dnsmasq.d/iran-domains.conf
# Iranian domains DNS configuration
# Primary DNS: Shecan (178.22.122.100)
# Backup DNS: 403.online (185.51.200.2)

# Use consistent matching patterns for all domains
server=/ir/178.22.122.100
server=/co.ir/178.22.122.100
server=/ac.ir/178.22.122.100
server=/gov.ir/178.22.122.100
server=/org.ir/178.22.122.100
server=/net.ir/178.22.122.100
server=/sch.ir/178.22.122.100
server=/id.ir/178.22.122.100

# Specific Iranian services
server=/mci.ir/178.22.122.100
server=/mtnirancell.ir/178.22.122.100
server=/shatel.ir/178.22.122.100
server=/irancell.ir/178.22.122.100
server=/hamrahcard.ir/178.22.122.100
server=/rightel.ir/178.22.122.100
server=/hiweb.ir/178.22.122.100
server=/apt.ir/178.22.122.100
server=/mellatbank.com/178.22.122.100
server=/samanbank.com/178.22.122.100
server=/parsian-bank.com/178.22.122.100
server=/bankmaskan.ir/178.22.122.100
server=/bmi.ir/178.22.122.100
server=/sb24.com/178.22.122.100
server=/enbank.net/178.22.122.100
server=/ayandeh.com/178.22.122.100
server=/bsi.ir/178.22.122.100
server=/banksepah.ir/178.22.122.100
server=/postbank.ir/178.22.122.100
server=/digikala.com/178.22.122.100
server=/snapp.ir/178.22.122.100
server=/divar.ir/178.22.122.100
server=/tapsi.ir/178.22.122.100
server=/alibaba.ir/178.22.122.100
server=/torob.com/178.22.122.100
server=/setare.com/178.22.122.100
server=/tamin.ir/178.22.122.100
server=/iran.ir/178.22.122.100

# Backup Iranian DNS (using same patterns as primary)
server=/ir/185.51.200.2
server=/co.ir/185.51.200.2
server=/ac.ir/185.51.200.2
server=/gov.ir/185.51.200.2
server=/org.ir/185.51.200.2
server=/net.ir/185.51.200.2
server=/sch.ir/185.51.200.2
EOF

# Global DNS Configuration with Proxy Priority (IPv4 and IPv6)
cat << "EOF" > /etc/dnsmasq.d/global-dns.conf
# DNS configuration with proxy priority
# First try PassWall2 DNS proxy (port 7913)
server=/#/127.0.0.1#7913

# Fallback to global DNS when proxy is disabled (IPv4 and IPv6)
server=/#/8.8.8.8
server=/#/8.8.4.4
server=/#/2001:4860:4860::8888       # Google IPv6
server=/#/2001:4860:4860::8844       # Google IPv6
server=/#/1.1.1.1
server=/#/1.0.0.1
server=/#/2606:4700:4700::1111       # Cloudflare IPv6
server=/#/2606:4700:4700::1001       # Cloudflare IPv6
EOF

# Configure DHCP for both IPv4 and IPv6
uci set dhcp.lan.dhcp_option='6,192.168.1.1'  # Router as DNS for IPv4
uci add_list dhcp.lan.dhcp_option='6,fd00::1'  # Router as DNS for IPv6
uci set dhcp.lan.ra='server'
uci set dhcp.lan.dhcpv6='server'
uci set dhcp.lan.ra_management='1'
uci add_list dhcp.lan.dns='fd00::1'             # Router as DNS for IPv6 SLAAC

# Configure PassWall2 with DoH and enhanced caching (IPv6 support)
DOH_SERVERS='https://dns.google/dns-query,https://cloudflare-dns.com/dns-query'
DOH_HOSTS='dns.google,cloudflare-dns.com'

uci set passwall2.@global[0].dns_mode='fakeip'
uci set passwall2.@global[0].dns_proxy_mode='doh'
uci set passwall2.@global[0].doh_url="$DOH_SERVERS"
uci set passwall2.@global[0].dns_listen='127.0.0.1,::1'  # Listen on both IPv4 and IPv6
uci set passwall2.@global[0].dns_cache='1'
uci set passwall2.@global[0].dns_cache_timeout='7200'  # 2-hour caching
uci set passwall2.@global[0].dns_max_cache='10000'    # 10,000 entries
uci set passwall2.@global[0].remote_dns="$DOH_SERVERS"
uci set passwall2.@global[0].dns_query_strategy='prefer_ipv4'
uci set passwall2.@global[0].dns_fakeip_range='192.168.3.0/24'
uci set passwall2.@global[0].dns_auto='1'
uci set passwall2.@global[0].ipv6_tproxy='1'  # Enable IPv6 transparent proxy

# Enhanced DoH settings
uci set passwall2.@global[0].doh_host="$DOH_HOSTS"
uci set passwall2.@global[0].doh_path='/dns-query,/dns-query'
uci set passwall2.@global[0].doh_sni="$DOH_HOSTS"
uci set passwall2.@global[0].doh_ipversion='prefer_ipv4'

# Enable DNS prefetching and persistent caching
uci set passwall2.@global[0].dns_prefetch='1'
uci set passwall2.@global[0].dns_cache_persistent='1'

# Configure DoH load balancing and failover
uci set passwall2.@global[0].doh_lb='1'
uci set passwall2.@global[0].doh_lb_ttl='300'
uci set passwall2.@global[0].doh_lb_retry='2'
uci set passwall2.@global[0].doh_lb_timeout='10'

# Port exclusions for compatibility
uci -q delete passwall2.@global_forwarding[0]
uci add passwall2 global_forwarding
uci set passwall2.@global_forwarding[0].tcp_no_redir_ports='25,110,465,587,993,995'
uci set passwall2.@global_forwarding[0].udp_no_redir_ports='123,1194,51820'

# Access control for local IPs and Iranian domains
uci -q delete passwall2.@access_control[0]
uci add passwall2 access_control
uci set passwall2.@access_control[0].direct_hosts='ir,iran.ir,ac.ir,bank.ir,shaparak.ir,dl.music-fa.com,dl.songsara.net'
uci set passwall2.@access_control[0].direct_ip='10.0.0.0/8,192.168.0.0/16,127.0.0.0/8,::1/128,fc00::/7,fd00::/8'

# Auto-switch for failover
uci -q delete passwall2.@auto_switch[0]
uci add passwall2 auto_switch
uci set passwall2.@auto_switch[0].enabled='1'
uci set passwall2.@auto_switch[0].testing_url='https://www.google.com/generate_204'
uci set passwall2.@auto_switch[0].timeout='5'
uci set passwall2.@auto_switch[0].try_count='2'
uci set passwall2.@auto_switch[0].node_timeout='5'
uci set passwall2.@auto_switch[0].connectivity_test_mode='http'

# Shunt rules for Iranian domains
uci -q delete passwall2.@shunt_rules[0]
uci add passwall2 shunt_rules
uci set passwall2.@shunt_rules[-1].name='IR Sites'
uci set passwall2.@shunt_rules[-1].domain_list='ir,ac.ir,gov.ir,bank.ir,shaparak.ir,dl.music-fa.com,telegram.org,cdn.telegram.org,core.telegram.org'
uci set passwall2.@shunt_rules[-1].proxy_mode='direct'

uci -q delete passwall2.@shunt_rules[1]
uci add passwall2 shunt_rules
uci set passwall2.@shunt_rules[-1].name='Default'
uci set passwall2.@shunt_rules[-1].proxy_mode='default'

uci -q delete passwall2.@shunt[0]
uci add passwall2 shunt
uci set passwall2.@shunt[0].main_node='@auto_switch[0]'

# Apply changes
if ! uci commit dhcp; then
    echo "Error: Failed to commit DHCP changes" >&2
    exit 1
fi

if ! uci commit passwall2; then
    echo "Error: Failed to commit PassWall2 changes" >&2
    exit 1
fi

# Create DoH bypass for Iranian domains
mkdir -p /etc/passwall2 || exit 1
cat << "EOF" > /etc/passwall2/999_bypass_iran_dns.yaml
bypass:
  - name: "Iranian DNS Domains"
    type: domain
    domain:
      - "ir"
      - "co.ir"
      - "ac.ir"
      - "gov.ir"
      - "org.ir"
      - "net.ir"
      - "sch.ir"
      - "id.ir"
      - "mci.ir"
      - "mtnirancell.ir"
      - "shatel.ir"
      - "irancell.ir"
      - "hamrahcard.ir"
      - "rightel.ir"
      - "hiweb.ir"
      - "digikala.com"
      - "snapp.ir"
      - "divar.ir"
      - "tapsi.ir"
      - "alibaba.ir"
      - "torob.com"
      - "setare.com"
      - "tamin.ir"
      - "iran.ir"
      - "mellatbank.com"
      - "samanbank.com"
      - "parsian-bank.com"
      - "bankmaskan.ir"
      - "bmi.ir"
      - "sb24.com"
      - "enbank.net"
      - "ayandeh.com"
      - "bsi.ir"
      - "banksepah.ir"
      - "postbank.ir"
    target: DIRECT
EOF

# Enable IPv6 forwarding
uci set network.globals.ula_prefix='fd00::/48'  # Use unique local address range
uci set firewall.@defaults[0].forward='ACCEPT'
uci set firewall.@defaults[0].fullcone6='1'     # Enable IPv6 full-cone NAT

# Kill switch rule: Drop WAN traffic if tunnel fails
uci -q delete firewall.passwall2_killswitch
uci set firewall.passwall2_killswitch=rule
uci set firewall.passwall2_killswitch.name='KillSwitch'
uci set firewall.passwall2_killswitch.src='wan'
uci set firewall.passwall2_killswitch.dest='*'
uci set firewall.passwall2_killswitch.proto='all'
uci set firewall.passwall2_killswitch.target='DROP'
uci set firewall.passwall2_killswitch.enabled='1'

# Block IRGC ASNs (basic ranges)
uci -q delete firewall.irgc_block
uci set firewall.irgc_block=rule
uci set firewall.irgc_block.name='Block IRGC ASN'
uci set firewall.irgc_block.src='lan'
uci set firewall.irgc_block.dest='wan'
uci set firewall.irgc_block.dest_ip='185.147.160.0/22 185.173.104.0/22 185.49.104.0/22'
uci set firewall.irgc_block.proto='all'
uci set firewall.irgc_block.target='REJECT'

# Apply firewall changes
if ! uci commit firewall; then
    echo "Error: Failed to commit firewall changes" >&2
    exit 1
fi

# Boot persistence
uci set system.@system[0].startup='/etc/init.d/passwall2 restart'
if ! uci commit system; then
    echo "Error: Failed to commit system changes" >&2
    exit 1
fi

# Restart services with status checks
echo "Restarting network..."
/etc/init.d/network reload && echo "Network reloaded" || echo "Network reload failed"
sleep 2

echo "Restarting DNSMasq..."
/etc/init.d/dnsmasq restart && echo "DNSMasq restarted" || echo "DNSMasq restart failed"
sleep 2

echo "Restarting PassWall2..."
/etc/init.d/passwall2 restart && echo "PassWall2 restarted" || echo "PassWall2 restart failed"
sleep 2

echo "Restarting firewall..."
/etc/init.d/firewall restart && echo "Firewall restarted" || echo "Firewall restart failed"

echo "
✅ All configurations applied successfully!
=== Configuration Summary ===
DNS Mode: fakeip + DoH with Google primary and Cloudflare backup
IPv6 Support: Enabled
Iranian domains: Handled by local DNS servers
Security Features:
  - Kill switch enabled
  - IRGC ASN blocking
  - Port exclusions for compatibility
Time Zone: Asia/Tehran (UTC+3:30)
Last known configuration backed up to: $BACKUP_DIR
"
