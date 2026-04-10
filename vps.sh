#!/bin/bash

# 1. Simple Loading Animation
echo -n "System Loading"
for i in {1..5}; do
    echo -n "."
    sleep 0.5
done
clear

# 2. Vital Game Name & Welcome Message
echo -e "\e[32m======================================\e[0m"
echo -e "\e[1;36m          VITAL GAMER NETWORK         \e[0m"
echo -e "\e[32m======================================\e[0m"
echo ""
echo "Welcome to the custom setup panel!"
echo ""

# 3. Interactive Menu
echo "Please select an option:"
echo "1. Install PufferPanel"
echo "2. Install Minecraft Server"
echo "3. Exit"
echo ""
read -p "Enter your choice (1-3): " choice

# 4. Action based on choice
if [ "$choice" == "1" ]; then
    echo ""
    echo -e "\e[33mStarting PufferPanel installation...\e[0m"
    # Ekhane PufferPanel install er ashol command gulo thakbe
    # Example: curl -s https://use.pufferpanel.com | sudo bash
    
elif [ "$choice" == "2" ]; then
    echo "Setting up Minecraft Server..."
    
elif [ "$choice" == "3" ]; then
    echo "Exiting panel. Goodbye!"
    exit 0
else
    echo "Invalid choice! Please run the script again."
fi
