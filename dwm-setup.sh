sudo apt update
sudo apt install build-essential libx11-dev libxft-dev libxinerama-dev suckless-tools git xorg xinit x11-xserver-utils maim xclip -y
read -p "Choose 1 for official barebones dwm, 2 for my dwm dots and 3 to close the script with just the build deps: " choice
if [ "$choice" -eq 1 ]; then
    git clone https://suckless.org
    cd dwm
    sudo make clean install
elif [ "$choice" -eq 2 ]; then
    git clone https://github.com
    cd dwm
    chmod +x setupdwm.sh
    sudo ./setupdwm.sh
elif [ "$choice" -eq 3 ]; then
    exit 0
else
    exit 1
fi
