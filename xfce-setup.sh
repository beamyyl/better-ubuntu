sudo apt update
sudo apt upgrade -y
sudo apt install xfce4 xfce4-goodies xfce4-whiskermenu-plugin xfce4-pulseaudio-plugin lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings pavucontrol -y
sudo dpkg-reconfigure lightdm
sudo mkdir /usr/share/xfce4/backdrops -p
sudo cp -r /usr/share/backgrounds/* /usr/share/xfce4/backdrops/
echo "You can now reboot to go into Xfce"
