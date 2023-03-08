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
    sudo systemctl start ronin-post.service
    sudo systemctl restart pm2-ronindojo.service
    sudo systemctl disable ronin-setup.service
    sudo sed -i '/ronindojo/s/ALL) NOPASSWD:ALL/ALL) ALL/' /etc/sudoers
    touch /home/ronindojo/.logs/setup-complete
fi