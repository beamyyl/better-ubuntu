#!/usr/bin/env bash
set -e

TARGET="/mnt"

echo "=== 1. Ensuring Mount Points Exist ==="
mkdir -p "${TARGET}"

echo "=== 2. Running Debootstrap (Resolute Minbase) ==="
apt install debootstrap
debootstrap --variant=minbase resolute "${TARGET}" http://archive.ubuntu.com/ubuntu/

echo "=== 3. Creating Virtual FS Mounts ==="
mkdir -p "${TARGET}"/{proc,sys,dev,boot/efi,tmp}

echo "=== 4. Mounting Virtual Filesystems ==="
mount --types proc /proc "${TARGET}/proc"
mount --types sysfs /sys "${TARGET}/sys"
mount --bind /dev "${TARGET}/dev"
mount --bind /dev/pts "${TARGET}/dev/pts"

echo "=== 5. Generating Mirror Sources ==="
cat <<EOF > "${TARGET}/etc/apt/sources.list"
deb http://archive.ubuntu.com/ubuntu/ resolute main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ resolute-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ resolute-security main restricted universe multiverse
EOF

echo "=== 6. Provisioning the Base System inside Chroot ==="
cat << 'CHROOT_EOF' > "${TARGET}/tmp/chroot_setup.sh"
#!/usr/bin/env bash
set -e

echo "Updating apt cache..."
apt-get update

echo "Installing Linux kernel and hardware firmware blobs..."
apt-get install -y --no-install-recommends linux-image-generic linux-firmware

echo "Installing GRUB for UEFI..."
apt-get install -y grub-efi-amd64 efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu --recheck
update-grub

echo "Installing lightweight network tools (ifupdown + dhcpcd)..."
apt-get install -y ifupdown dhcpcd

echo "Writing /etc/network/interfaces config..."
cat <<EOF > /etc/network/interfaces
auto lo
iface lo inet loopback

auto enp1s0
iface enp1s0 inet dhcp
EOF

echo "Set your Root Password:"
passwd

CHROOT_EOF

# Execute the setup script inside the chroot jail
chmod +x "${TARGET}/tmp/chroot_setup.sh"
chroot "${TARGET}" /tmp/chroot_setup.sh

# Cleanup the script from the target environment
rm -f "${TARGET}/tmp/chroot_setup.sh"

echo "=== 7. Detaching Virtual Mounts and Syncing ==="
sync

# Clean unmount loops with lazy fallback for stubborn locks
umount "${TARGET}/boot/efi" || umount -l "${TARGET}/boot/efi"
umount "${TARGET}/dev/pts" || umount -l "${TARGET}/dev/pts"
umount "${TARGET}/dev"     || umount -l "${TARGET}/dev"
umount "${TARGET}/sys"     || umount -l "${TARGET}/sys"
umount "${TARGET}/proc"    || umount -l "${TARGET}/proc"

echo "=== Done! Ready to reboot. ==="
