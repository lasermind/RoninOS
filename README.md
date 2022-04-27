**To replicate this build you must do the following:**

1) Have Manjaro Linux (x86-64)
2) Install make with `sudo pacman -qS --noconfirm make`
3) Run `make install` to install
4) Edit "$HOME"/.gpg-passwd with password to RoninDojo gpg key
5) Run `roninos --user="gpg@ronindojo.io" --generate`
6) Run `shred -fuzn24 "$HOME"/.gpg-passwd` (optional but recommended)

**To check on setup scripts:**

1) Flash the image you created using the steps above to micro SD card
2) Make sure HDMI screen, keyboard, and ethernet cable are plugged in
3) Power on the device 
4) Run `journalctl -u ronin-setup -f`

**File structure:**

- _roninos:_ Build script to generate Manjaro OS images for various single board computers.
- _tool-libs/functions.sh:_ Contains modifications specific for RoninOS under the buildrootfs function. This mainly is used to enable oem-boot service to run at boot.
- _overlays/RoninOS/usr/local/sbin/ronin-oem-fast.sh:_ This is a modification of the Manjaro Linux ARM oem script to ensure other services are enabled and user is setup during boot. This is also where the username, passwd, locale, keyboard are setup and randomly generated username & passwords are created and stored in a tmp file located at /home/"${USER}"/.config/RoninDojo/info.json for use with the RoninUI.
- _overlays/RoninOS/usr/local/sbin/ronin-setup.sh:_ Automates the install of RoninDojo to allow end users to access RoninDojo UI during install process.
- _overlays/RoninOS/etc/avahi:_ Configuration for the ronindojo.local access.
- _overlays/RoninOS/etc/plymouth:_ Custom boot theme for RoninOS.
- _overlays/RoninOS/systemd/system/getty@tty1.service.d/override.conf:_ Enable auto login to terminal on initial boot.
- _services/RoninOS:_ Services that execute on boot.
