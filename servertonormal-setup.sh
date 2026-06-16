#cloud-config
autoinstall:
  version: 1
  
  # 1. Native APT block with components, 32-bit support, and your custom PPAs
  apt:
    fallback: offline
    primary:
      - arches: [amd64, i386]
        uri: http://archive.ubuntu.com/ubuntu/
    components:
      - main
      - restricted
      - universe
      - multiverse
    # This forces Subiquity to activate the PPAs BEFORE installing any desktop packages
    sources:
      xtradeb-apps:
        source: "ppa:xtradeb/apps"
      mozilla-team:
        source: "ppa:mozillateam/ppa"
  
  # 2. Package definitions
  packages:
    - ubuntu-desktop-minimal
    - flatpak
    - gnome-software-plugin-flatpak
    - synaptic
  
  # 3. BLOCK SNAPS IMMEDIATELY AT THE START OF THE INSTALLER
  early-commands:
    - mkdir -p /etc/apt/preferences.d
    - |
      cat <<EOF > /etc/apt/preferences.d/nosnap.pref
      Package: snapd
      Pin: release a=*
      Pin-Priority: -10
      EOF

  # 4. TARGET RUN TIME OPTIMIZATIONS
  late-commands:
    # 1. Pre-seed the target with our preferences BEFORE anything else installs
    - mkdir -p /target/etc/apt/preferences.d
    - |
      cat <<EOF > /target/etc/apt/preferences.d/nosnap.pref
      Package: snapd
      Pin: release a=*
      Pin-Priority: -10
      EOF

    - |
      cat <<EOF > /target/etc/apt/preferences.d/xtradeb-no-snap
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

    # 2. Apply browser branding blocks to protect package integrity
    - mkdir -p /target/etc/dpkg/dpkg.cfg.d
    - |
      cat <<EOF > /target/etc/dpkg/dpkg.cfg.d/block-browser-branding
      path-exclude=/usr/lib/firefox/distribution/*
      path-exclude=/etc/chromium/*
      path-exclude=/etc/chromium-browser/*
      EOF

    # 3. Add 32-bit architecture for compatibility
    - curtin in-target -- dpkg --add-architecture i386
    
    # 4. Configure Flatpak's Flathub mirror natively
    - curtin in-target -- flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

    # 5. Final system synchronization
    - curtin in-target -- apt-get update
    - curtin in-target -- apt-get purge -y snapd
    - rm -rf /target/root/snap /target/var/snap /target/var/lib/snapd /target/var/cache/snapd /target/usr/lib/snapd
    - curtin in-target -- apt-get install -y firefox
    - curtin in-target -- apt-get dist-upgrade -y
    - curtin in-target -- apt-get autoremove -y
