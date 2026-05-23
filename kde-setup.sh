sudo apt update
sudo apt upgrade -y
sudo apt install kde-plasma-desktop sddm-theme-breeze breeze-theme konsole dolphin -y
sudo mkdir -p /etc/sddm.conf.d
sudo mv mv /etc/sddm.conf.d/50-ubuntu-budgie.conf /etc/sddm.conf.d/50-ubuntu-budgie.bak
echo -e "[Theme]\nCurrent=breeze" | sudo tee /etc/sddm.conf.d/kde_settings.conf
echo "You can now reboot to go into plasma"
