#!/bin/bash

# FIX ME
git config --global http.sslVerify false

# Clone Repo
git clone -b master https://code.samourai.io/ronindojo/RoninDojo

# Source files
cd "$HOME"/RoninDojo || exit

. Scripts/defaults.sh
. Scripts/functions.sh

# Run main
if _main; then
    # Run system setup
    Scripts/Install/install-system-setup.sh system

    # Run RoninDojo install
    Scripts/Install/install-dojo.sh dojo

    # Restore getty
    sudo mv /usr/lib/systemd/system/getty\@.service.bak /usr/lib/systemd/system/getty\@.service
    sudo rm /etc/systemd/system/getty\@tty1.service.d/override.conf
    sudo systemctl daemon-reload

    sudo systemctl disable ronin-setup.service
    sudo rm /etc/sudoers.d/99-nopasswd

    git config --global http.sslVerify true
    pm2 resurrect
fi