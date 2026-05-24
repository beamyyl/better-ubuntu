sudo add-apt-repository -y universe
sudo add-apt-repository -y multiverse
sudo add-apt-repository -y restricted
sudo dpkg --add-architecture i386
sudo apt install flatpak -y
sudo apt install gnome-software-plugin-flatpak -y
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

for s in $(snap list | awk '{print $1}' | tail -n +2); do sudo snap remove --purge "$s"; done
sudo apt purge -y snapd firefox
sudo rm -rf ~/snap /var/snap /var/lib/snapd /var/cache/snapd

sudo add-apt-repository -y ppa:xtradeb/apps
sudo add-apt-repository -y ppa:mozillateam/ppa

sudo tee /etc/apt/preferences.d/xtradeb-no-snap << 'EOF'
Package: *
Pin: release o=LP-PPA-xtradeb-apps
Pin-Priority: 1001

Package: firefox*
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1002

Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y

echo ""
read -p "Would you like to install Firefox back? (y/N): " choice
if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
    sudo apt install -y firefox
fi

echo "Done. Reboot your system to be sure every snap dependency is GONE"
