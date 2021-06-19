#!/bin/bash

echo "Removing oem files ..."
if [ -f /tmp/ronin-oem-activated ]; then
   rm /tmp/ronin-oem-activated
   touch /tmp/ronin-oem-teardown
   if [ "$(systemctl is-active ronin-setup.service 2>/dev/null)" != "active" ]; then
      systemctl enable ronin-setup.service
   fi
else
   echo "Doesn't seem to be working: Skipping ..."
   exit
fi

echo '' >> /etc/resolv.conf
echo '# Added at Ronin startup' >> /etc/resolv.conf
echo 'domain .local >> /etc/resolv.conf
echo 'nameserver 8.8.8.8' >> /etc/resolv.conf
echo 'nameserver 8.8.4.4' >> /etc/resolv.conf
echo 'nameserver 1.1.1.1' >> /etc/resolv.conf


#passwd -e admin

sleep 2s

systemctl reboot
