
##
## This script will equip the Armbian build system with the RoninOS repo as an overlay
##


# Terminal colours
CDEF="\033[0m"
CGREEN="\033[0;32m"
CLGREEN="\033[1;32m"
CRED="\033[0;31m"

# Global vars
FILENAME=$(basename -- "$0";)



# Check for correct place of RoninOS repo
if [ ! -f ~/RoninOS/${FILENAME} ]; then
    echo " "
    echo -e "${FILENAME}: [${CRED} Failure ${CDEF}]"
    echo -e "RoninOS repo seems to not be present in the expected directory"
    echo -e "Please make sure you cloned it to [${CGREEN} ~/RoninOS ${CDEF}] to use the automated scripts"
    echo -e "If you want to operate manually, please refer to [${CGREEN} README.md ${CDEF}] and/or examine what the scripts intended to do"

    exit 0
fi

# Check for Armbian build dir present
if [ ! -f ~/build/compile.sh ]; then
    echo " "
    echo -e "${FILENAME}: [${CRED} Failure ${CDEF}]"
    echo -e "Armbian build directory seems to not be present as expected"
    echo -e "Please make sure you cloned it completely to [${CGREEN} ~/build ${CDEF}] to use the automated scripts"
    echo -e "If you want to operate manually, please refer to [${CGREEN} README.md ${CDEF}] and/or examine what the scripts intended to do"

    exit 0
fi



# If not already present, prepare 'overlay' dir for Armbian build system
mkdir -p ~/build/userpatches/overlay

# Copy RoninOS build script for Armbian build system to use
cp -fp ~/RoninOS/customize-image.sh ~/build/userpatches/customize-image.sh

# Delete potentially existing RoninOS dir in overlay
rm -Rfd ~/build/userpatches/overlay/RoninOS

# Copy RoninOS files to Armbian 'overlay' dir
cp -Rp ~/RoninOS ~/build/userpatches/overlay/

# Remove unnecessary .sh scripts to not confuse the user with doublet files
rm -f ~/build/userpatches/overlay/RoninOS/*.sh

# Output an encouraging success message
echo " "
echo -e "${FILENAME}: [${CLGREEN} Success ${CDEF}]"
echo -e "The RoninOS scripts are now prepared in [${CGREEN} ~/build/userpatches/overlay/ ${CDEF}]"
echo -e "If needed, make your edits to [${CGREEN} ~/build/userpatches/${CLGREEN}customize-image.sh ${CDEF}]"
echo -e "To make your build, run [ ${CGREEN}~/RoninOS/${CLGREEN}02-compile-ronin-os.sh ${CDEF}] and choose your target board."
echo -e "You will find your image then in [${CGREEN} ~/build/output/images/ ${CDEF}]"

# Unset executable to self, to not be able to accidentally mess up the files any more
chmod 664 ~/RoninOS/01-stage-ronin-os.sh
echo " "
echo -e "${CLGREEN}Note:${CDEF} This script is now set to be ${CGREEN}not executable${CDEF} (644) any more –"\
      "to not have you in the situation to accidentally mess up your staged files."\
      "However, should you be willing to use it again, simply command [${CGREEN} chmod 755 ${FILENAME} ${CDEF}] first."

