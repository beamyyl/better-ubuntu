# This repo includes several scripts that make Ubuntu a better distro, including setup for other DE's.
# !! If you're installing with the ubuntu server iso, I recommend cloning this repo already on the usb disk, in case youre using USB Tethering¹. 

The "setup.sh" script fully removes SNAPS and snap-apps, INCLUDING FIREFOX!
Make sure to run this script without setting up the default firefox, because everything **WILL BE PURGED**.

## Installation
(replace setup.sh with the script you wanna run)
### 1. Clone this repo by running:
```bash
git clone https://github.com/beamyyl/better-ubuntu.git
```
### 2. Go into the cloned folder:
```bash
cd better-ubuntu/
```
### 3. Make the script executable:
```bash
chmod +x setup.sh
```
### 4. Run the script (will require sudo password)
```bash
./setup.sh
```

¹If after installing you're stuck on service 'systemd-networkd-wait-online', you must reboot into the grub menu, press `e`, go to the end of the Linux line and add `init=/bin/bash`, then `ctrl + x` or `F10`. After it boots, run `mount -o remount,rw /` and `systemctl --root=/ mask systemd-networkd-wait-online.service` and force reboot. Then, run the fix usb tethering script (from the usb cloned repo) by mounting your usb to /mnt and then copying it like `cp -r /mnt/better-ubuntu .` and you should be able to run the `servertonormal.sh` script to enable NetworkManager.
