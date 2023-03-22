#!/bin/bash

regenerate_passwords_and_update_info_file(){
    # Generate a random password consisting of 16 characters using only numbers and letters.
    rootpwd="$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c'21')"
    roninpwd="$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c'21')"
    USER="ronindojo"


    # Change the root user's password.
    echo "Changing the root user's password..."
    sudo chpasswd <<<"root:$rootpwd"

    # Change the ronindojo user's password.
    echo "Changing the ronindojo user's password..."
    sudo chpasswd <<<"$USER:$roninpwd"

    # remove old info.json then create new with new passwords.
    rm -rf /home/ronindojo/.config/RoninDojo/info.json
    cat <<EOF >/home/"${USER}"/.config/RoninDojo/info.json
{"user":[{"name":"${USER}","password":"${PASSWORD}"},{"name":"root","password":"${ROOTPASSWORD}"}]}
EOF

    # add validation for that the setup was done.
    GENERATE_MESSAGE="Generated during system Setup."
    TIMESTAMP=$(date)
    echo "${GENERATE_MESSAGE}" >> /home/"${USER}"/.config/RoninDojo/info.json
    echo "${TIMESTAMP}" >> /home/"${USER}"/.config/RoninDojo/info.json
}

cd "$HOME"/RoninDojo || exit
# Source files
. Scripts/defaults.sh
. Scripts/functions.sh

# Run main
if _main; then
    # regenerate the passwords to be random for each user.
    regenerate_passwords_and_update_info_file

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