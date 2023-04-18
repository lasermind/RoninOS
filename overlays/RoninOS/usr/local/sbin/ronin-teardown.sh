#!/bin/bash

echo "Waiting to resurrect PM2"
while [ ! -f /home/ronindojo/.logs/setup-complete]
do
   echo "waiting..."
   sleep 5s
   if [ -f /home/ronindojo/.logs/setup-complete ]; then
      if ! systemctl is-active pm2-ronindojo.service; then
        sudo systemctl start pm2-ronindojo.service
      fi
      break
   fi
done