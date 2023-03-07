#!/bin/bash

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
    #sudo mv /usr/lib/systemd/system/getty\@.service.bak /usr/lib/systemd/system/getty\@.service
    sudo rm /etc/systemd/system/getty\@tty1.service.d/override.conf
    sudo systemctl daemon-reload
    sudo systemctl disable ronin-setup.service
    sudo systemctl start ronin-post.service
    sudo sed -i '/ronindojo/s/ALL) NOPASSWD:ALL/ALL) ALL/' /etc/sudoers
    touch /home/ronindojo/.logs/setup-complete
fi