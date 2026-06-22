#!/bin/bash
# =============================================================================
# De-snapped Ubuntu Install Script
# Supports: UEFI or BIOS
# =============================================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()   { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }
ask()   { echo -e "${CYAN}[INPUT]${NC} $*"; }

# Configuration
RELEASE="${1:-resolute}"
TARGET="/mnt"
HOSTNAME="ubuntu"

# =============================================================================
# Sanity checks
# =============================================================================
if ! mountpoint -q "$TARGET"; then
    die "$TARGET is not a target mountpoint. Please mount your root partition."
fi

# =============================================================================
# Boot mode selection
# =============================================================================
ask "Boot mode — are you using UEFI or BIOS?"
ask "  1) UEFI (modern, GPT disk)"
ask "  2) BIOS (legacy/older, MBR/GPT disk)"
read -rp "  Choice [1/2]: " BOOT_CHOICE

if [ "$BOOT_CHOICE" = "1" ]; then
    BOOT_MODE="uefi"
    if ! mountpoint -q "$TARGET/boot/efi"; then
        die "$TARGET/boot/efi is not a target mountpoint. Please mount your EFI partition."
    fi
else
    BOOT_MODE="bios"
    ask "Enter the disk to install GRUB to (e.g. /dev/sda):"
    read -rp "  Install disk: " GRUB_DISK
    [ -z "$GRUB_DISK" ] && die "Disk cannot be empty."
fi

# =============================================================================
# Environment Setup
# =============================================================================
info "Detecting host environment package mirror..."
if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
    MIRROR=$(awk '/^URIs:/ {print $2; exit}' /etc/apt/sources.list.d/ubuntu.sources)
elif [ -f /etc/apt/sources.list ]; then
    MIRROR=$(awk '/^deb / {print $2; exit}' /etc/apt/sources.list)
fi

if [ -z "$MIRROR" ]; then
    MIRROR="http://archive.ubuntu.com/ubuntu/"
    warn "Mirror auto-detection inconclusive. Falling back to default: $MIRROR"
else
    info "Detected target mirror: $MIRROR"
fi

# =============================================================================
# User Input
# =============================================================================
ask "Enter desired username for the new user:"
read -rp "  Username: " username
while [ -z "$username" ]; do
    read -rp "  Username cannot be empty. Enter username: " username
done

read -s -rp "  Enter password for $username: " user_password
echo ""
read -s -rp "  Confirm password for $username: " user_password_confirm
echo ""

if [ "$user_password" != "$user_password_confirm" ]; then
    die "Passwords do not match!"
fi

read -s -rp "  Enter password for root account: " root_password
echo ""
read -s -rp "  Confirm password for root account: " root_password_confirm
echo ""

if [ "$root_password" != "$root_password_confirm" ]; then
    die "Root passwords do not match!"
fi
echo ""

if ! command -v debootstrap &> /dev/null; then
    info "debootstrap not found. Installing on live environment"
    apt-get update
    apt-get install -y debootstrap
fi

# =============================================================================
# Installation
# =============================================================================
info "Bootstrapping base system via debootstrap"
debootstrap --arch=amd64 --keyring=/usr/share/keyrings/ubuntu-archive-keyring.gpg "$RELEASE" "$TARGET" "$MIRROR"

info "Generating /etc/fstab configuration"
ROOT_UUID=$(blkid -s UUID -o value $(findmnt -n -o SOURCE --target "$TARGET"))

cat << FSTAB > "$TARGET/etc/fstab"
UUID=$ROOT_UUID / ext4 errors=remount-ro 0 1
FSTAB

if [ "$BOOT_MODE" = "uefi" ]; then
    EFI_UUID=$(blkid -s UUID -o value $(findmnt -n -o SOURCE --target "$TARGET/boot/efi"))
    echo "UUID=$EFI_UUID /boot/efi vfat umask=0077 0 2" >> "$TARGET/etc/fstab"
fi

echo "$HOSTNAME" > "$TARGET/etc/hostname"
cat << HOSTS > "$TARGET/etc/hosts"
127.0.0.1   localhost
127.1.1.1   $HOSTNAME

::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
HOSTS

info "Mounting API virtual filesystems"
for dir in /dev /dev/pts /proc /sys /run; do
    mount --bind "$dir" "$TARGET$dir"
done

# =============================================================================
# Chroot execution
# =============================================================================
chroot "$TARGET" /bin/bash -s "$RELEASE" "$MIRROR" "$username" "$user_password" "$root_password" "$BOOT_MODE" "$GRUB_DISK" << 'CHROOT_EOF'
set -e
TARGET_RELEASE="$1"
TARGET_MIRROR="$2"
NEW_USER="$3"
NEW_USER_PASS="$4"
ROOT_PASS="$5"
BOOT_MODE="$6"
GRUB_DISK="$7"

echo "--> Initializing package manager and architecture layers..."
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

dpkg --add-architecture i386

echo "--> Implementing anti-snap APT constraints..."
mkdir -p /etc/apt/preferences.d
cat << 'EOF' > /etc/apt/preferences.d/xtradeb-no-snap
Package: *
Pin: release o=LP-PPA-xtradeb-apps
Pin-Priority: 1001

Package: firefox* thunderbird*
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1002

Package: thunderbird
Pin: version 2:1snap*
Pin-Priority: -1

Package: firefox*
Pin: release o=Ubuntu*
Pin-Priority: -1

Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

mkdir -p /etc/dpkg/dpkg.cfg.d
cat << 'EOF' > /etc/dpkg/dpkg.cfg.d/block-browser-branding
path-exclude=/usr/lib/firefox/distribution/*
path-exclude=/etc/chromium/*
path-exclude=/etc/chromium-browser/*
EOF

echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:${distro_codename}";' | tee /etc/apt/apt.conf.d/51unattended-upgrades-thunderbird

apt-get update
apt-get install -y software-properties-common gnupg

add-apt-repository -y ppa:xtradeb/apps
add-apt-repository -y ppa:mozillateam/ppa
apt-get update

echo "--> Pulling base kernel, boot management, and network stuff"
apt-get install -y linux-image-generic grub-efi-amd64 network-manager ubuntu-desktop-minimal
systemctl enable NetworkManager gdm

apt-get install -y flatpak gnome-software-plugin-flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

apt-get install -y firefox thunderbird bash

apt-get purge -y snapd || true
rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd /usr/lib/snapd

echo "--> Configuring boot entries..."
if [ "$BOOT_MODE" = "uefi" ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Ubuntu --recheck
else
    grub-install "$GRUB_DISK"
fi
update-grub

echo "--> Provisioning users and system credentials..."
echo "root:$ROOT_PASS" | chpasswd
chsh -s /bin/bash root

useradd -m -s /bin/bash -G sudo,plugdev,netdev,audio,video,input "$NEW_USER"
echo "$NEW_USER:$NEW_USER_PASS" | chpasswd
CHROOT_EOF

# =============================================================================
# Cleanup
# =============================================================================
info "Tear down external bind structures..."
for dir in /run /sys /proc /dev/pts /dev; do
    umount "$TARGET$dir" || true
done

echo "=========================================================="
echo " Done! You can now reboot your system."
echo "=========================================================="
