#!/bin/bash

sudo add-apt-repository -y universe
sudo add-apt-repository -y multiverse
sudo add-apt-repository -y restricted
sudo dpkg --add-architecture i386

sudo apt update
sudo apt install flatpak gnome-software-plugin-flatpak -y
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

sudo systemctl stop snapd.service snapd.socket 2>/dev/null

sudo apt purge -y snapd
sudo rm -rf ~/snap /var/snap /var/lib/snapd /var/cache/snapd /usr/lib/snapd

sudo add-apt-repository -y ppa:xtradeb/apps
sudo add-apt-repository -y ppa:mozillateam/ppa

sudo tee /etc/apt/preferences.d/xtradeb-no-snap << 'EOF'
Package: *
Pin: release o=LP-PPA-xtradeb-apps
Pin-Priority: 1001

Package: firefox*
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1002

Package: firefox*
Pin: release o=Ubuntu*
Pin-Priority: -1

Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

sudo mkdir -p /etc/dpkg/dpkg.cfg.d
sudo tee /etc/dpkg/dpkg.cfg.d/block-browser-branding << 'EOF'
path-exclude=/usr/lib/firefox/distribution/*
path-exclude=/etc/chromium/*
path-exclude=/etc/chromium-browser/*
EOF

sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y

echo ""
read -p "Would you like to install Firefox back as a native .deb? (y/N): " choice
if [[ "$choice" =~ ^[Yy]$ ]]; then
    sudo apt install -y firefox
fi

echo "Done. Reboot your system to ensure all changes take effect cleanly!"
