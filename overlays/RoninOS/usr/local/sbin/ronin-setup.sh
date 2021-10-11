#!/bin/bash

# FIX ME
git config --global http.sslVerify false

# Clone Repo
git clone -b feat_plug_n_play https://code.samourai.io/ronindojo/RoninDojo

# Source files
cd "$HOME"/RoninDojo || exit

. Scripts/defaults.sh
. Scripts/functions.sh

# Run main
_main & export _pid="$!"

# Run system setup
Scripts/Install/install-system-setup.sh system

# Run RoninDojo install
Scripts/Install/install-dojo.sh dojo

sudo systemctl disable ronin-setup.service
sudo rm /etc/sudoers.d/99-nopasswd

git config --global http.sslVerify true