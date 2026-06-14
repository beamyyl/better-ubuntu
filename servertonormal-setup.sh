#!/bin/bash
echo 'Run with SUDO!'
sleep 3

apt update
apt install -y network-manager iputils-ping net-tools dnsutils curl

cd /etc/netplan
mkdir -p ./bak/
cp *.yaml ./bak/
rm -f *.yaml

cat << EOF > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: NetworkManager
EOF

netplan generate
netplan apply

systemctl daemon-reload
systemctl enable NetworkManager.service
systemctl restart NetworkManager.service
systemctl disable systemd-networkd-wait-online

systemctl disable snapd snapd.socket
apt purge -y snapd
apt purge -y cloud-init
rm -rf /etc/cloud/ /var/lib/cloud/
apt purge -y multipath-tools
apt autoremove --purge -y

reboot
