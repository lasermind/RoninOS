#!/bin/bash


## Global variables
# RoninDojo setup
TMPDIR=/var/tmp
USER="ronindojo"
FULLNAME="RoninDojo"
# PASSWORD="password"       # Test purposes only
# ROOTPASSWORD="password"   # Test purposes only
PASSWORD="$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c'21')"
ROOTPASSWORD="$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c'21')"

# Locales
TIMEZONE="UTC"
KEYMAP="us"
LOCALE="en_US.UTF-8"

# Terminal colours
CGREEN="\033[0;32m"
CRED="\033[0;31m"
CDEF="\033[0m"



# Adding users
echo -e "Add user [${CGREEN} ronindojo ${CDEF}] [${CGREEN} tor ${CDEF}]"
useradd -s /bin/bash -m -c "ronindojo" ronindojo -p rock
useradd -c "tor" tor && echo "ronindojo    ALL=(ALL) ALL" >> /etc/sudoers

# Removing the first user login requirement with monitor and keyboard
rm /root/.not_logged_in_yet 



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
    echo -e "Preparing for timezone [${CGREEN} $TIMEZONE ${CDEF}]"
    sed -i -e "1a\ " \
    -e "1asudo timedatectl set-timezone ${TIMEZONE}" \
    -e "1asudo timedatectl set-ntp true" \
    -e "1a\ " /usr/local/sbin/ronin-setup.sh

    
    # Generating desired $LOCALE as additional locale
    echo -e "Adding locale [${CGREEN} $LOCALE ${CDEF}]"
    # Uncommenting desired locale; but also keep preset 'en_US' as a necessary default
    sed -i "s/^\s*#.*$LOCALE/$LOCALE/" /etc/locale.gen
    locale-gen
    # We should not set this locale now, because it is not wise to set non-standard locale ('en_US')
    # Some scripts can complain and break, especially during build time
    # localectl set-locale $LOCALE
    
    # Preparing keyboard layout to be set to $KEYMAP
    echo -e "Setting keyboard layout to [${CGREEN} $KEYMAP ${CDEF}]"
    sed -i "s/XKBLAYOUT.*/XKBLAYOUT=\"$KEYMAP\"/" /etc/default/keyboard	
    
    # Configuration complete, cleaning up
    # rm /root/.bash_profile

    # Avahi setup
    sed -i 's/hosts: .*$/hosts: files mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] dns mdns/' /etc/nsswitch.conf
    sed -i 's/.*host-name=.*$/host-name=ronindojo/' /etc/avahi/avahi-daemon.conf
    if ! systemctl is-enabled --quiet avahi-daemon; then
        systemctl enable --quiet avahi-daemon
    fi

    # Sshd setup
    sed -i -e "s/PermitRootLogin yes/#PermitRootLogin prohibit-password/" \
        -e "s/PermitEmptyPasswords yes/#PermitEmptyPasswords no/" /etc/ssh/sshd_config

    # Enable password-less sudo
    test -d /etc/sudoers.d || mkdir /etc/sudoers.d
    echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ronindojo.override
    sed -i '/ronindojo/s/ALL) ALL/ALL) NOPASSWD:ALL/' /etc/sudoers # Change to no password
    # ^ Observation: Probably this ^ throws an error, visible early in './logs/setup.logs'
    # This means, the command has no effect anyway. Not sure what the implication is right now ...
    

    echo -e "domain .local\nnameserver 1.1.1.1\nnameserver 1.0.0.1" >> /etc/resolv.conf
    
    # Setup logs for outputs
    mkdir -p /home/ronindojo/.logs
    touch /home/ronindojo/.logs/setup.logs
    touch /home/ronindojo/.logs/post.logs
    chown -R ronindojo:ronindojo /home/ronindojo/.logs
}



_service_checks(){  
    if ! systemctl is-enabled tor.service; then
        systemctl enable tor.service
    fi

    if ! systemctl is-enabled --quiet avahi-daemon.service; then
        systemctl disable systemd-resolved.service &>/dev/null
        systemctl enable avahi-daemon.service
    fi

    if ! systemctl is-enabled motd.service; then
        systemctl enable motd.service
    fi
    
    if ! systemctl is-enabled ronin-setup.service; then
        systemctl enable ronin-setup.service
    fi

    if ! systemctl is-enabled ronin-post.service; then
        systemctl enable ronin-post.service
    fi
}



# Installs Node.js, docker, docker-compose, and pm2.
# This is needed due to some out dated packages in the default debian package manager.
_prep_install(){

    # Install Node.js
    curl -sL https://deb.nodesource.com/setup_16.x | bash -
    apt-get update
    apt-get install -y nodejs

    # Install docker
    mkdir -m 0755 -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Install docker-compose
    curl -L https://github.com/docker/compose/releases/download/v2.0.1/docker-compose-linux-aarch64 -o /usr/bin/docker-compose
    chmod +x /usr/bin/docker-compose

    # Install pm2 for Node.js
    npm install pm2 -g
}



_ronin_ui_avahi_service() {

    echo "Setting up Avahi service"
    
    if [ ! -f /etc/avahi/services/http.service ]; then
        tee "/etc/avahi/services/http.service" <<EOF >/dev/null
<?xml version="1.0" standalone='no'?><!--*-nxml-*-->
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<!-- This advertises the RoninDojo vhost -->
<service-group>
 <name replace-wildcards="yes">%h Web Application</name>
  <service>
   <type>_http._tcp</type>
   <port>80</port>
  </service>
</service-group>
EOF
    fi

    sed -i 's/hosts: .*$/hosts: files mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] dns mdns/' /etc/nsswitch.conf

    if ! grep -q "host-name=ronindojo" /etc/avahi/avahi-daemon.conf; then
        sed -i 's/.*host-name=.*$/host-name=ronindojo/' /etc/avahi/avahi-daemon.conf
    fi

    if ! systemctl is-enabled --quiet avahi-daemon; then
        systemctl enable --quiet avahi-daemon
    fi

    return 0
}



_rand_passwd() {
    local _length
    _length="${1:-16}"

    tr -dc 'a-zA-Z0-9' </dev/urandom | head -c"${_length}"
}



# Install RoninUI.
# This function is the same we utilize in the RoninDojo repo.
# Only modifying slightly since this runs during build and not organic setup.
_install_ronin_ui(){

     echo -e "Preparing installation of [${CGREEN} RoninUI ${CDEF}]"
     
    roninui_version_file="https://ronindojo.io/downloads/RoninUI/version.json"

    gui_api=$(_rand_passwd 69)
    gui_jwt=$(_rand_passwd 69)

    cd /home/ronindojo || exit

    echo "Installing pnpm for Node.js"
    
    npm i -g pnpm@7 &>/dev/null

    # sudo npm install pm2 -g

    test -d /home/ronindojo/Ronin-UI || mkdir /home/ronindojo/Ronin-UI
    cd /home/ronindojo/Ronin-UI || exit

    echo "Downloading and verifying RoninUI archive"
    
    wget -q "${roninui_version_file}" -O /tmp/version.json 2>/dev/null

    _file=$(jq -r .file /tmp/version.json)
    _shasum=$(jq -r .sha256 /tmp/version.json)

    wget -q https://ronindojo.io/downloads/RoninUI/"$_file" 2>/dev/null

    if ! echo "${_shasum} ${_file}" | sha256sum --check --status; then
        _bad_shasum=$(sha256sum ${_file})
        echo "Ronin UI archive verification failed! Valid sum is ${_shasum}, got ${_bad_shasum} instead..."
    fi
      
    echo "Extracting RoninUI archive"
    
    tar xzf "$_file"

    rm "$_file" /tmp/version.json

    # Mark RoninUI initialized if necessary
    if [ -e "${ronin_ui_init_file}" ]; then
        echo -e "{\"initialized\": true}\n" > ronin-ui.dat
    fi

    # Generate .env file
    echo "JWT_SECRET=$gui_jwt" > .env
    echo "NEXT_TELEMETRY_DISABLED=1" >> .env

    if [ "${roninui_version_staging}" = true ] ; then
        echo -e "VERSION_CHECK=staging\n" >> .env
    fi

    _ronin_ui_avahi_service

    chown -R ronindojo:ronindojo /home/ronindojo/Ronin-UI
    
    echo -e "Ronin UI [${CGREEN} installed ${CDEF}]"
}



# The Debian default was incompatible with our setup.
# This sets Tor to match RoninDojo requirements and removes the Debian variants.
_prep_tor(){

    echo -e "Setting up new Tor service for RoninDojo"

    # Prepare RoninDojo Tor service
    mkdir -p /mnt/usb/tor
    chown -R tor:tor /mnt/usb/tor
    sed -i '$a\User tor\nDataDirectory /mnt/usb/tor' /etc/tor/torrc
    sed -i '$ a\
HiddenServiceDir /mnt/usb/tor/hidden_service_ronin_backend/\
HiddenServiceVersion 3\
HiddenServicePort 80 127.0.0.1:8470\
' /etc/tor/torrc

    cp -Rv /tmp/RoninOS/overlays/RoninOS/example.tor.service /usr/lib/systemd/system/tor.service
    # Remove unnecessary Debian-installed services 
    rm -rf /usr/lib/systemd/system/tor@*
}



# If RoninOS image needs to be compiled with a static IP preset, then make your edits here
# Adapted from: wiki.ronindojo.io/en/extras/Setting-Static-IP
# Uncomment _prep_staticip() function in main() to make use of this
_prep_staticip(){

    echo -e "Preparing for local IP to be [${CGREEN} static ${CDEF}]"

    systemctl -q disable NetworkManager.service
    mkdir -p /etc/systemd/network

    echo " "
    tee "/etc/systemd/network/eth0.network" <<EOF
[Match]
Name=eth0

[Network]
Address=192.168.0.21
Gateway=192.168.0.1
DNS=192.168.0.1
DNS=9.9.9.9
EOF

    systemctl -q unmask systemd-networkd.service
    systemctl -q enable systemd-networkd.service
}



# This installs all required packages needed for RoninDojo.
# Copies (or clones) the RoninOS repo so it can be provided to appropriate locations.
# Then runs all the functions defined above.
main(){
    # Installing dependencies
    echo -e "Preparing and installing packages [${CGREEN} GO ${CDEF}]"
    apt-get update
    apt-get install -y man-db git avahi-daemon nginx openjdk-11-jdk tor fail2ban net-tools htop unzip wget ufw rsync jq python3 python3-pip pipenv gdisk gcc curl apparmor ca-certificates gnupg lsb-release
    apt-get install -y mc glances

    # Pass user-prepared RoninOS repo on from overlay to build
    echo -e "Preparing scripts for [${CGREEN} RoninOS ${CDEF}]"
    mkdir -p /tmp/RoninOS

    # Choose method 1: CLONE a branch from web
    # git clone --branch=master https://code.samourai.io/ronindojo/RoninOS /tmp/RoninOS
    
    # Choose method 2: COPY provided from overlay to build
    cp -R /tmp/overlay/RoninOS/* /tmp/RoninOS
    

    cp -R /tmp/RoninOS/overlays/RoninOS/usr/* /usr/
    cp -R /tmp/RoninOS/overlays/RoninOS/etc/* /etc/


    ## Sanity check
    # TODO: Remove this after successful runs.
    if [ ! -f /usr/lib/systemd/system/ronin-setup.service ]; then
        echo -e "Warning: ronin-setup.service [${CRED} missing ${CDEF}]"
        echo -e "Still broken ... ${CRED}exiting.${CDEF}"
        exit 1;
    else

        echo -e "The ronin-setup.service is now [${CGREEN} present ${CDEF}] – keep going!"

        _create_oem_install
        # _prep_staticip # Use this if static IP is needed
        _prep_install
        _prep_tor

        mkdir -p /usr/share/nginx/logs
        rm -rf /etc/nginx/sites-enabled/default
        
        _install_ronin_ui
        usermod -aG docker ronindojo
        
        systemctl enable oem-boot.service
        _service_checks
        
        echo -e "RoninOS setup [${CGREEN} completed ${CDEF}]"
    fi
}



# Run main setup function.
main