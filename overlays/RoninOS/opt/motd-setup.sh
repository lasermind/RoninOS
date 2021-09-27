#!/bin/bash

rm -rf /etc/motd

bash -c "cat <<EOF > /etc/motd
Welcome to RoninDojo!

Website:   ronindojo.io
Wiki:      wiki.ronindojo.io
EOF"

touch /tmp/motd-actived