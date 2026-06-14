echo 'Run with SUDO!'
sleep 3
apt update
apt install -y network-manager iputils-ping net-tools dnsutils curl

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
systemctl disable systemd-networkd-wait-online
systemctl disable snapd snapd.socket
apt purge snapd
apt purge cloud-init
rm -rf /etc/cloud/ /var/lib/cloud/
apt purge multipath-tools
apt autoremove --purge

sudo reboot
