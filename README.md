**To replicate this build you must do the following:**

1) Follow the setup guide provided by armbian https://docs.armbian.com/Developer-Guide_Build-Preparation/
2) Clone this repo and run `cp -Rv ~/RoninOS/customize-image.sh ~/build/userpatches/customize-image.sh && cp -Rv ~/RoninOS ~/build/userpatches/overlay/`
3) Start armbian build process - `cd ~/build && sudo ./compile.sh COMPRESSION= "gz, sha"`
4) From here Select: `Full OS Image for flashing`-> `Do not change the kernal configuration` -> `Rockpro64 (or board of choice)` -> `current` -> `bullseye` -> `(server)` -> `Minimal image with  console interface`.
5) Let it run and relax. (Takes 45-90 min)

**File structure:**

- _customize-image.sh:_ Customize the image during the building process. Setting username and password (random password). clone repos, modify tor and prep the UI. 

If any changes occur moving forward this repo will be updated. 
If you'd like to customize anything about the build, utilize the armbian guides and/or edit the `customize-image.sh` file.
