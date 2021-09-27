#!/bin/bash

echo "Removing OEM files ..."

if [ -f /tmp/ronin-oem-activated ]; then
   rm /tmp/ronin-oem-activated
   touch /tmp/ronin-oem-teardown

   if ! systemctl is-active ronin-setup.service; then
      systemctl enable --quiet ronin-setup.service
   fi
else
   echo "Doesn't seem to be working: Skipping ..."
   exit
fi

systemctl reboot