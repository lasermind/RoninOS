#! /bin/bash

#variables
BRANCH='stable'
LIBDIR=/usr/share/manjaro-arm-tools/lib
BUILDDIR=/var/lib/manjaro-arm-tools/pkg
BUILDSERVER=https://repo.manjaro.org/repo
PACKAGER=$(cat /etc/makepkg.conf | grep PACKAGER)
PKGDIR=/var/cache/manjaro-arm-tools/pkg
ROOTFS_IMG=/var/lib/manjaro-arm-tools/img
TMPDIR=/var/lib/manjaro-arm-tools/tmp
IMGDIR=/var/cache/manjaro-arm-tools/img
IMGNAME=Manjaro-ARM-$EDITION-$DEVICE-$VERSION
PROFILES=/usr/share/manjaro-arm-tools/profiles
NSPAWN='systemd-nspawn -q --resolv-conf=copy-host --timezone=off -D'
OSDN='storage.osdn.net:/storage/groups/m/ma/manjaro-arm'
STORAGE_USER=$(whoami)
VERSION=$(date +'%y'.'%m')
FLASHVERSION=$(date +'%y'.'%m')
ARCH='aarch64'
DEVICE='rpi4'
EDITION='minimal'
USER='admin'
PASSWORD='admin'
srv_list=/tmp/services_list

#import conf file
source /etc/manjaro-arm-tools/manjaro-arm-tools.conf 


usage_deploy_img() {
    echo "Usage: ${0##*/} [options]"
    echo "    -i <image>         Image to upload. Should be a .xz file."
    echo "    -d <device>        Device the image is for. [Default = rpi4. Options = $(ls -m --width=0 "$PROFILES/arm-profiles/devices/")]"
    echo "    -e <edition>       Edition of the image. [Default = minimal. Options = $(ls -m --width=0 "$PROFILES/arm-profiles/editions/")]"
    echo "    -v <version>       Version of the image. [Default = Current YY.MM]"
    echo "    -k <gpg key ID>    Email address associated with the GPG key to use for signing"
    echo "    -u <username>      Username of your OSDN user account with access to upload [Default = currently logged in local user]"
    echo "    -t                 Create a torrent of the image"
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_build_pkg() {
    echo "Usage: ${0##*/} [options]"
    echo "    -a <arch>          Architecture. [Default = aarch64. Options = any or aarch64]"
    echo "    -p <pkg>           Package to build"
    echo "    -k                 Keep the previous rootfs for this build"
    echo "    -b <branch>        Set the branch used for the build. [Default = stable. Options = stable, testing or unstable]"
    echo "    -n                 Install built package into rootfs"
    echo "    -i <package>       Install local package into rootfs."
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_build_img() {
    echo "Usage: ${0##*/} [options]"
    echo "    -d <device>        Device the image is for. [Default = rpi4. Options = $(ls -m --width=0 "$PROFILES/arm-profiles/devices/")]"
    echo "    -e <edition>       Edition of the image. [Default = minimal. Options = $(ls -m --width=0 "$PROFILES/arm-profiles/editions/")]"
    echo "    -v <version>       Define the version the resulting image should be named. [Default is current YY.MM]"
    echo "    -i <package>       Install local package into image rootfs."
    echo "    -b <branch>        Set the branch used in the image. [Default = stable. Options = stable, testing or unstable]"
    echo "    -m                 Create bmap. ('bmap-tools' need to be installed.)"
    echo "    -n                 Force download of new rootfs."
    echo "    -x                 Don't compress the image."
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_build_emmcflasher() {
    echo "Usage: ${0##*/} [options]"
    echo "    -d <device>        Device the image is for. [Default = rpi4. Options = $(ls -m --width=0 "$PROFILES/arm-profiles/devices/")]"
    echo "    -e <edition>       Edition of the image to download. [Default = minimal. Options = $(ls -m --width=0 "$PROFILES/arm-profiles/editions/")]"
    echo "    -v <version>       Define the version of the release to download. [Default is current YY.MM]"
    echo "    -f <flash version> Version of the eMMC flasher image it self. [Default is current YY.MM]"
    echo "    -i <package>       Install local package into image rootfs."
    echo "    -n                 Force download of new rootfs."
    echo "    -x                 Don't compress the image."
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_getarmprofiles() {
    echo "Usage: ${0##*/} [options]"
    echo '    -f                 Force download of current profiles from the git repository'
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

msg() {
    ALL_OFF="\e[1;0m"
    BOLD="\e[1;1m"
    GREEN="${BOLD}\e[1;32m"
    local mesg=$1; shift
    printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
 }
 
info() {
    ALL_OFF="\e[1;0m"
    BOLD="\e[1;1m"
    BLUE="${BOLD}\e[1;34m"
    local mesg=$1; shift
    printf "${BLUE}  ->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
 }

error() {
    local mesg=$1; shift
    printf "${RED}==> ERROR:${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

cleanup() {
    umount $ROOTFS_IMG/rootfs_$ARCH/var/cache/pacman/pkg
    exit ${1:-0}
}

abort() {
    error 'Aborting...'
    cleanup 255
}

prune_cache(){
    info "Prune and unmount pkg-cache..."
    $NSPAWN $CHROOTDIR paccache -r
    umount $PKG_CACHE
}
 
get_timer(){
    echo $(date +%s)
}

# $1: start timer
elapsed_time(){
    echo $(echo $1 $(get_timer) | awk '{ printf "%0.2f",($2-$1)/60 }')
}

show_elapsed_time(){
    msg "Time %s: %s minutes..." "$1" "$(elapsed_time $2)"
}

create_torrent() {
    info "Creating torrent of $IMAGE..."
    cd $IMGDIR/
    mktorrent -v -a udp://tracker.opentrackr.org:1337 -w https://osdn.net/projects/manjaro-arm/storage/$DEVICE/$EDITION/$VERSION/$IMAGE -o $IMAGE.torrent $IMAGE
}

checksum_img() {
    # Create checksums for the image
    info "Creating checksums for [$IMAGE]..."
    cd $IMGDIR/
    sha1sum $IMAGE > $IMAGE.sha1
    sha256sum $IMAGE > $IMAGE.sha256
    info "Creating signature for [$IMAGE]..."
    gpg --detach-sign -u $GPGMAIL "$IMAGE"
    if [ ! -f "$IMAGE.sig" ]; then
        echo "Image not signed. Aborting..."
        exit 1
    fi
}

img_upload() {
    # Upload image + checksums to image server
    msg "Uploading image and checksums to server..."
    info "Please use your server login details..."
    img_name=${IMAGE%%.*}
    rsync -raP $img_name* $STORAGE_USER@$OSDN/$DEVICE/$EDITION/$VERSION/
}

create_rootfs_pkg() {
    msg "Building $PACKAGE for $ARCH..."
    # Remove old rootfs if it exists
    if [ -d $CHROOTDIR ]; then
        info "Removing old rootfs..."
        rm -rf $CHROOTDIR
    fi
    msg "Creating rootfs..."
    # cd to rootfs
    mkdir -p $CHROOTDIR
    # basescrap the rootfs filesystem
    info "Switching branch to $BRANCH..."
    sed -i s/"arm-stable"/"arm-$BRANCH"/g $LIBDIR/pacman.conf.$ARCH
    $LIBDIR/pacstrap -G -M -C $LIBDIR/pacman.conf.$ARCH $CHROOTDIR fakeroot-qemu base-devel
    echo "Server = $BUILDSERVER/arm-$BRANCH/\$repo/\$arch" > $CHROOTDIR/etc/pacman.d/mirrorlist
    sed -i s/"arm-$BRANCH"/"arm-stable"/g $LIBDIR/pacman.conf.$ARCH
    # Enable cross architecture Chrooting
    cp /usr/bin/qemu-aarch64-static $CHROOTDIR/usr/bin/

    msg "Configuring rootfs for building..."
    $NSPAWN $CHROOTDIR pacman-key --init 1> /dev/null 2>&1
    $NSPAWN $CHROOTDIR pacman-key --populate archlinuxarm manjaro manjaro-arm 1> /dev/null 2>&1
    cp $LIBDIR/makepkg $CHROOTDIR/usr/bin/
    $NSPAWN $CHROOTDIR chmod +x /usr/bin/makepkg 1> /dev/null 2>&1
    rm -f $CHROOTDIR/etc/ssl/certs/ca-certificates.crt
    rm -f $CHROOTDIR/etc/ca-certificates/extracted/tls-ca-bundle.pem
    cp -a /etc/ssl/certs/ca-certificates.crt $CHROOTDIR/etc/ssl/certs/
    cp -a /etc/ca-certificates/extracted/tls-ca-bundle.pem $CHROOTDIR/etc/ca-certificates/extracted/
    sed -i s/'#PACKAGER="John Doe <john@doe.com>"'/"$PACKAGER"/ $CHROOTDIR/etc/makepkg.conf
    sed -i s/'#MAKEFLAGS="-j2"'/'MAKEFLAGS="-j$(nproc)"'/ $CHROOTDIR/etc/makepkg.conf
    sed -i s/'COMPRESSXZ=(xz -c -z -)'/'COMPRESSXZ=(xz -c -z - --threads=0)'/ $CHROOTDIR/etc/makepkg.conf
    $NSPAWN $CHROOTDIR pacman -Syy
}

create_rootfs_img() {
    #Check if device file exists
    if [ ! -f "$PROFILES/arm-profiles/devices/$DEVICE" ]; then 
        echo 'Invalid device '$DEVICE', please choose one of the following'
        echo "$(ls $PROFILES/arm-profiles/devices/)"
        exit 1
    fi
    #check if edition file exists
    if [ ! -f "$PROFILES/arm-profiles/editions/$EDITION" ]; then 
        echo 'Invalid edition '$EDITION', please choose one of the following'
        echo "$(ls $PROFILES/arm-profiles/editions/)"
        exit 1
    fi
    msg "Creating image of $EDITION for $DEVICE..."
    # Remove old rootfs if it exists
    if [ -d $ROOTFS_IMG/rootfs_$ARCH ]; then
        info "Removing old rootfs..."
        rm -rf $ROOTFS_IMG/rootfs_$ARCH
    fi
    mkdir -p $ROOTFS_IMG/rootfs_$ARCH
    if [[ "$KEEPROOTFS" = "false" ]]; then
        rm -rf $ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz*
        # fetch and extract rootfs
        info "Downloading latest $ARCH rootfs..."
        cd $ROOTFS_IMG
        wget -q --show-progress --progress=bar:force:noscroll https://osdn.net/projects/manjaro-arm/storage/.rootfs/Manjaro-ARM-$ARCH-latest.tar.gz
    fi
    #also fetch it, if it does not exist
    if [ ! -f "$ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz" ]; then
        cd $ROOTFS_IMG
        wget -q --show-progress --progress=bar:force:noscroll https://osdn.net/projects/manjaro-arm/storage/.rootfs/Manjaro-ARM-$ARCH-latest.tar.gz
    fi
    
    info "Extracting $ARCH rootfs..."
    bsdtar -xpf $ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz -C $ROOTFS_IMG/rootfs_$ARCH
    
    info "Setting up keyrings..."
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman-key --init 1>/dev/null || abort
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman-key --populate archlinux archlinuxarm manjaro manjaro-arm 1>/dev/null || abort
    
    info "Setting branch to $BRANCH..."
    echo "Server = $BUILDSERVER/arm-$BRANCH/\$repo/\$arch" > $ROOTFS_IMG/rootfs_$ARCH/etc/pacman.d/mirrorlist
    
    msg "Installing packages for $EDITION edition on $DEVICE..."
    # Install device and editions specific packages
    mount -o bind $PKGDIR/pkg-cache $PKG_CACHE
    case "$EDITION" in
        cubocore|phosh|plasma-mobile|plasma-mobile-dev)
            $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -Syyu base systemd systemd-libs manjaro-system manjaro-release $PKG_EDITION $PKG_DEVICE --noconfirm || abort
            ;;
        *)
            $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -Syyu base systemd systemd-libs dialog manjaro-system manjaro-release $PKG_EDITION $PKG_DEVICE --noconfirm || abort
            ;;
    esac
    if [[ ! -z "$ADD_PACKAGE" ]]; then
        info "Installing local package {$ADD_PACKAGE} to rootfs..."
        cp -ap $ADD_PACKAGE $PKG_CACHE/
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -U /var/cache/pacman/pkg/$ADD_PACKAGE --noconfirm || abort
    fi
    info "Generating mirrorlist..."
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman-mirrors --method random --api --set-branch $BRANCH 1> /dev/null 2>&1
    
    info "Enabling services..."
    # Enable services
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl enable getty.target haveged.service 1>/dev/null

    while read service; do
        if [ -e $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/$service ]; then
            info "Enabling $service ..."
            $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl enable $service 1>/dev/null
        else
            echo "$service not found in rootfs. Skipping."
        fi
    done < $srv_list
    
    #disabling services depending on edition
    case "$EDITION" in
        mate|i3|xfce|lxqt)
            $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl disable lightdm.service
            $NSPAWN $ROOTFS_IMG/rootfs_$ARCH usermod --expiredate= lightdm
            ;;
        sway)
            $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl disable greetd.service
            ;;
        minimal|server|plasma-mobile|plasma-mobile-dev|phosh|cubocore|lomiri)
            echo "No display manager to disable in $EDITION..."
            ;;
        *)
            $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl disable sddm.service
            $NSPAWN $ROOTFS_IMG/rootfs_$ARCH usermod --expiredate= sddm
            ;;
    esac

    info "Applying overlay for $EDITION edition..."
    cp -ap $PROFILES/arm-profiles/overlays/$EDITION/* $ROOTFS_IMG/rootfs_$ARCH/
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl enable dhcpcd sshd avahi-daemon oem-boot motd  1>/dev/null

    info "Setting up system settings..."
    #system setup
    rm -f $ROOTFS_IMG/rootfs_$ARCH/etc/ssl/certs/ca-certificates.crt
    rm -f $ROOTFS_IMG/rootfs_$ARCH/etc/ca-certificates/extracted/tls-ca-bundle.pem
    cp -a /etc/ssl/certs/ca-certificates.crt $ROOTFS_IMG/rootfs_$ARCH/etc/ssl/certs/
    cp -a /etc/ca-certificates/extracted/tls-ca-bundle.pem $ROOTFS_IMG/rootfs_$ARCH/etc/ca-certificates/extracted/
    echo "manjaro-arm" | tee --append $ROOTFS_IMG/rootfs_$ARCH/etc/hostname 1> /dev/null 2>&1
    case "$EDITION" in
        cubocore|plasma-mobile|plasma-mobile-dev)
            echo "No OEM setup!"
            ;;
        phosh|lomiri)
            echo "Configure autologin for user 'manjaro'"
            $NSPAWN $ROOTFS_IMG/rootfs_$ARCH groupadd -r autologin
            $NSPAWN $ROOTFS_IMG/rootfs_$ARCH gpasswd -a manjaro autologin
            ;;
        *)
            echo "Enabling SSH login for root user for headless setup..."
            sed -i s/"#PermitRootLogin prohibit-password"/"PermitRootLogin yes"/g $ROOTFS_IMG/rootfs_$ARCH/etc/ssh/sshd_config
            sed -i s/"#PermitEmptyPasswords no"/"PermitEmptyPasswords yes"/g $ROOTFS_IMG/rootfs_$ARCH/etc/ssh/sshd_config
            echo "NOT Enabling autologin for first setup..."
            #mv $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/getty\@.service $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/getty\@.service.bak
            #cp $LIBDIR/getty\@.service $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/getty\@.service
            ;;
    esac
    
    # Lomiri services Temporary in function until it is moved to an individual package.
    if [[ "$EDITION" = "lomiri" ]]; then
        echo "Fix indicators"
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH mkdir -pv /usr/lib/systemd/user/ayatana-indicators.target.wants
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/lib/systemd/user/ayatana-indicator-datetime.service /usr/lib/systemd/user/ayatana-indicators.target.wants/ayatana-indicator-datetime.service
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/lib/systemd/user/ayatana-indicator-display.service /usr/lib/systemd/user/ayatana-indicators.target.wants/ayatana-indicator-display.service
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/lib/systemd/user/ayatana-indicator-messages.service /usr/lib/systemd/user/ayatana-indicators.target.wants/ayatana-indicator-messages.service
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/lib/systemd/user/ayatana-indicator-power.service /usr/lib/systemd/user/ayatana-indicators.target.wants/ayatana-indicator-power.service
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/lib/systemd/user/ayatana-indicator-session.service /usr/lib/systemd/user/ayatana-indicators.target.wants/ayatana-indicator-session.service
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/lib/systemd/user/ayatana-indicator-sound.service /usr/lib/systemd/user/ayatana-indicators.target.wants/ayatana-indicator-sound.service
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/lib/systemd/user/indicator-network.service /usr/lib/systemd/user/ayatana-indicators.target.wants/indicator-network.service
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/lib/systemd/user/indicator-transfer.service /usr/lib/systemd/user/ayatana-indicators.target.wants/indicator-transfer.service
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/lib/systemd/user/indicator-bluetooth.service /usr/lib/systemd/user/ayatana-indicators.target.wants/indicator-bluetooth.service
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/lib/systemd/user/indicator-location.service /usr/lib/systemd/user/ayatana-indicators.target.wants/indicator-location.service
        
        echo "Fix background"
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH mkdir -pv /usr/share/backgrounds
        #$NSPAWN $ROOTFS_IMG/rootfs_$ARCH convert -verbose /usr/share/wallpapers/manjaro.jpg /usr/share/wallpapers/manjaro.png
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/share/wallpapers/manjaro.png /usr/share/backgrounds/warty-final-ubuntu.png
        
        echo "Fix Maliit"
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH mkdir -pv /usr/lib/systemd/user/graphical-session.target.wants
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/lib/systemd/user/maliit-server.service /usr/lib/systemd/user/graphical-session.target.wants/maliit-server.service
    fi
    ### Lomiri Temporary service ends here  
    
    echo "Correcting permissions from overlay..."
    chown -R root:root $ROOTFS_IMG/rootfs_$ARCH/etc
    if [[ "$EDITION" != "minimal" && "$EDITION" != "server" ]]; then
        chown root:polkitd $ROOTFS_IMG/rootfs_$ARCH/etc/polkit-1/rules.d
    fi
    
    info "Cleaning rootfs for unwanted files..."
    prune_cache
    rm $ROOTFS_IMG/rootfs_$ARCH/usr/bin/qemu-aarch64-static
    rm -rf $ROOTFS_IMG/rootfs_$ARCH/var/log/*
    rm -rf $ROOTFS_IMG/rootfs_$ARCH/etc/*.pacnew
    rm -rf $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/systemd-firstboot.service
    rm -rf $ROOTFS_IMG/rootfs_$ARCH/etc/machine-id

    if [[ "$FACTORY" = "true" ]]; then
        info "Making settings for factory specific image..."
        case "$EDITION" in
            kde-plasma)
                sed -i s/"manjaro-arm.png"/"manjaro-pine64-2b.png"/g $ROOTFS_IMG/rootfs_$ARCH/etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc
                echo "$EDITION - $(date +'%y'.'%m'.'%d')" | tee --append $ROOTFS_IMG/rootfs_$ARCH/etc/factory-version 1> /dev/null 2>&1
                ;;
            xfce)
                sed -i s/"manjaro-arm.png"/"manjaro-pine64-2b.png"/g $ROOTFS_IMG/rootfs_$ARCH/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml
                sed -i s/"manjaro-arm.png"/"manjaro-pine64-2b.png"/g $ROOTFS_IMG/rootfs_$ARCH/etc/lightdm/lightdm-gtk-greeter.conf
                echo "$EDITION - $(date +'%y'.'%m'.'%d')" | tee --append $ROOTFS_IMG/rootfs_$ARCH/etc/factory-version 1> /dev/null 2>&1
                ;;
        esac
    else
        echo "$DEVICE - $EDITION - $VERSION" | tee --append $ROOTFS_IMG/rootfs_$ARCH/etc/manjaro-arm-version 1> /dev/null 2>&1
    fi

    msg "Creating package list: [$IMGDIR/$IMGNAME-pkgs.txt]"
    pacman -Qr "$ROOTFS_IMG/rootfs_$ARCH/" > "$IMGDIR/$IMGNAME-pkgs.txt" 2>/dev/null

    msg "$DEVICE $EDITION rootfs complete"
}

create_emmc_install() {
    msg "Creating eMMC install image of $EDITION for $DEVICE..."
    # Remove old rootfs if it exists
    if [ -d $CHROOTDIR ]; then
        info "Removing old rootfs..."
        rm -rf $CHROOTDIR
    fi
    mkdir -p $CHROOTDIR
    if [[ "$KEEPROOTFS" = "false" ]]; then
        rm -rf $ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz*
        # fetch and extract rootfs
        info "Downloading latest $ARCH rootfs..."
        cd $ROOTFS_IMG
        wget -q --show-progress --progress=bar:force:noscroll https://osdn.net/projects/manjaro-arm/storage/.rootfs/Manjaro-ARM-$ARCH-latest.tar.gz
    fi
    #also fetch it, if it does not exist
    if [ ! -f "$ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz" ]; then
        cd $ROOTFS_IMG
        wget -q --show-progress --progress=bar:force:noscroll https://osdn.net/projects/manjaro-arm/storage/.rootfs/Manjaro-ARM-$ARCH-latest.tar.gz
    fi
    
    info "Extracting $ARCH rootfs..."
    bsdtar -xpf $ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz -C $CHROOTDIR
    
    info "Setting up keyrings..."
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman-key --init || abort
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman-key --populate archlinuxarm manjaro manjaro-arm || abort
    
    msg "Installing packages for eMMC installer edition of $EDITION on $DEVICE..."
    # Install device and editions specific packages
    echo "Server = $BUILDSERVER/arm-$BRANCH/\$repo/\$arch" > $CHROOTDIR/etc/pacman.d/mirrorlist
    mount -o bind $PKGDIR/pkg-cache $PKG_CACHE
    $NSPAWN $CHROOTDIR pacman -Syyu base manjaro-system manjaro-release manjaro-arm-emmc-flasher $PKG_EDITION $PKG_DEVICE --noconfirm

    info "Enabling services..."
    # Enable services
    $NSPAWN $CHROOTDIR systemctl enable getty.target haveged.service 1> /dev/null 2>&1
    
    info "Setting up system settings..."
    # setting hostname
    echo "manjaro-arm" | tee --append $ROOTFS_IMG/rootfs_$ARCH/etc/hostname 1> /dev/null 2>&1
    # enable autologin
    mv $CHROOTDIR/usr/lib/systemd/system/getty\@.service $CHROOTDIR/usr/lib/systemd/system/getty\@.service.bak
    cp $LIBDIR/getty\@.service $CHROOTDIR/usr/lib/systemd/system/getty\@.service
    
    if [ -f $IMGDIR/Manjaro-ARM-$EDITION-$DEVICE-$VERSION.img.xz ]; then
        info "Copying local $DEVICE $EDITION image..."
        cp $IMGDIR/Manjaro-ARM-$EDITION-$DEVICE-$VERSION.img.xz $CHROOTDIR/var/tmp/Manjaro-ARM.img.xz
        sync
    else
        info "Downloading $DEVICE $EDITION image..."
        cd $CHROOTDIR/var/tmp/
        wget -q --show-progress --progress=bar:force:noscroll -O Manjaro-ARM.img.xz https://osdn.net/projects/manjaro-arm/storage/$DEVICE/$EDITION/$VERSION/Manjaro-ARM-$EDITION-$DEVICE-$VERSION.img.xz
    fi
    
    info "Cleaning rootfs for unwanted files..."
    prune_cache
    rm $CHROOTDIR/usr/bin/qemu-aarch64-static
    rm -rf $CHROOTDIR/var/log/*
    rm -rf $CHROOTDIR/etc/*.pacnew
    rm -rf $CHROOTDIR/usr/lib/systemd/system/systemd-firstboot.service
    rm -rf $CHROOTDIR/etc/machine-id
}

create_img() {
    msg "Finishing image for $DEVICE $EDITION edition..."
    info "Creating partitions..."

    ARCH='aarch64'
    
    SIZE=$(du -s --block-size=MB $CHROOTDIR | awk '{print $1}' | sed -e 's/MB//g')
    EXTRA_SIZE=300
    REAL_SIZE=`echo "$(($SIZE+$EXTRA_SIZE))"`
    
    #making blank .img to be used
    dd if=/dev/zero of=$IMGDIR/$IMGNAME.img bs=1M count=$REAL_SIZE 1> /dev/null 2>&1

    #probing loop into the kernel
    modprobe loop 1> /dev/null 2>&1

    #set up loop device
    LDEV=`losetup -f`
    DEV=`echo $LDEV | cut -d "/" -f 3`

    #mount image to loop device
    losetup $LDEV $IMGDIR/$IMGNAME.img 1> /dev/null 2>&1


    # Create partitions
    #Clear first 32mb
    dd if=/dev/zero of=${LDEV} bs=1M count=32 1> /dev/null 2>&1
    #partition with boot and root
    parted -s $LDEV mklabel msdos 1> /dev/null 2>&1
    parted -s $LDEV mkpart primary fat32 32M 256M 1> /dev/null 2>&1
    START=`cat /sys/block/$DEV/${DEV}p1/start`
    SIZE=`cat /sys/block/$DEV/${DEV}p1/size`
    END_SECTOR=$(expr $START + $SIZE)
    parted -s $LDEV mkpart primary ext4 "${END_SECTOR}s" 100% 1> /dev/null 2>&1
    partprobe $LDEV 1> /dev/null 2>&1
    mkfs.vfat "${LDEV}p1" -n BOOT_MNJRO 1> /dev/null 2>&1
    mkfs.ext4 -O ^metadata_csum,^64bit "${LDEV}p2" -L ROOT_MNJRO 1> /dev/null 2>&1

    #copy rootfs contents over to the FS
    info "Copying files to image..."
    mkdir -p $TMPDIR/root
    mkdir -p $TMPDIR/boot
    mount ${LDEV}p1 $TMPDIR/boot
    mount ${LDEV}p2 $TMPDIR/root
    cp -ra $ROOTFS_IMG/rootfs_$ARCH/* $TMPDIR/root/
    mv $TMPDIR/root/boot/* $TMPDIR/boot
        
    # Flash bootloader
    info "Flashing bootloader..."
    case "$DEVICE" in
    # AMLogic uboots
        oc2)
            dd if=$TMPDIR/boot/bl1.bin.hardkernel of=${LDEV} conv=fsync bs=1 count=442 1> /dev/null 2>&1
            dd if=$TMPDIR/boot/bl1.bin.hardkernel of=${LDEV} conv=fsync bs=512 skip=1 seek=1 1> /dev/null 2>&1
            dd if=$TMPDIR/boot/u-boot.gxbb of=${LDEV} conv=fsync bs=512 seek=97 1> /dev/null 2>&1
            ;;
        on2|on2-plus|oc4)
            dd if=$TMPDIR/boot/u-boot.bin of=${LDEV} conv=fsync,notrunc bs=512 seek=1 1> /dev/null 2>&1
            ;;
        vim1|vim2|vim3)
            dd if=$TMPDIR/boot/$DEVICE.u-boot.bin of=${LDEV} conv=fsync,notrunc bs=442 count=1 1> /dev/null 2>&1
            dd if=$TMPDIR/boot/$DEVICE.u-boot.bin of=${LDEV} conv=fsync,notrunc bs=512 skip=1 seek=1 1> /dev/null 2>&1
            ;;
        edgev)
            dd if=$TMPDIR/boot/u-boot-rk3399-khadas-edge-v.img of=${LDEV} conv=fsync bs=1 count=442 1> /dev/null 2>&1
            dd if=$TMPDIR/boot/u-boot-rk3399-khadas-edge-v.img of=${LDEV} conv=fsync bs=512 skip=1 seek=1 1> /dev/null 2>&1
            ;;
        # Allwinner uboots
        pinebook|pine64-lts|pine64|pinephone|pinetab|pine-h64)
            dd if=$TMPDIR/boot/u-boot-sunxi-with-spl-$DEVICE.bin of=${LDEV} conv=fsync bs=8k seek=1 1> /dev/null 2>&1
            ;;
        # Rockchip uboots
        pbpro|rockpro64|rockpi4b|rockpi4c|nanopc-t4|rock64|roc-cc)
            dd if=$TMPDIR/boot/idbloader.img of=${LDEV} seek=64 conv=notrunc,fsync 1> /dev/null 2>&1
            dd if=$TMPDIR/boot/u-boot.itb of=${LDEV} seek=16384 conv=notrunc,fsync 1> /dev/null 2>&1
            ;;
        # For PBP BSP uboot
        #pbpro)
        #    dd if=$TMPDIR/boot/idbloader.img of=${LDEV} seek=64 conv=notrunc,fsync 1> /dev/null 2>&1
        #    dd if=$TMPDIR/boot/uboot.img of=${LDEV} seek=16384 conv=notrunc,fsync 1> /dev/null 2>&1
        #    dd if=$TMPDIR/boot/trust.img of=${LDEV} seek=24576 conv=notrunc,fsync 1> /dev/null 2>&1
        #    ;;
    esac
    
    # Clean up
    info "Cleaning up image..."
    umount $TMPDIR/root
    umount $TMPDIR/boot
    losetup -d $LDEV 1> /dev/null 2>&1
    rm -r $TMPDIR/root $TMPDIR/boot
    partprobe $LDEV 1> /dev/null 2>&1
    chmod 666 $IMGDIR/$IMGNAME.img
}

create_bmap() {
    if [ ! -e /usr/bin/bmaptool ]; then
        echo "'bmap-tools' are not installed. Skipping."
    else
        info "Creating bmap."
        cd ${IMGDIR}
        rm ${IMGNAME}.img.bmap 2>/dev/null
        bmaptool create -o ${IMGNAME}.img.bmap ${IMGNAME}.img
    fi
}

compress() {
    if [ -f $IMGDIR/$IMGNAME.img.xz ]; then
        info "Removing existing compressed image file {$IMGNAME.img.xz}..."
        rm -rf $IMGDIR/$IMGNAME.img.xz
    fi
    info "Compressing $IMGNAME.img..."
    #compress img
    cd $IMGDIR
    xz -zv --threads=0 $IMGNAME.img
    chmod 666 $IMGDIR/$IMGNAME.img.xz

    info "Removing rootfs_$ARCH"
    rm -rf $CHROOTDIR
}

build_pkg() {
    # Install local package to rootfs before building
    if [[ ! -z "$ADD_PACKAGE" ]]; then
        info "Installing local package {$ADD_PACKAGE} to rootfs..."
        cp -ap $ADD_PACKAGE $PKG_CACHE
        $NSPAWN $CHROOTDIR pacman -U /var/cache/pacman/pkg/$ADD_PACKAGE --noconfirm
    fi
    # Build the actual package
    msg "Copying build directory {$PACKAGE} to rootfs..."
    $NSPAWN $CHROOTDIR mkdir build 1> /dev/null 2>&1
    mount -o bind "$PACKAGE" $CHROOTDIR/build
    msg "Building {$PACKAGE}..."
    mount -o bind $PKGDIR/pkg-cache $PKG_CACHE
    $NSPAWN $CHROOTDIR pacman -Syu 1> /dev/null 2>&1
    if [[ $INSTALL_NEW = true ]]; then
        $NSPAWN $CHROOTDIR --chdir=/build/ makepkg -Asci --noconfirm
    else
        $NSPAWN $CHROOTDIR --chdir=/build/ makepkg -Asc --noconfirm
    fi
}

export_and_clean() {
    if ls $CHROOTDIR/build/*.pkg.tar.* 1> /dev/null 2>&1; then
        #pull package out of rootfs
        msg "Package Succeeded..."
        info "Extracting finished package out of rootfs..."
        mkdir -p $PKGDIR/$ARCH
        cp $CHROOTDIR/build/*.pkg.tar.* $PKGDIR/$ARCH/
        chown -R $SUDO_USER $PKGDIR
        msg "Package saved as {$PACKAGE} in {$PKGDIR/$ARCH}..."
        umount $CHROOTDIR/build

        #clean up rootfs
        info "Cleaning build files from rootfs"
        rm -rf $CHROOTDIR/build/
    else
        msg "!!!!! Package failed to build !!!!!"
        umount $CHROOTDIR/build
        prune_cache
        rm -rf $CHROOTDIR/build/
        exit 1
    fi
}

get_profiles() {
    if ls $PROFILES/arm-profiles/* 1> /dev/null 2>&1; then
        cd $PROFILES/arm-profiles
        git pull
    else
        cd $PROFILES
        git clone https://gitlab.manjaro.org/manjaro-arm/applications/arm-profiles.git
    fi
}
