#!/bin/sh

# Disable ISP DNS on WAN
uci set network.wan.peerdns='0'
uci delete network.wan.dns
uci commit network

# Configure DNSMasq
uci set dhcp.@dnsmasq[0].noresolv='1'
uci set dhcp.@dnsmasq[0].localuse='1'
uci set dhcp.@dnsmasq[0].cachesize='10000'
uci set dhcp.@dnsmasq[0].rebind_protection='0'  # Required for Iranian CDNs
uci set dhcp.@dnsmasq[0].strictorder='1'  # Try servers in order
uci set dhcp.@dnsmasq[0].allservers='1'   # Enable fallback
uci set dhcp.@dnsmasq[0].confdir='/etc/dnsmasq.d'
uci set dhcp.@dnsmasq[0].cachelocal='1'  # Cache local domains

# Create config directory
mkdir -p /etc/dnsmasq.d

# Iranian DNS Configuration (Shecan)
cat << "EOF" > /etc/dnsmasq.d/iran-domains.conf
# Primary Iranian DNS
server=/.ir/178.22.122.100
server=/.co.ir/178.22.122.100
server=/.ac.ir/178.22.122.100
server=/.gov.ir/178.22.122.100
server=/.org.ir/178.22.122.100
server=/.net.ir/178.22.122.100
server=/.sch.ir/178.22.122.100
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

# Backup Iranian DNS
server=/ir/185.51.200.2
server=/co.ir/185.51.200.2
server=/ac.ir/185.51.200.2
server=/gov.ir/185.51.200.2
server=/org.ir/185.51.200.2
server=/net.ir/185.51.200.2
server=/sch.ir/185.51.200.2
EOF

# Global DNS Configuration with Proxy Priority
cat << "EOF" > /etc/dnsmasq.d/global-dns.conf
# First try PassWall2 DNS proxy
server=/#/127.0.0.1#7913

# Fallback to global DNS when proxy is disabled
server=/#/8.8.8.8
server=/#/8.8.4.4
server=/#/1.1.1.1
server=/#/1.0.0.1
EOF

# Configure DHCP
uci set dhcp.lan.dhcp_option='6,192.168.1.1'  # Router as DNS

# Configure PassWall2 with DoH and enhanced caching
uci set passwall2.@global[0].dns_mode='fakeip'
uci set passwall2.@global[0].dns_proxy_mode='doh'
uci set passwall2.@global[0].doh_url='https://dns.google/dns-query,https://cloudflare-dns.com/dns-query'
uci set passwall2.@global[0].dns_listen='127.0.0.1'
uci set passwall2.@global[0].dns_cache='1'
uci set passwall2.@global[0].dns_cache_timeout='7200'  # 2-hour caching
uci set passwall2.@global[0].dns_max_cache='10000'    # 10,000 entries
uci set passwall2.@global[0].remote_dns='https://dns.google/dns-query,https://cloudflare-dns.com/dns-query'
uci set passwall2.@global[0].dns_query_strategy='prefer_ipv4'
uci set passwall2.@global[0].dns_fakeip_range='192.168.3.0/24'
uci set passwall2.@global[0].dns_auto='1'

# Enhanced DoH settings for Iran
uci set passwall2.@global[0].doh_host='dns.google,cloudflare-dns.com'
uci set passwall2.@global[0].doh_path='/dns-query,/dns-query'
uci set passwall2.@global[0].doh_sni='dns.google,cloudflare-dns.com'
uci set passwall2.@global[0].doh_ipversion='prefer_ipv4'

# Enable DNS prefetching and persistent caching
uci set passwall2.@global[0].dns_prefetch='1'
uci set passwall2.@global[0].dns_cache_persistent='1'

# Configure DoH load balancing and failover
uci set passwall2.@global[0].doh_lb='1'
uci set passwall2.@global[0].doh_lb_ttl='300'
uci set passwall2.@global[0].doh_lb_retry='2'
uci set passwall2.@global[0].doh_lb_timeout='10'

# Apply changes
uci commit dhcp
uci commit passwall2

# Create DoH bypass for Iranian domains to prevent leaks
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
    target: DIRECT
EOF

# Restart services
/etc/init.d/dnsmasq restart
/etc/init.d/network reload
/etc/init.d/passwall2 restart

echo "DoH Configuration Applied Successfully!"
echo "DNS Mode: fakeip + DoH with Google primary and Cloudflare backup and Enhanced Iranian domain handling"

