#!/bin/bash

TMPDIR=/var/tmp
SYSTEM=`inxi -M | awk '{print $6}'`
SYSTEMPRO=`inxi -M | awk '{print $7,$8}'`
USERGROUPS=""
USER="admin"
PASSWORD="admin"
CONFIRMPASSWORD="admin"
ROOTPASSWORD="ronindojoroot"
CONFIRMROOTPASSWORD="ronindojoroot"
FULLNAME="RoninDojo"
TIMEZONE="UTF-8"
LOCALE="en_US.UTF-8"
HOSTNAME="RoninDojo"
KEYMAP="us"
#IP_ADDRESS=$(ip route get 1.1.1.1 | awk '{print$7}')
#NETWORK_INTERFACE=$(ip route get 1.1.1.1 | awk '{print$5}')
#GATEWAY=$(ip route get 1.1.1.1 | awk '{print$3}')

create_oem_install() {
    echo "$USER" > $TMPDIR/user
    echo "$PASSWORD" >> $TMPDIR/password
    echo "$PASSWORD" >> $TMPDIR/password
    echo "$ROOTPASSWORD" >> $TMPDIR/rootpassword
    echo "$ROOTPASSWORD" >> $TMPDIR/rootpassword
#    tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 8 | head -n 1 >> /tmp/adminpass
#    ADMINPASS=$(cat /tmp/adminpass)
#    echo $ADMINPASS >> /tmp/adminpass
    echo "Setting root password..."
    passwd root < $TMPDIR/rootpassword 1> /dev/null 2>&1
    echo "Adding user $USER..."
    useradd -m -G wheel,sys,audio,input,video,storage,lp,network,users,power -s /bin/bash $(cat $TMPDIR/user) 1> /dev/null 2>&1
    if [ -d /usr/share/sddm ]; then
    cp /usr/share/sddm/faces/.face.icon /usr/share/sddm/faces/$USER.face.icon
    fi
    usermod -aG $USERGROUPS $(cat $TMPDIR/user) 1> /dev/null 2>&1
    echo "Setting full name to $FULLNAME..."
    chfn -f "$FULLNAME" $(cat $TMPDIR/user) 1> /dev/null 2>&1
    echo "Setting password for $USER..."
    passwd $(cat $TMPDIR/user) < $TMPDIR/password 1> /dev/null 2>&1
    echo "Setting timezone to $TIMEZONE..."
    timedatectl set-timezone $TIMEZONE 1> /dev/null 2>&1
    timedatectl set-ntp true 1> /dev/null 2>&1
    echo "Generating $LOCALE locale..."
    sed -i s/"#$LOCALE"/"$LOCALE"/g /etc/locale.gen 1> /dev/null 2>&1
    locale-gen 1> /dev/null 2>&1
    localectl set-locale $LOCALE 1> /dev/null 2>&1
    if [[ "$SYSTEM" != "Pinebook" ]]; then
        echo "Setting keymap to $KEYMAP..."
    localectl set-keymap $KEYMAP 1> /dev/null 2>&1
    fi
    if [ -f /etc/sway/inputs/default-keyboard ]; then
    sed -i s/"us"/"$KEYMAP"/ /etc/sway/inputs/default-keyboard
    if [[ "$KEYMAP" = "uk" ]]; then
    sed -i s/"uk"/"gb"/ /etc/sway/inputs/default-keyboard
    fi
    fi
    echo "Setting hostname to $HOSTNAME..."
    hostnamectl set-hostname $HOSTNAME 1> /dev/null 2>&1
    echo "Resizing partition..."
    resize-fs 1> /dev/null 2>&1
    echo "Applying system settings..."
    #systemctl disable systemd-resolved.service 1> /dev/null 2>&1
    systemctl enable ronin-setup.service
    #systemctl start avahi.service
    echo "Cleaning install for unwanted files..."
    sudo rm -rf /var/log/*
    
    # Remove temp files on host
    sudo rm -rf $TMPDIR/user $TMPDIR/password $TMPDIR/rootpassword

    loadkeys "$KEYMAP"

    echo "Configuration complete. Cleaning up..."
    #mv /usr/lib/systemd/system/getty@.service.bak /usr/lib/systemd/system/getty@.service
    rm /root/.bash_profile
    sed -i s/"PermitRootLogin yes"/"#PermitRootLogin prohibit-password"/g /etc/ssh/sshd_config
    sed -i s/"PermitEmptyPasswords yes"/"#PermitEmptyPasswords no"/g /etc/ssh/sshd_config
}

if [ "$(systemctl is-active dhcpcd.service 2>/dev/null)" != "active" ]; then 
   systemctl enable --now dhcpcd.service 
fi

if [ "$(systemctl is-active avahi-daemon.service 2>/dev/null)" != "active" ]; then
   systemctl disable systemd-resolved.service 1> /dev/null 2>&1
   systemctl enable --now avahi-daemon.service
fi

create_oem_install

#chmod 0640 /etc/shadow
#passwd -e admin

if [ "$(systemctl is-enabled motd.service 2>/dev/null)" != "enabled" ]; then
   systemctl enabled --now motd.service
fi

echo '' >> /etc/resolv.conf
#echo '# Added at Ronin startup' >> /etc/resolv.conf
echo 'domain .local' >> /etc/resolv.conf
echo 'nameserver 8.8.8.8' >> /etc/resolv.conf
echo 'nameserver 8.8.4.4' >> /etc/resolv.conf
echo 'nameserver 1.1.1.1' >> /etc/resolv.conf

echo "OEM complete"
cat /etc/motd

systemctl enable ronin-setup.service
systemctl disable oem-boot.service
systemctl reboot
