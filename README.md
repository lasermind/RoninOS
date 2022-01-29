To replicate this build you must do the following:

1) Have Manjaro Linux (x86-64)
2) Install make with `sudo pacman -qS --noconfirm make`
3) Run `make install` to install
4) Edit "$HOME"/.gpg-passwd with password to RoninDojo gpg key
5) Run `roninos --user="gpg@ronindojo.io" --generate`
6) Run `shred -fuzn24 "$HOME"/.gpg-passwd` (optional but recommended)

File structure:

- roninos: Build script to generate Manjaro OS images for various single board computers.
- tool-libs/functions.sh: Contains modifications specific for RoninOS under the buildrootfs function. This mainly is used to enable oem-boot service to run at boot.
- overlays/RoninOS/usr/local/sbin/ronin-oem-fast.sh: This is a modification of the Manjaro Linux ARM oem script to ensure other services are enabled and user is setup during boot. This is also where the username, passwd, locale, keyboard are setup and randomly generated username & passwords are created and stored in a tmp file located at /home/"${USER}"/.config/RoninDojo/info.json for use with the RoninUI.
- overlays/RoninOS/usr/local/sbin/ronin-setup.sh: Automates the install of RoninDojo to allow end users to access RoninDojo UI during install process.
- overlays/RoninOS/etc/avahi: Configuration for the ronindojo.local access.
- overlays/RoninOS/etc/plymouth: Custom boot theme for RoninOS.
- overlays/RoninOS/systemd/system/getty@tty1.service.d/override.conf: Enable auto login to terminal on initial boot.
- services/RoninOS: Services that execute on boot.
