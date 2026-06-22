#!/bin/bash
# =============================================================================
# De-snapped Ubuntu Install Script
# A simplified, automated installer
# =============================================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()   { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }
ask()   { echo -e "${CYAN}[INPUT]${NC} $*"; }

# Configuration
RELEASE="${1:-noble}"
TARGET="/mnt"
HOSTNAME="ubuntu"

# =============================================================================
# Sanity checks
# =============================================================================
for cmd in debootstrap chroot; do
    command -v "$cmd" &>/dev/null \
        || die "'$cmd' not found. Please install debootstrap."
done

if ! mountpoint -q "$TARGET"; then
    die "$TARGET is not a target mountpoint. Please mount your root partition."
fi
if ! mountpoint -q "$TARGET/boot/efi"; then
    die "$TARGET/boot/efi is not a target mountpoint. Please mount your EFI partition."
fi

# =============================================================================
# Environment Setup
# =============================================================================
clear
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║             DE-SNAPPED UBUNTU INSTALLER                  ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

info "Detecting host environment package mirror..."
if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
    MIRROR=$(awk '/^URIs:/ {print $2; exit}' /etc/apt/sources.list.d/ubuntu.sources)
elif [ -f /etc/apt/sources.list ]; then
    MIRROR=$(awk '/^deb / {print $2; exit}' /etc/apt/sources.list)
fi

if [ -z "$MIRROR" ]; then
    MIRROR="http://archive.ubuntu.com/ubuntu/"
    warn "Mirror auto-detection inconclusive. Falling back to: $MIRROR"
else
    info "Detected target mirror: $MIRROR"
fi
echo ""

# =============================================================================
# User Input
# =============================================================================
ask "Enter desired username for the new user:"
read -rp "  Username: " username
[ -z "$username" ] && die "Username cannot be empty."

ask "Enter password for $username:"
read -s -rp "  Password: " user_password
echo ""
read -s -rp "  Confirm: " user_password_confirm
echo ""
[ "$user_password" != "$user_password_confirm" ] && die "Passwords do not match!"

ask "Enter password for root account:"
read -s -rp "  Password: " root_password
echo ""
read -s -rp "  Confirm: " root_password_confirm
echo ""
[ "$root_password" != "$root_password_confirm" ] && die "Root passwords do not match!"

# =============================================================================
# Bootstrapping
# =============================================================================
info "Bootstrapping base system via debootstrap..."
debootstrap --arch=amd64 --keyring=/usr/share/keyrings/ubuntu-archive-keyring.gpg "$RELEASE" "$TARGET" "$MIRROR"

info "Generating /etc/fstab..."
ROOT_UUID=$(blkid -s UUID -o value $(findmnt -n -o SOURCE --target "$TARGET"))
EFI_UUID=$(blkid -s UUID -o value $(findmnt -n -o SOURCE --target "$TARGET/boot/efi"))

cat << FSTAB > "$TARGET/etc/fstab"
UUID=$ROOT_UUID / ext4 errors=remount-ro 0 1
UUID=$EFI_UUID /boot/efi vfat umask=0077 0 2
FSTAB

echo "$HOSTNAME" > "$TARGET/etc/hostname"
cat << HOSTS > "$TARGET/etc/hosts"
127.0.0.1   localhost
127.1.1.1   $HOSTNAME

::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
HOSTS

# =============================================================================
# Mounting pseudo-filesystems
# =============================================================================
info "Mounting API virtual filesystems..."
for dir in /dev /dev/pts /proc /sys /run; do
    mount --bind "$dir" "$TARGET$dir"
done

# =============================================================================
# In-chroot script creation
# =============================================================================
info "Writing in-chroot script..."

cat << 'CHROOT_EOF' > "$TARGET/chroot-install.sh"
#!/bin/bash
set -e
TARGET_RELEASE="$1"
TARGET_MIRROR="$2"
NEW_USER="$3"
NEW_USER_PASS="$4"
ROOT_PASS="$5"

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

echo "--> Configuring EFI boot entries..."
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Ubuntu --recheck
update-grub

echo "--> Provisioning users and system credentials..."
echo "root:$ROOT_PASS" | chpasswd
chsh -s /bin/bash root

useradd -m -s /bin/bash -G sudo,plugdev,netdev,audio,video,input "$NEW_USER"
echo "$NEW_USER:$NEW_USER_PASS" | chpasswd
CHROOT_EOF

chmod +x "$TARGET/chroot-install.sh"

# =============================================================================
# Execute Chroot
# =============================================================================
info "Entering chroot to complete installation..."
chroot "$TARGET" /bin/bash /chroot-install.sh "$RELEASE" "$MIRROR" "$username" "$user_password" "$root_password"

# =============================================================================
# Cleanup
# =============================================================================
info "Tearing down external bind structures..."
for dir in /run /sys /proc /dev/pts /dev; do
    umount "$TARGET$dir" || true
done

rm -f "$TARGET/chroot-install.sh"

info "============================================================"
info " Done! You can now reboot your system."
info "============================================================"
