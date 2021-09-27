#!/bin/bash

if [ -f /tmp/ronin-activated ]; then
   rm /tmp/ronin-activated
else
   echo "Something went wrong"
fi
