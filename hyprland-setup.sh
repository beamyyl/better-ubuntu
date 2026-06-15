echo "How would you like to setup Hyprland?"
echo "1) Install the binary from Ubuntu's repo (might be a bit outdated, but 100% will work)"
echo "2) Build from source (NOT RECOMMENDED! Compiles latest Hyprland with a custom script (not made by me), but for new updates you have to re-run this script, and it MIGHT NOT WORK!)"

while true; do
    read -p "Enter your choice (1 or 2): " choice
    case $choice in
        1 ) 
            sudo apt update && sudo apt install -y hyprland
            echo "You can now start Hyprland from GDM, or install sddm"
            break
            ;;
        2 ) 
            echo "Go to https://github.com/LinuxBeginnings/Ubuntu-Hyprland and follow the steps."
            break
            ;;
        * ) 
            echo "Invalid choice. Please enter 1 or 2."
            ;;
    esac
done
