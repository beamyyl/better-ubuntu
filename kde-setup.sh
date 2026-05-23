sudo apt update
sudo apt upgrade -y
sudo apt install kde-plasma-desktop sddm-theme-breeze breeze-theme konsole dolphin -y
sudo dpkg-reconfigure sddm
sudo mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=breeze" | sudo tee /etc/sddm.conf.d/theme.conf
echo "You can now reboot to go into plasma"
