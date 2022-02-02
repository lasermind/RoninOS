#!/bin/bash

while systemctl is-active --quiet ronin-setup.service == true
do
    echo "Dojo still installing..."
    sleep 30s
    if ! systemctl is-active --quiet ronin-setup.service
    then
        echo "restarting pm2..."
        pm2 resurrect
        sudo systemctl disable ronin-post.service
        break
    fi
done