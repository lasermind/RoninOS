#!/bin/bash

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
    # Setting root password
    chpasswd <<<"root:$ROOTPASSWORD"

    # Adding user $USER
    useradd -m -G wheel,sys,audio,input,video,storage,lp,network,users,power,docker -s /bin/bash "$USER" &>/dev/null

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
    rm /root/.bash_profile

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
    echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-nopasswd

    echo -e "domain .local\nnameserver 1.1.1.1\nnameserver 1.0.0.1" >> /etc/resolv.conf
}

_service_checks(){
    if ! systemctl is-enabled --quiet dhcpcd.service; then
        systemctl enable --quiet dhcpcd.service
    fi

    if ! systemctl is-enabled --quiet avahi-daemon.service; then
        systemctl disable systemd-resolved.service &>/dev/null
        systemctl enable --quiet avahi-daemon.service
    fi

    if ! systemctl is-enabled motd.service; then
        systemctl enable --quiet motd.service
    fi

    if ! systemctl is-enabled ronin-setup.service; then
        systemctl enable --quiet ronin-setup.service
    fi
}

_prep_install(){
    ##### node
    curl -sL https://deb.nodesource.com/setup_16.x | bash -
    apt-get update
    apt-get install -y nodejs

    ##### docker
    mkdir -m 0755 -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    ##### docker-compose
    curl -L https://github.com/docker/compose/releases/download/v2.0.1/docker-compose-linux-aarch64 -o /usr/bin/docker-compose
    chmod +x /usr/bin/docker-compose

    ##### pm2
    curl -sL https://raw.githubusercontent.com/Unitech/pm2/master/packager/setup.deb.sh | sudo -E bash -
    npm install pm2 -g
}

main(){
    # install dependencies
    apt-get install git avahi-daemon nginx openjdk-11-jdk tor fail2ban net-tools htop unzip wget ufw rsync jq python3 python3-pip pipenv gdisk gcc curl apparmor ca-certificates gnupg lsb-release
    
    # clone the original RoninOS
    git clone https://code.samourai.io/ronindojo/RoninOS.git /tmp/RoninOS

    cp -Rv /tmp/RoninOS/overlays/RoninOS/usr/* /usr/
    cp -Rv /tmp/RoninOS/overlays/RoninOS/etc/* /etc/
    ### sanity check ###
    # TODO: Remove this after successful runs.
    if [ ! -f /usr/lib/systemd/system/ronin-setup.service ]; then
        echo "oem-boot.service is missing..."
        echo "Still broken.. exiting"
        exit 1;
    else 
        echo "Setup service is PRESENT! Keep going!"
        _prep_install
        _create_oem_install
        _service_checks
        systemctl disable --quiet oem-fast.service
        systemctl enable --quiet ronin-setup.service
        systemctl enable --quiet ronin-post.service
        echo "Setup is complete"
    fi
}

main
