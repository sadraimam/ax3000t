#!/bin/bash

# Set root password
opkg update && opkg install openssl-util
HASH=$(openssl passwd -1 "123456789")
sed -i "/^root:/s|:[^:]*:|:${HASH}:|" /etc/shadow
openssl passwd -1 "123456789" | awk -v hash="$(cat)" '{ system("sed -i \"/^root:/s|:[^:]*:|:" hash ":|\" /etc/shadow") }'

# Set Wifi
uci set wireless.radio0.cell_density='0'
uci set wireless.default_radio0.encryption='sae-mixed'
uci set wireless.default_radio0.key='123456789'
uci set wireless.default_radio0.ocv='0'
uci set wireless.radio1.cell_density='0'
uci set wireless.default_radio1.encryption='sae-mixed'
uci set wireless.default_radio1.key='123456789'
uci set wireless.default_radio1.ocv='0'
uci commit wireless
wifi reload
uci set wireless.radio0.disabled='0'
uci set wireless.radio1.disabled='0'
uci commit wireless
wifi reload
