install:
	if [ ! -d /opt/RoninOS/repo ]; then \
		sudo mkdir -p /opt/RoninOS/repo;\
		git clone https://code.samourai.io/ronindojo/RoninOS /opt/RoninOS/repo/RoninOS;\

		sudo cp -f /opt/RoninOS/repo/RoninOStools-lib/functions.sh /usr/share/manjaro-arm-tools/lib/;\
		sudo cp -f /opt/RoninOS/repo/RoninOS/editions/RoninOS /usr/share/manjaro-arm-tools/profiles/arm-profiles/editions/;\
		sudo cp -f /opt/RoninOS/repo/RoninOS/services/RoninOS /usr/share/manjaro-arm-tools/profiles/arm-profiles/services/;\
		sudo cp -rf "$HOME"/.ronindojo/RoninOS/overlays/RoninOS /usr/share/manjaro-arm-tools/profiles/arm-profiles/overlays/RoninOS;\

		sudo cp roninos /usr/local/sbin/;\
		sudo chmod +x /usr/local/sbin/roninos;\
	else \
		sudo bash -c "cd /opt/RoninOS/repo/RoninOS";\
		git pull -r;\
	fi

	if ! hash buildarmimg 2>/dev/null; then sudo pacman -qS --noconfirm manjaro-arm-tools; fi

uninstall:
	if [ -d /opt/RoninOS ]; then \
		sudo rm -rf /opt/RoninOS;\
		sudo rm -rf /usr/share/manjaro-arm-tools/profiles/arm-profiles/{services,editions,overlays}/RoninOS;\
	fi

	if hash buildarmimg 2>/dev/null; then sudo pacman -R --noconfirm manjaro-arm-tools; fi