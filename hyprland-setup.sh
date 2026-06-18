echo "How would you like to setup Hyprland?"
echo "1) Install the binary from Ubuntu's repo (might be a bit outdated, but 100% will work)"
echo "2) Custom PPA for latest (cppiber/hyprland)"

while true; do
    read -p "Enter your choice (1 or 2): " choice
    case $choice in
        1 ) 
            sudo apt update && sudo apt install -y hyprland
            echo "You can now start Hyprland from GDM, or install sddm"
            break
            ;;
        2 ) 
            echo 'Press [Enter] for the next prompt' && sleep 1
            sudo add-apt-repository ppa:cppiber/hyprland
            sudo apt install hyprland -y
            break
            ;;
        * ) 
            echo "Invalid choice. Please enter 1 or 2."
            ;;
    esac
done
