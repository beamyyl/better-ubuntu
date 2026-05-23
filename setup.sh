sudo add-apt-repository -y universe
sudo add-apt-repository -y multiverse
sudo add-apt-repository -y restricted
sudo dpkg --add-architecture i386
sudo apt install flatpak
sudo apt install gnome-software-plugin-flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

for s in $(snap list | awk '{print $1}' | tail -n +2); do sudo snap remove --purge "$s"; done
sudo apt purge -y snapd firefox
sudo rm -rf ~/snap /var/snap /var/lib/snapd /var/cache/snapd

sudo add-apt-repository -y ppa:xtradeb/apps

sudo tee /etc/apt/preferences.d/xtradeb-no-snap << 'EOF'
Package: *
Pin: release o=LP-PPA-xtradeb-apps
Pin-Priority: 1001

Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

sudo apt update
sudo apt upgrade -y
