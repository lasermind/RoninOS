#!/bin/bash

#####################################################################################################
#                                                                                                   #
# Meant as a test for new debian images. will be run by curl -sL <raw content> | sudo -E bash -     #
#                                                                                                   #
#####################################################################################################



echo "add user roinindojo"
useradd -s /bin/bash -m -c "ronindojo" ronindojo -p rock
useradd -c "tor" tor && echo "ronindojo    ALL=(ALL) ALL" >> /etc/sudoers


echo "set hostname"
hostname -b "ronindebian"

# RoninDojo part
TMPDIR=/var/tmp
USER="ronindojo"
PASSWORD="password" # test purposes only
#PASSWORD="$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c'21')"
ROOTPASSWORD="password" ## for testing purposes only
#ROOTPASSWORD="$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c'21')"
FULLNAME="RoninDojo"
TIMEZONE="UTC"
LOCALE="en_US.UTF-8"
HOSTNAME="RoninDojo"
KEYMAP="us"

_create_oem_install() {
    pam-auth-update --package	
    # Setting root password
    chpasswd <<<"root:$ROOTPASSWORD"

    # Adding user $USER
    useradd -m -G wheel,sys,audio,input,video,storage,lp,network,users,power -s /bin/bash "$USER" &>/dev/null

    # Set User and WorkingDirectory in ronin-setup.service unit file
    sed -i -e "s/User=.*$/User=${USER}/" \
        -e "s/WorkingDirectory=.*$/WorkingDirectory=\/home\/${USER}/" /usr/lib/systemd/system/ronin-setup.service

    # Setting full name to $FULLNAME
    chfn -f "$FULLNAME" "$USER" &>/dev/null

    # Setting password for $USER
    chpasswd <<<"$USER:$PASSWORD"

    # Save Linux user credentials for UI access
    mkdir -p /home/"${USER}"/.config/RoninDojo
    cat <<EOF >/home/"${USER}"/.config/RoninDojo/info.json
{"user":[{"name":"${USER}","password":"${PASSWORD}"},{"name":"root","password":"${ROOTPASSWORD}"}]}
EOF
    chown -R "${USER}":"${USER}" /home/"${USER}"/.config

    # Setting timezone to $TIMEZONE
    timedatectl set-timezone $TIMEZONE &>/dev/null
    timedatectl set-ntp true &>/dev/null

    # Generating $LOCALE locale
    sed -i "s/#$LOCALE/$LOCALE/" /etc/locale.gen &>/dev/null
    locale-gen &>/dev/null
    localectl set-locale $LOCALE &>/dev/null

    if [ -f /etc/sway/inputs/default-keyboard ]; then
        sed -i "s/us/$KEYMAP/" /etc/sway/inputs/default-keyboard

        if [ "$KEYMAP" = "uk" ]; then
            sed -i "s/uk/gb/" /etc/sway/inputs/default-keyboard
        fi
    fi

    # Setting hostname to $HOSTNAME
    hostnamectl set-hostname $HOSTNAME &>/dev/null

    # Resizing partition
    resize-fs &>/dev/null

    loadkeys "$KEYMAP"

    # Configuration complete. Cleaning up
    #rm /root/.bash_profile

    # Avahi setup
    sed -i 's/hosts: .*$/hosts: files mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] dns mdns/' /etc/nsswitch.conf
    sed -i 's/.*host-name=.*$/host-name=ronindojo/' /etc/avahi/avahi-daemon.conf
    if ! systemctl is-enabled --quiet avahi-daemon; then
        systemctl enable --quiet avahi-daemon
    fi

    # sshd setup
    sed -i -e "s/PermitRootLogin yes/#PermitRootLogin prohibit-password/" \
        -e "s/PermitEmptyPasswords yes/#PermitEmptyPasswords no/" /etc/ssh/sshd_config

    # Enable password less sudo
    test -d /etc/sudoers.d || mkdir /etc/sudoers.d
    echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ronindojo.override
    sed -i '/ronindojo/s/ALL) ALL/ALL) NOPASSWD:ALL/' /etc/sudoers # change to no password
    

    echo -e "domain .local\nnameserver 1.1.1.1\nnameserver 1.0.0.1" >> /etc/resolv.conf
    
    # Setup logs for outputs
    mkdir -p /home/ronindojo/.logs
    touch /home/ronindojo/.logs/setup.logs
    touch /home/ronindojo/.logs/post.logs
    chown -R ronindojo:ronindojo /home/ronindojo/.logs
}

_service_checks(){  
    systemctl enable tor

    if ! systemctl is-enabled --quiet avahi-daemon.service; then
        systemctl disable systemd-resolved.service &>/dev/null
        systemctl enable --quiet avahi-daemon.service
    fi

    if ! systemctl is-enabled motd.service; then
        systemctl enable --quiet motd.service
    fi
}

_prep_install(){
    # install Nodejs
    curl -sL https://deb.nodesource.com/setup_16.x | bash -
    apt-get update
    apt-get install -y nodejs

    # install docker
    mkdir -m 0755 -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # install docker-compose
    curl -L https://github.com/docker/compose/releases/download/v2.0.1/docker-compose-linux-aarch64 -o /usr/bin/docker-compose
    chmod +x /usr/bin/docker-compose

    # install pm2 
    npm install pm2 -g

    # Clone Repo
    git clone -b feature/debian_build_more https://code.samourai.io/ronindojo/RoninDojo /home/ronindojo/RoninDojo
}

_install_ronin_ui(){
    . /home/ronindojo/RoninDojo/Scripts/generated-credentials.sh
    . /home/ronindojo/RoninDojo/Scripts/defaults.sh
    . /home/ronindojo/RoninDojo/Scripts/

    cd /home/ronindojo || exit

    _print_message "Checking package dependencies for Ronin UI..."
    _sleep

    _install_pkg_if_missing "nginx"
    _install_pkg_if_missing "avahi-daemon"

    sudo npm i -g pnpm@7 &>/dev/null

    #sudo npm install pm2 -g

    test -d "${ronin_ui_path}" || mkdir "${ronin_ui_path}"
    cd "${ronin_ui_path}" || exit

    wget -q "${roninui_version_file}" -O /tmp/version.json 2>/dev/null

    _file=$(jq -r .file /tmp/version.json)
    _shasum=$(jq -r .sha256 /tmp/version.json)

    wget -q https://ronindojo.io/downloads/RoninUI/"$_file" 2>/dev/null

    if ! echo "${_shasum} ${_file}" | sha256sum --check --status; then
        _bad_shasum=$(sha256sum ${_file})
        _print_error_message "Ronin UI archive verification failed! Valid sum is ${_shasum}, got ${_bad_shasum} instead..."
    fi
      
    tar xzf "$_file"

    rm "$_file" /tmp/version.json

        # Mark Ronin UI initialized if necessary
        if [ -e "${ronin_ui_init_file}" ]; then
          echo -e "{\"initialized\": true}\n" > ronin-ui.dat
        fi

        # Generate .env file
        echo "JWT_SECRET=$gui_jwt" > .env
        echo "NEXT_TELEMETRY_DISABLED=1" >> .env

    if [ "${roninui_version_staging}" = true ] ; then
        echo -e "VERSION_CHECK=staging\n" >> .env
    fi

    _print_message "Performing pnpm install, please wait..."

    sudo -u ronindojo pnpm install --prod &>/dev/null || { printf "\n%s***\nRonin UI pnpm install failed...\n***%s\n" "${red}" "${nc}";exit; }

    _print_message "Performing Next start, please wait..."

    sudo -u ronindojo pm2 start pm2.config.js
    sudo -u ronindojo pm2 save
    sudo -u ronindojo pm2 startup && env PATH="$PATH:/usr/bin" /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u "ronindojo" --hp "/home/ronindojo" &>/dev/null

    _ronin_ui_setup_tor

    _ronin_ui_vhost

    _ronin_ui_avahi_service

    chown -R ronindojo:ronindojo /home/ronindojo/Ronin-UI
}

_prep_tor(){
	mkdir -p /mnt/usb/tor
	chown -R tor:tor /mnt/usb/tor
	sed -i '$a\User tor\nDataDirectory /mnt/usb/tor' /etc/tor/torrc
    cp /home/ronindojo/RoninDojo/example.tor.service /usr/lib/systemd/system/tor.service
    rm -rf /usr/lib/systemd/system/tor@* #remove unnecessary debian installed services
}

main(){
    # install dependencies
    apt-get install -y man-db git avahi-daemon nginx openjdk-11-jdk tor fail2ban net-tools htop unzip wget ufw rsync jq python3 python3-pip pipenv gdisk gcc curl apparmor ca-certificates gnupg lsb-release
    
    # clone the original RoninOS
    git clone -b feature/debian https://code.samourai.io/ronindojo/RoninOS.git /tmp/RoninOS

    cp -Rv /tmp/RoninOS/overlays/RoninOS/usr/* /usr/
    cp -Rv /tmp/RoninOS/overlays/RoninOS/etc/* /etc/
    ### sanity check ###
    # TODO: Remove this after successful runs.
    if [ ! -f /usr/lib/systemd/system/ronin-setup.service ]; then
        echo "ronin-setup.service is missing..."
        echo "Still broken.. exiting"
        exit 1;
    else 
        echo "Setup service is PRESENT! Keep going!"
        _create_oem_install
        _prep_install
        _service_checks
        _prep_tor
        usermod -aG pm2 ronindojo
        mkdir -p /usr/share/nginx/logs
        rm -rf /etc/nginx/sites-enabled/default
        _install_ronin_ui
        usermod -aG docker ronindojo
        systemctl enable oem-boot.service
        systemctl enable ronin-setup.service
        systemctl enable ronin-post.service
        echo "Setup is complete"
    fi
}

main