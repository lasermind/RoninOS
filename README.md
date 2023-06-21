**To make a build you must do the following:**

1) Change the current working directory to where your curent user has write permissions, for example `cd ~`
2) run `git clone --depth=1 --branch=main https://github.com/armbian/build`
3) Clone this repo with `git clone https://code.samourai.io/ronindojo/RoninOS.git`
4) run `mkdir -p build/userpatches/overlay/`
5) run `cp -Rv RoninOS/customize-image.sh build/userpatches/customize-image.sh && cp -Rv RoninOS build/userpatches/overlay/`
6) change the working directory to the root of the build project with `cd build`
7) Start armbian build process by running the command `./compile.sh BOARD=rockpro64 BRANCH=current BUILD_DESKTOP=no BUILD_MINIMAL=yes KERNEL_CONFIGURE=no RELEASE=bullseye`
8) Let it run and relax. (Takes 45-90 min)
9) You can find the image files in the directory `output` that's in the root of the build project

**Resources:**

- https://docs.armbian.com/Developer-Guide_Build-Preparation/

**File structure:**

- _customize-image.sh:_ Customize the image during the building process. Setting username and password (random password). clone repos, modify tor and prep the UI. 

If any changes occur moving forward this repo will be updated. 
If you'd like to customize anything about the build, utilize the armbian guides and/or edit the `customize-image.sh` file.
