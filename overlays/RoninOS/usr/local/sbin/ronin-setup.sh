#!/bin/bash
# Generate a random password consisting of 16 characters using only numbers and letters.
ROOTPASSWORD="$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c'21')"
PASSWORD="$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c'21')"
USER="ronindojo"


# Change the root user's password.
echo "Changing the root user's password..."
chpasswd <<<"root:$ROOTPASSWORD"

# Change the ronindojo user's password.
echo "Changing the ronindojo user's password..."
chpasswd <<<"$USER:$PASSWORD"

# remove old info.json then create new with new passwords.
rm -rf /home/ronindojo/.config/RoninDojo/info.json
cat <<EOF >/home/"${USER}"/.config/RoninDojo/info.json
{"user":[{"name":"${USER}","password":"${PASSWORD}"},{"name":"root","password":"${ROOTPASSWORD}"}]}
EOF

# add validation for that the setup was done.
GENERATE_MESSAGE="Generated during system Setup."
TIMESTAMP=$(date)
echo "${GENERATE_MESSAGE}$'\n'${TIMESTAMP}">> /home/"${USER}"/.config/RoninDojo/info.json

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
    if ! systemctl is-active pm2-ronindojo.service; then
        sudo systemctl start pm2-ronindojo.service
    fi
    sudo systemctl disable ronin-setup.service
    sudo sed -i '/ronindojo/s/ALL) NOPASSWD:ALL/ALL) ALL/' /etc/sudoers
    touch /home/ronindojo/.logs/setup-complete
fi