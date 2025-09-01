#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to create symlink if source exists
create_symlink() {
    local src=$1
    local dest=$2
    local name=$3
    
    if [ -e "$src" ]; then
        ln -sf "$src" "/usr/local/bin/$dest" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓${NC} Created symlink for $name"
            return 0
        else
            echo -e "${YELLOW}⚠  Failed to create symlink for $name (permission denied?)${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠  $name not found at $src${NC}"
        return 1
    fi
}

# Function to set default code editor
set_default_editor() {
    local editor=$1
    local editor_name=$2
    
    if [ -f "/usr/local/bin/$editor" ]; then
        rm -f /usr/local/bin/code 2>/dev/null
        ln -s "/usr/local/bin/$editor" /usr/local/bin/code
        echo -e "${GREEN}✓${NC} Set $editor_name as default 'code' editor"
    else
        echo -e "${YELLOW}⚠  $editor_name is not installed${NC}"
    fi
}

# Main script
echo "Setting up VSCode-like editor symlinks..."
echo "----------------------------------------"

# Create /usr/local/bin if it doesn't exist
if [ ! -d "/usr/local/bin" ]; then
    sudo mkdir -p /usr/local/bin
    sudo chown $(whoami) /usr/local/bin
fi

# Add /usr/local/bin to PATH if not already there
if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
    echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc
    echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bash_profile
    source ~/.zshrc
    source ~/.bash_profile
fi

# Create symlinks for each editor
create_symlink "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" "vscode" "VSCode"
create_symlink "/Applications/Visual Studio Code - Insiders.app/Contents/Resources/app/bin/code" "vscode-insiders" "VSCode Insiders"
create_symlink "/Applications/Cursor.app/Contents/Resources/app/bin/cursor" "cursor" "Cursor"
create_symlink "/Applications/Windsurf.app/Contents/Resources/app/bin/windsurf" "windsurf" "Windsurf"

echo -e "\n${YELLOW}Choose a default editor for the 'code' command:${NC}"
select_editor() {
    PS3="Enter your choice (1-5): "
    options=(
        "VSCode (vscode)"
        "VSCode Insiders (vscode-insiders)"
        "Cursor (cursor)"
        "Windsurf (windsurf)"
        "Skip - Don't set a default"
    )
    
    select opt in "${options[@]}"; do
        case $REPLY in
            1) set_default_editor "vscode" "VSCode"; break ;;
            2) set_default_editor "vscode-insiders" "VSCode Insiders"; break ;;
            3) set_default_editor "cursor" "Cursor"; break ;;
            4) set_default_editor "windsurf" "Windsurf"; break ;;
            5) echo "Skipping default editor setup"; break ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    done
}

select_editor

echo -e "\n${GREEN}Setup complete!${NC}"
echo "You can now use the following commands from anywhere:"
echo "- vscode: Open VSCode"
echo "- vscode-insiders: Open VSCode Insiders"
echo "- cursor: Open Cursor"
echo "- windsurf: Open Windsurf"

if [ -f "/usr/local/bin/code" ]; then
    echo -e "\n'code' is currently set to: $(readlink -f /usr/local/bin/code | xargs basename 2>/dev/null || echo 'Not set')"
fi
