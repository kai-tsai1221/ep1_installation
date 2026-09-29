#!/bin/bash

FAILED_SECTIONS=()

record_failed_section() {
    local failed_section="$1"
    local existing_section

    for existing_section in "${FAILED_SECTIONS[@]}"; do
        if [[ "$existing_section" == "$failed_section" ]]; then
            return
        fi
    done

    FAILED_SECTIONS+=("$failed_section")
}

run_checked() {
    local section="$1"
    shift

    "$@"
    local exit_code=$?

    if ((exit_code != 0)); then
        record_failed_section "$section"
        echo -e "\e[31mSEYOND: '$section' failed (exit code: $exit_code)\e[0m" >&2
    fi

    # Continue running the remaining installation sections.
    return 0
}

print_installation_summary() {
    local section

    echo
    echo "============================================================"
    echo "INSTALLATION SUMMARY"
    if ((${#FAILED_SECTIONS[@]} == 0)); then
        echo -e "\e[32mAll checked installation sections completed successfully.\e[0m"
    else
        echo -e "\e[31mThe following installation section(s) failed:\e[0m"
        for section in "${FAILED_SECTIONS[@]}"; do
            echo "  - $section"
        done
    fi
    echo "============================================================"
}

##change color of echo text in red (31):
# echo -e "\e[31mThis is red text\e[0m"
# echo -e "\e[31m\e[0m"


#====================================================================================================
# Set timezone
# What is the timezone for this machine?
echo "Select time zone:"
echo "1) West Coast Time"
echo "2) Mountain Time"
echo "3) Central Time"
echo "4) East Coast Time"
read -p "Enter your choice (1 or 2 or 3, or 4): " choice

if [ "$choice" == "1" ]; then
    run_checked "Set time zone" sudo timedatectl set-timezone America/Los_Angeles
    echo "Set to PST"
elif [ "$choice" == "2" ]; then
    run_checked "Set time zone" sudo timedatectl set-timezone America/Denver
    echo "Set to MST"
elif [ "$choice" == "3" ]; then
    run_checked "Set time zone" sudo timedatectl set-timezone America/Chicago
    echo "Set to CST"
elif [ "$choice" == "4" ]; then
    run_checked "Set time zone" sudo timedatectl set-timezone America/New_York
    echo "Set to EST"
else
    echo "Invalid option"
fi

#====================================================================================================
# change screen blank to never
echo -e "\e[36mSEYOND: changing Edgebox screen blank to never\e[0m"
sleep 5
gsettings set org.gnome.desktop.session idle-delay 0


#====================================================================================================
####file1: config_network.sh
# modify address1 to .111 and gateway to router in sunnyvale office for internet access
echo -e "\e[36mSEYOND: Modifying network ip\e[0m"
sleep 5

FILE="/etc/NetworkManager/system-connections/eno1-static.nmconnection"

# address2 for sdlc
if echo "admin123@Seyond" | sudo -S grep -q '^address2=' "$FILE"; then
    echo "admin123@Seyond" | sudo -S sed -i 's|^address2=.*|address2=192.168.1.100/24|' "$FILE"
else
    echo "admin123@Seyond" | sudo -S sed -i '/^address1=/a address2=192.168.1.100/24' "$FILE"
fi

# address3 for PoE Switch
if echo "admin123@Seyond" | sudo -S grep -q '^address3=' "$FILE"; then
    echo "admin123@Seyond" | sudo -S sed -i 's|^address3=.*|address3=192.168.2.100/24|' "$FILE"
else
    echo "admin123@Seyond" | sudo -S sed -i '/^address2=/a address3=192.168.2.100/24' "$FILE"
fi

# # address4 for sunnyvale office internet access
# if echo "admin123@Seyond" | sudo -S grep -q '^address4=' "$FILE"; then
#     echo "admin123@Seyond" | sudo -S sed -i 's|^address4=.*|address4=192.168.100.205/24|' "$FILE"
# else
#     echo "admin123@Seyond" | sudo -S sed -i '/^address3=/a address4=192.168.100.205/24' "$FILE"
# fi

:
# (sleep 5 && sudo nmcli connection up "eno1-static") &
# sudo nmcli connection down "eno1-static"
# sudo nmcli connection down "eno1-static" && sudo nmcli connection up "eno1-static"

# if to prevent auto dns from tailscale, dws, or connecting to laptop while troubleshoot
# sudo nmcli connection modify "eno1-static" ipv4.dns "8.8.8.8 1.1.1.1"
# sudo nmcli connection modify "eno1-static" ipv4.ignore-auto-dns yes

# sudo nmcli connection up "eno1-static"

# reload
run_checked "Reload network configuration" sudo nmcli connection reload
run_checked "Apply network configuration" sudo nmcli device reapply eno1
# route sunnvale router for network connection
# run_checked "Configure default network route" sudo nmcli connection modify "eno1-static" ipv4.routes "0.0.0.0/0 192.168.100.2"
# this will be reset after reboot
# run_checked "Apply temporary default route" sudo ip route replace default via 192.168.100.2




#====================================================================================================
# ask for sudo upfront
sudo -v

# optionally refresh in background every 60s while script runs
( while true; do sleep 60; sudo -n true || exit; done ) &
KEEPER_PID=$!
#====================================================================================================

# echo -e "\e[36mSEYOND: checking internet access\e[0m"
# sleep 5
# run_checked "Check internet access" ping -c 4 8.8.8.8


#====================================================================================================
# update package
echo -e "\e[36mSEYOND: update and install package with apt\e[0m"
sleep 5
# run_checked "APT package update" sudo apt update
# sudo apt upgrade -y

#====================================================================================================
# install nomahcine here so can do installation easily
echo -e "\e[36mSEYOND: installing nomachine\e[0m"
sleep 5
run_checked "Install NoMachine" sudo dpkg -i nomachine/*.deb





#====================================================================================================
# Install troubleshoot Software
echo -e "\e[36mSEYOND: Installing troubleshoot software: iftop, curl, speedtest, ffmpeg nmap socat\e[0m"
sleep 5
# run_checked "Install troubleshooting packages" sudo apt install -y iftop curl ffmpeg nmap socat
# run_checked "Install Speedtest" sudo snap install speedtest
sudo dpkg -i individual_app/deb_packages/*.deb
# for checking lidar info
run_checked "Copy LiDAR SDK" cp sdk/*.tgz /home/admin/Documents
# for recording point cloud
sudo mkdir -p /data/captures
sudo chown $USER:$USER /data/captures
run_checked "Copy point-cloud recording tool" cp -r data_collect /home/admin/Documents

#====================================================================================================
#installing Virtual Driver (Syslogic needs this since dummy display doesn't work on the unit)
echo -e "\e[36mSEYOND: installing Virtual Driver, Please run toggle_virtual_display_driver.sh to enable the virtual driver, and the physical monitor will be disabled after reboot\e[0m"
sleep 5
# run_checked "Install virtual display driver" sudo apt install -y xserver-xorg-video-dummy
run_checked "Back up physical display configuration" sudo cp /etc/X11/xorg.conf /etc/X11/xorg.conf.real
run_checked "Create virtual display configuration" sudo cp /etc/X11/xorg.conf /etc/X11/xorg.conf.dummy
sudo tee -a /etc/X11/xorg.conf.dummy > /dev/null <<'EOF'
Section "Monitor"
    Identifier "Monitor0"
    HorizSync   28.0-80.0
    VertRefresh 48.0-75.0
EndSection

Section "Device"
    Identifier  "Card0"
    Driver      "dummy"
    VideoRam    256000
EndSection

Section "Screen"
    Identifier "Screen0"
    Device     "Card0"
    Monitor    "Monitor0"
    DefaultDepth 24
    SubSection "Display"
        Depth     24
        Modes     "1920x1080"
    EndSubSection
EndSection
EOF

# save toggle on script on Documents folder
run_checked "Copy virtual display toggle script" cp toggle_virtual_display_driver.sh /home/admin/Documents


#====================================================================================================
## disable autoupdate or message
echo -e "\e[36mSEYOND: Disable auto update and message\e[0m"
sleep 5
FILE="/etc/apt/apt.conf.d/10periodic"
echo "Disabling automatic APT updates..."
sudo -S bash -c "cat > $FILE <<'EOF'
APT::Periodic::Update-Package-Lists \"0\";
APT::Periodic::Download-Upgradeable-Packages \"0\";
APT::Periodic::AutocleanInterval \"0\";
APT::Periodic::Unattended-Upgrade \"0\";
EOF"
sudo -S systemctl disable --now apt-daily.timer
sudo -S systemctl disable --now apt-daily-upgrade.timer

FILE="/etc/apt/apt.conf.d/10periodic"

sudo -S bash -c "cat > $FILE <<'EOF'
APT::Periodic::Update-Package-Lists \"0\";
APT::Periodic::Download-Upgradeable-Packages \"0\";
APT::Periodic::AutocleanInterval \"0\";
APT::Periodic::Unattended-Upgrade \"0\";
EOF"

cat /etc/apt/apt.conf.d/10periodic

#====================================================================================================
# remove updater
echo -e "\e[36mSEYOND: remove updater for pop-up window\e[0m"
sleep 5

# gsettings set com.ubuntu.update-notifier no-show-notifications true
# dconf write /org/gnome/desktop/notifications/application/update-manager/enable false
# sudo dpkg remove --purge update-manager update-notifier || true
# pkill -f update-manager || true
# pkill -f update-notifier || true

gsettings set com.ubuntu.update-notifier no-show-notifications true
dconf write /org/gnome/desktop/notifications/application/update-manager/enable false

pkill -f update-manager || true
pkill -f update-notifier || true
sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null <<'EOF'
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::AutocleanInterval "0";
APT::Periodic::Unattended-Upgrade "0";
EOF


#====================================================================================================
# check docker status
echo -e "\e[36mSEYOND: Checking Docker status, should be 6 containers\e[0m"
sudo docker ps




# # change power mode
# echo -e "\e[36mSEYOND: changing power mode to max, reboot is required to take affect\e[0m"
# sleep 5
# sudo nvpmodel -m 0



#====================================================================================================
# DWS
echo -e "\e[36mSEYOND: installing dws, please make sure the entire seyond_syslogic_edgebox_installation folder are saved locally\e[0m"
sleep 5
# read -p $'\e[1;33mSEYOND: Confirm if you have installation code ready? [y/N]: \e[0m' confirm
# sudo chmod +x dws/dwagent.sh
# sudo ./dws/dwagent.sh
## 1 1 1 code 
run_checked "Copy DWS installer" cp dws/dwagent.sh /home/admin/Documents


#====================================================================================================
# create data and loop folder, add to bookmark
echo -e "\e[36mSEYOND: Add /data folder in file shortcut\e[0m"
sleep 5
# sudo mkdir /data
# sudo chmod 777 /data
# sudo mkdir /loop
# sudo chmod 777 /loop
# sudo chown $USER:$USER /data
# sudo chown $USER:$USER /loop
echo "file:///data data" >> /home/admin/.config/gtk-3.0/bookmarks
# echo "file:///loop loop" >> ~/.config/gtk-3.0/bookmarks
nautilus -q

#====================================================================================================
# add firefox browser
echo -e "\e[36mSEYOND: Install firefox\e[0m"
sleep 5
run_checked "Extract Firefox" sudo tar -xvf browser/firefox-140.0.4.tar.xz -C /opt/
sudo cat > /home/admin/.local/share/applications/firefox.desktop <<'EOF'
[Desktop Entry]
Name=Firefox
Comment=Web Browser
Exec=/opt/firefox/firefox %u
Icon=/opt/firefox/browser/chrome/icons/default/default128.png
Terminal=false
Type=Application
Categories=Network;WebBrowser;
EOF
# add to default path and shortcut
sudo chmod +x /home/admin/.local/share/applications/firefox.desktop
update-desktop-database /home/admin/.local/share/applications

## adjust favorite bar
gsettings set org.gnome.shell favorite-apps "['firefox.desktop','org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop']"
# gsettings set org.gnome.shell favorite-apps "$(gsettings get org.gnome.shell favorite-apps | sed "s/]$/, 'firefox.desktop']/")"



#====================================================================================================
# install simpl
echo -e "\e[36mSEYOND: install/upgrade SIMPL\e[0m"
echo -e "\e[36mSEYOND: unzip SIMPL\e[0m"
sleep 5
sudo mkdir -p /data/SIMPL_installation
sudo chown $USER:$USER /data/SIMPL_installation
run_checked "Extract SIMPL package" sudo tar xzvf simpl_fw/*.tgz -C /data/SIMPL_installation
echo -e "\e[36mSEYOND: installing SIMPL\e[0m"
sleep 5

# to ensure the auto fusion will run at first start up, uninstall and install
# /data/SIMPL_installation/SIMPL_Setup -n uninstall
PASSWORD="admin123@Seyond"
expect << EOF
set timeout 60
spawn /data/SIMPL_installation/SIMPL_Setup -n uninstall
expect "Please enter the password for the user:"
send "${PASSWORD}\r"
expect eof
EOF


sudo rm -rf /data/seyond_user/

# Do you need highway or intersection?
# echo "Select application type:"
# echo "1) Intersection"
# echo "2) Highway"
# read -p "Enter your choice (1 or 2): " choice

# if [ "$choice" == "1" ]; then
#     run_checked "Install SIMPL" /data/SIMPL_installation/SIMPL_Setup -n install -p /data/seyond_user --host-ip 127.0.0.1 -s intersection -l 172.168.1.11 172.168.1.12 --actuation
# elif [ "$choice" == "2" ]; then
#     # /data/SIMPL_installation/SIMPL_Setup -n install -p /data/seyond_user --host-ip 127.0.0.1 -s highway -l 172.168.1.11
#     echo "Please install it manually with gui for highway until further notice"
# else
#     echo "Invalid option"
# fi
PASSWORD="admin123@Seyond"
expect << EOF
set timeout 300
spawn /data/SIMPL_installation/SIMPL_Setup -n install -p /data/seyond_user --host-ip 127.0.0.1 -s intersection -l 172.168.1.11 172.168.1.12 --actuation
expect "Please enter the password for the user:"
send "${PASSWORD}\r"
expect eof
EOF





# if SIMPL is already installed. do upgrade
# if sudo docker ps --format '{{.Names}}' | grep -q "^OmniVidi_VL$"; then
#     echo "Already has SIMPL running, doing upgrade"
#     # /data/SIMPL_installation/SIMPL_Setup -n update --host-ip 127.0.0.1
#     /data/SIMPL_installation/SIMPL_Setup -n upgrade --simpl_username admin --simpl_password admin
#     /data/SIMPL_installation/SIMPL_Setup -n update --actuation
# else
#     echo "don't have simpl install, running install"
#     /data/SIMPL_installation/SIMPL_Setup -n install -p /data/seyond_user --host-ip 127.0.0.1 -s intersection -l 172.168.1.11 172.168.1.12 --actuation
#     /data/SIMPL_installation/
# fi


# sudo /data/SIMPL_installation/installer -n -p /data/SIMPL_app --host-ip 172.168.1.111








#====================================================================================================
## Install tailscale
#echo -e "\e[36mSEYOND: Installing tailscale\e[0m"
#sleep 5



#curl -fsSL https://tailscale.com/install.sh | sh
#sudo tailscale set --advertise-exit-node
#sudo tailscale up
### copy link and enter in admin console
## turn off auto dns
## ***this resolve dns issue
#sudo tailscale up --accept-dns=false --advertise-exit-node 

###temporary solution
##sudo resolvectl dns eno1 8.8.8.8 1.1.1.1
##sudo resolvectl revert tailscale0
#sudo nmcli connection reload && sudo nmcli device reapply eno1
#sudo ip route replace default via 192.168.100.2



#====================================================================================================
# check remove unnecessary stuff from the /data drive 
read -p $'\e[1;33mSEYOND: Pres any key to continue remove unnecessary stuff in /data folder. System will reboot after [y/N]: \e[0m' confirm
sudo mkdir /tmp/root_peek
sudo mount --bind / /tmp/root_peek 
sudo rm -rf /tmp/root_peek/data/backup/* /tmp/root_peek/data/tools/*
sudo umount /tmp/root_peek

print_installation_summary

read -r -p "SEYOND: Installation is complete. Reboot now? [y/N]: " reboot_confirm
if [[ "$reboot_confirm" =~ ^[Yy]$ ]]; then
    echo "Rebooting system..."
    sleep 5
    sudo reboot
else
    echo "Reboot skipped. Please reboot the system manually when ready."
fi

