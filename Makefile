install:
	if ! hash buildarmimg 2>/dev/null; then \
		sudo pacman -qS --noconfirm manjaro-arm-tools;\
		sudo getarmprofiles -f;\
	fi;\
	sudo cp -f tools-lib/functions.sh /usr/share/manjaro-arm-tools/lib/;\
	sudo cp -f editions/RoninOS /usr/share/manjaro-arm-tools/profiles/arm-profiles/editions/;\
	sudo cp -f services/RoninOS /usr/share/manjaro-arm-tools/profiles/arm-profiles/services/;\
	sudo cp -rf overlays/RoninOS /usr/share/manjaro-arm-tools/profiles/arm-profiles/overlays/RoninOS;\
	sudo cp roninos /usr/local/sbin/;\
	sudo chmod +x /usr/local/sbin/roninos

uninstall:
	if hash buildarmimg 2>/dev/null; then sudo pacman -R --noconfirm manjaro-arm-tools; fi;\
	sudo rm -rf /usr/share/manjaro-arm-tools
