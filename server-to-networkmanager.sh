sudo apt update
sudo apt install -y network-manager
echo -e "network:\n  version: 2\n  renderer: NetworkManager" | sudo tee /etc/netplan/01-networkmanager.yaml
sudo rm -f /etc/netplan/00-installer-config.yaml /etc/netplan/50-cloud-init.yaml
sudo netplan apply
sudo systemctl enable NetworkManager --now
sudo systemctl disable systemd-networkd.service --now
sudo systemctl mask systemd-networkd-wait-online.service
sudo touch /etc/NetworkManager/conf.d/10-globally-managed-devices.conf
#sudo sed -i 's/managed=false/managed=true/g' /etc/NetworkManager/NetworkManager.conf
sudo systemctl restart NetworkManager
sudo reboot
