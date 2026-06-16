#!/bin/bash
set -e

# --- Configuration ---
RELEASE="${1:-resolute}"
TARGET="/mnt"
HOSTNAME="ubuntu"

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

# 2. Dynamic Mirror Extraction (Pulls the live ISO's operational mirror)
echo "--> Detecting host environment package mirror..."
if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
    MIRROR=$(awk '/^URIs:/ {print $2; exit}' /etc/apt/sources.list.d/ubuntu.sources)
elif [ -f /etc/apt/sources.list ]; then
    MIRROR=$(awk '/^deb / {print $2; exit}' /etc/apt/sources.list)
fi

# Fallback block if files are unreadable or complex
if [ -z "$MIRROR" ]; then
    MIRROR="http://archive.ubuntu.com/ubuntu/"
    echo "    (!) Mirror auto-detection inconclusive. Falling back to default: $MIRROR"
else
    echo "    Detected target mirror: $MIRROR"
fi

# 3. Interactively gather user details on the host system BEFORE entering chroot
# This ensures standard input is completely open and clean.
echo ""
read -p "Enter desired username for the new system: " username
while [ -z "$username" ]; do
    read -p "Username cannot be empty. Enter username: " username
done

read -s -p "Enter password for $username: " user_password
echo ""
read -s -p "Confirm password for $username: " user_password_confirm
echo ""

if [ "$user_password" != "$user_password_confirm" ]; then
    echo "ERROR: Passwords do not match!"
    exit 1
fi

read -s -p "Enter password for root account: " root_password
echo ""
read -s -p "Confirm password for root account: " root_password_confirm
echo ""

if [ "$root_password" != "$root_password_confirm" ]; then
    echo "ERROR: Root passwords do not match!"
    exit 1
fi
echo ""

# 4. Ensure debootstrap is installed on the host environment
if ! command -v debootstrap &> /dev/null; then
    echo "--> debootstrap not found. Installing on live environment..."
    apt-get update
    apt-get install -y debootstrap
fi

# 5. Securely bootstrap the core system with full GPG validation
echo "--> Bootstrapping base system via debootstrap..."
debootstrap --arch=amd64 --keyring=/usr/share/keyrings/ubuntu-archive-keyring.gpg "$RELEASE" "$TARGET" "$MIRROR"

# 6. Dynamically capture block device UUIDs to populate fstab
echo "--> Generating /etc/fstab configuration..."
ROOT_UUID=$(blkid -s UUID -o value $(findmnt -n -o SOURCE --target "$TARGET"))
EFI_UUID=$(blkid -s UUID -o value $(findmnt -n -o SOURCE --target "$TARGET/boot/efi"))

cat << FSTAB > "$TARGET/etc/fstab"
# /etc/fstab: Static file system information.
UUID=$ROOT_UUID / ext4 errors=remount-ro 0 1
UUID=$EFI_UUID /boot/efi vfat umask=0077 0 2
FSTAB

# 7. Configure foundational network assets
echo "$HOSTNAME" > "$TARGET/etc/hostname"
cat << HOSTS > "$TARGET/etc/hosts"
127.0.0.1   localhost
127.1.1.1   $HOSTNAME

::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
HOSTS

# 8. Bind mount virtual filesystems into target structure
echo "--> Mounting API virtual filesystems..."
for dir in /dev /dev/pts /proc /sys /run; do
    mount --bind "$dir" "$TARGET$dir"
done

# 9. Execute core deployment inside the isolated chroot
echo "--> Shifting context to target environment..."
chroot "$TARGET" /bin/bash -s "$RELEASE" "$MIRROR" "$username" "$user_password" "$root_password" << 'CHROOT_EOF'
set -e
TARGET_RELEASE="$1"
TARGET_MIRROR="$2"
NEW_USER="$3"
NEW_USER_PASS="$4"
ROOT_PASS="$5"

echo "--> Initializing package manager and architecture layers..."
# Write out modern deb822 source sheets using the parsed mirror
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
apt-get install -y software-properties-common gnupg

# Add external PPAs
add-apt-repository -y ppa:xtradeb/apps
add-apt-repository -y ppa:mozillateam/ppa
apt-get update

echo "--> Pulling base kernel, boot management, and network stacks..."
apt-get install -y linux-image-generic grub-efi-amd64 network-manager

echo "--> Building minimal desktop stack minus snap interventions..."
apt-get install -y ubuntu-desktop-minimal

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

echo "--> Provisioning users and system credentials..."
# Provision root account password securely using a string pipe
echo "root:$ROOT_PASS" | chpasswd

# Setup primary user account
useradd -m -s /bin/bash -G sudo,plugdev,netdev,audio,video,input "$NEW_USER"
echo "$NEW_USER:$NEW_USER_PASS" | chpasswd

CHROOT_EOF

# 10. Safe teardown of working namespaces
echo "--> Tear down external bind structures..."
for dir in /run /sys /proc /dev/pts /dev; do
    umount "$TARGET$dir" || true
done

echo "=========================================================="
echo " Process complete! Unmount /mnt and initiate system reboot."
echo "=========================================================="
