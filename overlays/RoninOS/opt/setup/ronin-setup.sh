#!/bin/bash

systemctl disable oem-boot.service

mv /opt/RoninDojo /home/admin/RoninDojo
chown -R admin:admin /home/admin/RoninDojo
echo "admin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-nopasswd

# move repo

su admin -c /home/admin/RoninDojo/ronin _main
source /home/admin/RoninDojo/Scripts/defaults.sh /home/admin/RoninDojo/Scripts/functions.sh && su admin -c /home/admin/RoninDojo/Scripts/functions.sh _main
su admin -c /home/admin/RoninDojo/Scripts/Install/install-system-setup.sh
su admin -l /home/admin/RoninDojo/Scripts/Install/install-dojo.sh

rm  /etc/sudoers.d/99-nopasswd
systemctl disable ronin-setup.service
done
