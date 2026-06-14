sudo apt update
sudo apt purge cloud-init
sudo rm -rf /etc/cloud/ /var/lib/cloud/
sudo apt purge multipath-tools
sudo apt autoremove --purge
sudo apt install -y network-manager iputils-ping net-tools dnsutils curl

cd /etc/netplan
cp 01-netcfg.yaml 01-netcfg.yaml.BAK

cat << EOF > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: NetworkManager
EOF

netplan generate
netplan apply
systemctl enable NetworkManager.service
systemctl restart NetworkManager.service

sudo reboot
