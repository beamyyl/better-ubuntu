echo "How would you like to setup Hyprland?"
echo "1) Build from source (compiles latest Hyprland, but for new updates you have to re-run this script)"
echo "2) Install the binary from Ubuntu's repo (might be outdated)"
while true; do
    read -p "Enter your choice (1 or 2): " choice
    case $choice in
        1 ) 
            git clone https://gitlab.com/kralos/hyprbuntu
            cd hyprbuntu/
            ./setup-hyprbuntu.sh
            break
            ;;
        2 ) 
            echo "Installing Hyprland binary via apt..."
            sudo apt update && sudo apt install -y hyprland
            echo "You can now start Hyprland from GDM, or install sddm"
            break
            ;;
        * ) 
            echo "Invalid choice. Please enter 1 or 2."
            ;;
    esac
done
