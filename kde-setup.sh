sudo apt update
sudo apt upgrade -y
sudo apt install kde-plasma-desktop sddm-theme-breeze breeze-gtk-theme breeze-icon-theme konsole dolphin kde-spectacle -y
sudo dpkg-reconfigure sddm
sudo mkdir -p /etc/sddm.conf.d
sudo mv /etc/sddm.conf.d/50-ubuntu-budgie.conf /etc/sddm.conf.d/50-ubuntu-budgie.bak
echo -e "[Theme]\nCurrent=breeze" | sudo tee /etc/sddm.conf.d/kde_settings.conf
sudo apt purge light-locker -y
echo "You can now reboot to go into plasma"
