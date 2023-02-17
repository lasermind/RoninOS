#!/bin/bash

#####################################################################################################
#                                                                                                   #
# Meant as a test for new debian images. will be run by curl -sL <raw content> | sudo -E bash -     #
#                                                                                                   #
#####################################################################################################


git clone https://code.samourai.io/ronindojo/RoninOS.git /tmp/RoninOS
cp -Rv /tmp/RoninOS/overlays/RoninOS/usr/* /usr/
cp -Rv /tmp/RoninOS/overlays/RoninOS/etc/* /etc/
### sanity check ###
# TODO: Remove this after successful runs.
if [ ! -f /usr/lib/systemd/system/oem-boot.service ]; then
    echo "oem-boot.service is missing..."
    echo "Still broken.. exiting"
    exit 1;
else 
    echo "Setup service is PRESENT! Keep going!"
    systemctl enable oem-boot.service

    sudo apt-get install avahi-daemon nginx openjdk-11-jdk tor fail2ban net-tools htop unzip which wget ufw rsync jq python3 python3-pip pipenv gdisk gcc curl apparmor git ca-certificates gnupg lsb-release

    ##### node

    sudo curl -sL https://deb.nodesource.com/setup_16.x | sudo bash -
    sudo apt-get update
    sudo apt-get install -y nodejs

    ##### docker

    sudo mkdir -m 0755 -p /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    ##### docker-compose
    sudo curl -L https://github.com/docker/compose/releases/download/v2.0.1/docker-compose-linux-aarch64 -o /usr/bin/docker-compose
    sudo chmod +x /usr/bin/docker-compose

    ##### pm2
    sudo curl -sL https://raw.githubusercontent.com/Unitech/pm2/master/packager/setup.deb.sh | sudo -E bash -
    npm install pm2 -g
fi
