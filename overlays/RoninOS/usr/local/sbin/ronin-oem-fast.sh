#!/bin/bash

if [ ! -d /home/ronindojo/.logs ]; then
    mkdir -p /home/ronindojo/.logs
    touch /home/ronindojo/.logs/setup.logs
    touch /home/ronindojo/.logs/post.logs
    chown -R ronindojo:ronindojo /home/ronindojo/.logs
fi

systemctl enable ronin-setup.service
systemctl disable oem-boot.service
