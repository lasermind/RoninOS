#!/bin/bash

# Enable password less sudo
echo "admin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-nopasswd

su admin -c /home/admin/RoninDojo/ronin _main
source /home/admin/RoninDojo/Scripts/defaults.sh /home/admin/RoninDojo/Scripts/functions.sh && su admin -c /home/admin/RoninDojo/Scripts/functions.sh _main
su admin -c /home/admin/RoninDojo/Scripts/Install/install-system-setup.sh
su admin -l /home/admin/RoninDojo/Scripts/Install/install-dojo.sh

rm /etc/sudoers.d/99-nopasswd
systemctl disable ronin-setup.service