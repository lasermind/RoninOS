#!/bin/bash

echo "Waiting to resurrect PM2"
while [ ! -f /home/ronindojo/.logs/setup-complete]
do
   echo "waiting..."
   sleep 5s
   if [ -f /home/ronindojo/.logs/setup-complete ]; then
      echo "restarting pm2..."
      pm2 resurrect
      break
   fi
done