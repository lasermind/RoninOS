
#
# This script will call the Armbian build script ('compile.sh') in the expected default directory,
# with all the necessary command line parameters recommended for RoninOS.
#
# Param 'BOARD' is left unset, to let an interactive list appear, where the user can
# pick the board of choice. For Tanto, the option would be 'rockpro64'.
#


~/build/./compile.sh \
    KERNEL_CONFIGURE=no \
    BRANCH=current \
    RELEASE=bullseye \
    BUILD_DESKTOP=no \
    BUILD_MINIMAL=yes \
    HOST=ronindojo \
    BOARD=

