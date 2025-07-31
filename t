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
