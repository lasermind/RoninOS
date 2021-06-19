To replicate this build you must do the following:

1) Have Manjaro (x86-64)
2) Install manjaro-arm-tools
3) Copy the functions.sh file from tools-lib to /usr/share/manjaro-arm-tools/lib/
4) Copy each of the files from editions, services, and overlays to /user/share/manjaro-arm-tools/profile/arm-profiles
5) Give root permissions to all files (the defualt setting of the manjaro-arm-tools)
6) Run `sudo buildarmimg -d rockpro64 -e RoninOS`

Notes:

- The functions.sh contains modifications specific for roninOS under the buildrootfs function. This mainly is used to enable oem-boot.service to run off boot.
- Overlay contains files to make the setup more effecticent but most importantly are the files in /opt/
  - a git repo of RoninDojo 
  - the ronin-oem-fast.sh (this is a modification of the manjaro-arm oem script to ensure other services are enabled and user is setup during boot. Then reboot the device.
  - In /opt/setup is the ronin-setup.sh:
     - This script is what gives and later removes the permissions of admin user
     - Then runs the _main function from ronin, install-system.sh, and install-dojo.sh
