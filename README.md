To replicate this build you must do the following:

1) Have Manjaro Linux (x86-64)
2) Install manjaro-arm-tools
3) Copy the functions.sh file from tools-lib to /usr/share/manjaro-arm-tools/lib/
4) Copy each of the files from editions, services, and overlays to /usr/share/manjaro-arm-tools/profile/arm-profiles
5) Give root permissions to all files (the default setting of the manjaro-arm-tools)
6) Run `sudo buildarmimg -d rockpro64 -e RoninOS`

File structure:

/tool-libs/functions.sh:
  - Contains modifications specific for RoninOS under the buildrootfs function. This mainly is used to enable oem-boot.service to run off boot.
/overlays/RoninOS:
  - Contains files to make the setup more efficient but most importantly are the files located in /usr/local/sbin
/overlays/usr/local/sbin/ronin-oem-fast.sh:
  - This is a modification of the manjaro-arm oem script to ensure other services are enabled and user is setup during boot. This is also where the username, passwd, locale, keyboard are setup. randomly generated username & passwords are created and stored in a tmp file located at /home/"${USER}"/.config/RoninDojo/info.json for use with the UI initial setup.
/overlays/usr/local/sbin/ronin-setup.sh:
  - Automates the install of RoninDojo to allow end users to access RoninDojo UI during install process