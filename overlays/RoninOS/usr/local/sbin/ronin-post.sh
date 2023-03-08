#!/bin/bash

while systemctl is-active --quiet ronin-setup.service
do
    echo "Dojo still installing..."
    sleep 5s
    if ! systemctl is-active --quiet ronin-setup.service
    then
        sudo systemctl disable ronin-setup.service
        sudo systemctl disable ronin-post.service
        touch /home/ronindojo/.logs/post-complete
        echo "Install complete"
        break
    fi
done