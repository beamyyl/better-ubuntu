read -p "Remove (1) or Install (2) GNOME? [1-2]: " choice

if [ "$choice" -eq 1 ]; then
    sudo apt purge -y ubuntu-desktop ubuntu-desktop-minimal gnome-shell gdm3 && sudo apt autoremove --purge -y
elif [ "$choice" -eq 2 ]; then
    sudo apt update && sudo apt install -y ubuntu-desktop-minimal
else
    echo "Invalid option."
fi
