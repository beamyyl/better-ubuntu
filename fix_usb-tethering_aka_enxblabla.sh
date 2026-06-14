sudo sed -i "s/enx[0-9a-f]*/$(ip -br link show | awk '{print $1}' | grep '^enx')/g" /etc/netplan/00-installer-config.yaml && sudo netplan apply
