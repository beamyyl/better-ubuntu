#!/bin/bash
set -e

# --- Configuration ---
RELEASE="${1:-resolute}"
TARGET="/mnt"
HOSTNAME="ubuntu-minimal"
MIRROR="http://ro.archive.ubuntu.com/ubuntu/"

echo "=========================================================="
echo " Starting De-snapped Ubuntu ($RELEASE) Installation "
echo "=========================================================="

# 1. Sanity checks for pre-existing mountpoints
if ! mountpoint -q "$TARGET"; then
    echo "ERROR: $TARGET is not a target mountpoint. Please mount your root partition."
    exit 1
fi
if ! mountpoint -q "$TARGET/boot/efi"; then
    echo "ERROR: $TARGET/boot/efi is not a target mountpoint. Please mount your EFI partition."
    exit 1
fi

# 2. Ensure debootstrap is installed on the host environment
if ! command -v debootstrap &> /dev/null; then
    echo "--> debootstrap not found. Installing on live environment..."
    apt-get update
    apt-get install -y debootstrap
fi

# 3. Securely bootstrap the core system with full GPG validation
echo "--> Bootstrapping base system via debootstrap..."
debootstrap --arch=amd64 --keyring=/usr/share/keyrings/ubuntu-archive-keyring.gpg "$RELEASE" "$TARGET" "$MIRROR"

# 4. Dynamically capture block device UUIDs to populate fstab
echo "--> Generating /etc/fstab configuration..."
ROOT_UUID=$(blkid -s UUID -o value $(findmnt -n -o SOURCE --target "$TARGET"))
EFI_UUID=$(blkid -s UUID -o value $(findmnt -n -o SOURCE --target "$TARGET/boot/efi"))

cat << FSTAB > "$TARGET/etc/fstab"
# /etc/fstab: Static file system information.
UUID=$ROOT_UUID / ext4 errors=remount-ro 0 1
UUID=$EFI_UUID /boot/efi vfat umask=0077 0 2
FSTAB

# 5. Configure foundational network assets
echo "$HOSTNAME" > "$TARGET/etc/hostname"
cat << HOSTS > "$TARGET/etc/hosts"
127.0.0.1   localhost
127.1.1.1   $HOSTNAME

::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
HOSTS

# 6. Bind mount virtual filesystems into target structure
echo "--> Mounting API virtual filesystems..."
for dir in /dev /dev/pts /proc /sys /run; do
    mount --bind "$dir" "$TARGET$dir"
done

# 7. Execute core deployment inside the isolated chroot
echo "--> Shifting context to target environment..."
chroot "$TARGET" /bin/bash -s "$RELEASE" "$MIRROR" << 'CHROOT_EOF'
set -e
TARGET_RELEASE="$1"
TARGET_MIRROR="$2"

echo "--> Initializing package manager and architecture layers..."
# Write out modern deb822 source sheets
cat << SOURCES > /etc/apt/sources.list.d/ubuntu.sources
Types: deb
URIs: $TARGET_MIRROR
Suites: $TARGET_RELEASE $TARGET_RELEASE-updates $TARGET_RELEASE-backports
Components: main universe multiverse restricted
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu/
Suites: $TARGET_RELEASE-security
Components: main universe multiverse restricted
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
SOURCES

# Add i386 multiarch layer
dpkg --add-architecture i386

# Ingest custom APT pin layouts BEFORE any core system installations occur
echo "--> Implementing anti-snap APT constraints..."
mkdir -p /etc/apt/preferences.d
cat << 'EOF' > /etc/apt/preferences.d/xtradeb-no-snap
Package: *
Pin: release o=LP-PPA-xtradeb-apps
Pin-Priority: 1001

Package: firefox*
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1002

Package: firefox*
Pin: release o=Ubuntu*
Pin-Priority: -1

Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

# Prevent browser branding distributions from clashing
mkdir -p /etc/dpkg/dpkg.cfg.d
cat << 'EOF' > /etc/dpkg/dpkg.cfg.d/block-browser-branding
path-exclude=/usr/lib/firefox/distribution/*
path-exclude=/etc/chromium/*
path-exclude=/etc/chromium-browser/*
EOF

apt-get update

# Install infrastructure modules necessary for manual PPA ingestion
apt-get install -y --no-install-recommends software-properties-common gnupg

# Add external PPAs
add-apt-repository -y ppa:xtradeb/apps
add-apt-repository -y ppa:mozillateam/ppa
apt-get update

echo "--> Pulling base kernel, boot management, and network stacks..."
apt-get install -y linux-image-generic grub-efi-amd64 network-manager

echo "--> Building minimal desktop stack minus snap interventions..."
# --no-install-recommends blocks indirect transitions or unwanted transitional snaps
apt-get install -y --no-install-recommends ubuntu-desktop-minimal

echo "--> Formatting flatpak delivery layout..."
apt-get install -y flatpak gnome-software-plugin-flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

echo "--> Deploying native Mozilla PPA Firefox package..."
apt-get install -y firefox

# Sanitation routine to catch any unexpected snap components
apt-get purge -y snapd || true
rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd /usr/lib/snapd

echo "--> Configuring EFI boot entries..."
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Ubuntu --recheck
update-grub

echo "--> Define root authentication parameters:"
passwd root

echo "--> Setting up primary standard user profile:"
read -p "Enter desired username: " username
useradd -m -s /bin/bash -G sudo,plugdev,netdev "$username"
passwd "$username"

CHROOT_EOF

# 8. Safe teardown of working namespaces
echo "--> Tear down external bind structures..."
for dir in /run /sys /proc /dev/pts /dev; do
    umount "$TARGET$dir" || true
done

echo "=========================================================="
echo " Process complete! Unmount /mnt and initiate system reboot."
echo "=========================================================="
