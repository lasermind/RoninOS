#!/bin/bash

while systemctl is-active --quiet ronin-setup.service
do
    echo "Dojo still installing..."
    sleep 5s
    if ! systemctl is-active --quiet ronin-setup.service
    then
        echo "restarting pm2..."
        pm2 resurrect
        break
    fi
done