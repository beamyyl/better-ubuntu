sudo apt update
sudo apt install -y network-manager
echo -e "network:\n  version: 2\n  renderer: NetworkManager" | sudo tee /etc/netplan/01-networkmanager.yaml
sudo rm -f /etc/netplan/00-installer-config.yaml /etc/netplan/50-cloud-init.yaml
sudo netplan apply
sudo systemctl enable NetworkManager --now
sudo apt purge -y netplan.io
sudo apt autoremove -y
sudo rm -rf /etc/netplan/ /usr/share/netplan/
