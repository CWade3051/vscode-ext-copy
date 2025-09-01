#!/usr/bin/env bash
# sync-code-extensions.sh - Sync VS Code extensions between different installations

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to check if symlink exists and points to the right location
check_symlink() {
    local expected_target=$1
    local symlink_path="/usr/local/bin/$2"
    
    if [ -L "$symlink_path" ]; then
        local current_target=$(readlink "$symlink_path")
        if [ "$current_target" = "$expected_target" ]; then
            return 0  # Symlink exists and points to the right place
        fi
    fi
    return 1  # Symlink doesn't exist or points to wrong place
}

# Function to create symlink if it doesn't exist or is incorrect
create_symlink() {
    local src=$1
    local dest=$2
    local name=$3
    
    if [ ! -e "$src" ]; then
        return 1  # Source doesn't exist
    fi
    
    # Check if symlink already exists and is correct
    if check_symlink "$src" "$dest"; then
        return 0  # Symlink is already correct
    fi
    
    # Try without sudo first
    if mkdir -p "/usr/local/bin" 2>/dev/null && \
       ln -sf "$src" "/usr/local/bin/$dest" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Created symlink for $name"
        return 0
    
    # If that fails, try with sudo
    else
        echo -e "${YELLOW}⚠  Need administrator privileges to create symlinks in /usr/local/bin${NC}"
        if sudo mkdir -p "/usr/local/bin" 2>/dev/null && \
           sudo ln -sf "$src" "/usr/local/bin/$dest" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Created symlink for $name (with sudo)"
            return 0
        else
            echo -e "${RED}✗  Failed to create symlink for $name${NC}"
            return 1
        fi
    fi
}

# Create symlinks for all installed editors
setup_editor_symlinks() {
    echo -e "${YELLOW}=== Setting up editor symlinks ===${NC}"
    
    # Check if /usr/local/bin exists, create it with sudo if needed
    if [ ! -d "/usr/local/bin" ]; then
        echo -e "${YELLOW}Creating /usr/local/bin directory...${NC}"
        if ! mkdir -p "/usr/local/bin" 2>/dev/null; then
            echo -e "${YELLOW}Need administrator privileges to create /usr/local/bin${NC}"
            sudo mkdir -p "/usr/local/bin" || {
                echo -e "${RED}Failed to create /usr/local/bin directory${NC}"
                return 1
            }
        fi
    fi

    # Check if /usr/local/bin is in PATH
    if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
        echo -e "${YELLOW}Adding /usr/local/bin to PATH...${NC}"
        for rcfile in ~/.zshrc ~/.bash_profile; do
            if [ -f "$rcfile" ]; then
                if ! grep -q 'export PATH="/usr/local/bin:$PATH"' "$rcfile"; then
                    echo 'export PATH="/usr/local/bin:$PATH"' >> "$rcfile"
                fi
            fi
        done
        # Update current shell's PATH
        export PATH="/usr/local/bin:$PATH"
    fi

    # Create symlinks for each editor
    echo -e "\n${YELLOW}Creating editor symlinks...${NC}"
    local any_created=false
    
    if create_symlink "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" "vscode" "VSCode"; then
        any_created=true
    fi
    if create_symlink "/Applications/Visual Studio Code - Insiders.app/Contents/Resources/app/bin/code" "vscode-insiders" "VSCode Insiders"; then
        any_created=true
    fi
    if create_symlink "/Applications/Cursor.app/Contents/Resources/app/bin/cursor" "cursor" "Cursor"; then
        any_created=true
    fi
    if create_symlink "/Applications/Windsurf.app/Contents/Resources/app/bin/windsurf" "windsurf" "Windsurf"; then
        any_created=true
    fi
    
    if $any_created; then
        echo -e "${GREEN}✓ Editor symlinks setup complete${NC}\n"
    else
        echo -e "${YELLOW}⚠  No editors found or no permissions to create symlinks${NC}\n"
        # Check if we have any editors installed but couldn't create symlinks
        local editors_found=0
        for app in "/Applications/Visual Studio Code.app" \
                  "/Applications/Visual Studio Code - Insiders.app" \
                  "/Applications/Cursor.app" \
                  "/Applications/Windsurf.app"; do
            if [ -e "$app" ]; then
                ((editors_found++))
            fi
        done
        
        if [ $editors_found -gt 0 ]; then
            echo -e "${YELLOW}Found $editors_found editors but couldn't create symlinks. You may need to run this script with sudo.${NC}\n"
        fi
    fi
}

# App configurations - name to binary mapping
# Using arrays instead of associative arrays for better compatibility
APP_NAMES=(
    "VS Code"
    "VS Code Insiders"
    "Cursor"
    "Windsurf"
)

APP_BINS=(
    "vscode"
    "vscode-insiders"
    "cursor"
    "windsurf"
)

# Paths to check for each app
APP_PATHS=(
    "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    "/Applications/Visual Studio Code - Insiders.app/Contents/Resources/app/bin/code"
    "/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
    "/Applications/Windsurf.app/Contents/Resources/app/bin/windsurf"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Base directory for VSIX files
VSIX_BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/vsix"
# Create vsix directory if it doesn't exist
mkdir -p "$VSIX_BASE_DIR" || {
    echo -e "${RED}Failed to create VSIX directory: $VSIX_BASE_DIR${NC}"
    exit 1
}

# Function to list available apps
list_available_apps() {
    local available_indices=()
    local available_names=()
    local available_bins=()
    
    # Find available apps
    for i in "${!APP_NAMES[@]}"; do
        local app_name="${APP_NAMES[$i]}"
        local app_bin="${APP_BINS[$i]}"
        
        if command -v "$app_bin" >/dev/null 2>&1; then
            available_indices+=("$(( ${#available_indices[@]} + 1 ))")
            available_names+=("$app_name")
            available_bins+=("$app_bin")
        fi
    done
    
    if [ ${#available_indices[@]} -eq 0 ]; then
        echo -e "${RED}No supported VS Code applications found.${NC}"
        exit 1
    fi
    
    # Display available apps
    echo -e "${YELLOW}Available applications:${NC}"
    for i in "${!available_indices[@]}"; do
        echo -e "  ${GREEN}${available_indices[$i]}) ${available_names[$i]}${NC} (${available_bins[$i]})"
    done
    
    # If only one app is available, use it as both source and destination
    if [ ${#available_indices[@]} -eq 1 ]; then
        echo -e "\n${YELLOW}Only one editor (${available_names[0]}) is available. Using it as both source and destination.${NC}"
        SOURCE_APP="${available_names[0]}"
        SOURCE_BIN="${available_bins[0]}"
        DEST_APP="${available_names[0]}"
        DEST_BIN="${available_bins[0]}"
        return
    fi
    
    # Get source selection with default to first available
    echo -e "\n${YELLOW}Select the source application (number) [${available_indices[0]}]${NC}: "
    read -r source_choice
    
    # Set default if empty
    if [ -z "$source_choice" ]; then
        source_choice="${available_indices[0]}"
    fi
    
    # Validate source selection
    local source_idx=-1
    for i in "${!available_indices[@]}"; do
        if [[ "${available_indices[$i]}" == "$source_choice" ]]; then
            source_idx=$i
            break
        fi
    done
    
    if [ $source_idx -eq -1 ]; then
        echo -e "${RED}Invalid selection. Please enter a number from the list above.${NC}"
        exit 1
    fi
    
    SOURCE_APP="${available_names[$source_idx]}"
    SOURCE_BIN="${available_bins[$source_idx]}"
    
    # Display available apps (excluding source)
    echo -e "\n${YELLOW}Available destination applications:${NC}"
    local dest_indices=()
    local dest_names=()
    local dest_bins=()
    
    for i in "${!available_indices[@]}"; do
        if [ "$i" -ne "$source_idx" ]; then
            local idx=$(( ${#dest_indices[@]} + 1 ))
            dest_indices+=("$idx")
            dest_names+=("${available_names[$i]}")
            dest_bins+=("${available_bins[$i]}")
            echo -e "  ${GREEN}$idx) ${available_names[$i]}${NC} (${available_bins[$i]})"
        fi
    done
    
    # Get destination selection with default to next available
    local default_dest_idx=$(( (${available_indices[0]} % ${#available_indices[@]}) + 1 ))
    echo -e "\n${YELLOW}Select the destination application (number) [${default_dest_idx}]${NC}: "
    read -r dest_choice
    
    # Set default if empty
    if [ -z "$dest_choice" ]; then
        dest_choice="$default_dest_idx"
    fi
    
    # Validate destination selection
    local dest_idx=-1
    for i in "${!dest_indices[@]}"; do
        if [[ "${dest_indices[$i]}" == "$dest_choice" ]]; then
            dest_idx=$i
            break
        fi
    done
    
    if [ $dest_idx -eq -1 ]; then
        echo -e "${RED}Invalid selection. Please enter a number from the list above.${NC}"
        exit 1
    fi
    
    DEST_APP="${dest_names[$dest_idx]}"
    DEST_BIN="${dest_bins[$dest_idx]}"
}

# Function to get list of installed extensions
get_installed_extensions() {
    local bin=$1
    "$bin" --list-extensions 2>/dev/null | sort || (echo -e "${RED}Failed to get extensions for $bin${NC}" >&2 && return 1)
}

# Function to download VSIX files
download_vsix() {
    local full_id=$1
    local output_dir=$2
    
    # Split the full ID into publisher and name
    local pub="${full_id%%.*}"
    local name="${full_id#*.}"
    
    echo -e "\n${YELLOW}Processing $full_id...${NC}"
    
    # Special case handling for specific extensions with known download URLs
    case "$full_id" in
        "adamwojcikit.pnp-powershell-extension")
            local download_url="https://marketplace.visualstudio.com/_apis/public/gallery/publishers/adamwojcikit/vsextensions/pnp-powershell-extension/3.0.42/vspackage"
            local version="3.0.42"
            ;;
        "ms-azuretools.vscode-azure-mcp-server")
            local download_url="https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-azuretools/vsextensions/vscode-azure-mcp-server/0.5.5/vspackage"
            local version="0.5.5"
            ;;
        "openai.openai-chatgpt-adhoc")
            local download_url="https://persistent.oaistatic.com/pair-with-ai/openai-chatgpt-latest.vsix"
            local version="latest"
            ;;
        *)
            # For all other extensions, get the latest version from the marketplace
            echo "  ↳ Getting latest version..."
            local version
            version=$(get_latest_version "$pub" "$name" 2>/dev/null) || {
                echo -e "  ${RED}⚠️ Could not determine latest version for $full_id${NC}"
                return 1
            }
            echo -e "  ${GREEN}✓${NC} Latest version: $version"
            local download_url="https://marketplace.visualstudio.com/_apis/public/gallery/publishers/${pub}/vsextensions/${name}/${version}/vspackage"
            ;;
    esac
    
    local output_file="${output_dir}/${full_id}-${version}.vsix"
    
    # Skip if file already exists
    if [[ -f "$output_file" ]]; then
        echo -e "  ${GREEN}✓${NC} VSIX already exists: $(basename "$output_file")"
        return 0
    fi
    
    # Temporary file for download
    local temp_file="${output_file}.tmp"
    
    echo "  ↳ Downloading from: $download_url"
    
    # Download the VSIX file
    if curl -fL --retry 3 --retry-delay 1 -o "$temp_file" "$download_url"; then
        # Check if the file was actually downloaded and has content
        if [[ ! -s "$temp_file" ]]; then
            echo -e "  ${RED}⚠️ Downloaded file is empty${NC}"
            rm -f "$temp_file" 2>/dev/null || true
            return 1
        fi
        
        # Check file type (VSIX is a ZIP file)
        local file_type
        file_type=$(file -b "$temp_file" 2>/dev/null || true)
        
        if [[ "$file_type" == *"Zip archive data"* ]]; then
            # Rename temp file to final name
            mv -f "$temp_file" "$output_file"
            echo -e "  ${GREEN}✓${NC} Downloaded: $(basename "$output_file")"
            return 0
        else
            # Check if it's a gzipped file
            if [[ "$file_type" == *"gzip compressed data"* ]]; then
                # Try to unzip it
                if gunzip -c "$temp_file" > "${temp_file}.unzipped" 2>/dev/null; then
                    mv -f "${temp_file}.unzipped" "$output_file"
                    echo -e "  ${GREEN}✓${NC} Downloaded and extracted: $(basename "$output_file")"
                    rm -f "$temp_file"
                    return 0
                fi
            fi
            
            echo -e "  ${RED}⚠️ Downloaded file is not a valid VSIX (type: ${file_type%%[,\n]%})${NC}"
            rm -f "$temp_file" "${temp_file}.unzipped" 2>/dev/null || true
            return 1
        fi
    else
        echo -e "  ${RED}⚠️ Failed to download VSIX for $full_id${NC}"
        rm -f "$temp_file" 2>/dev/null || true
        return 1
    fi
}

# Function to get the latest version of an extension
get_latest_version() {
    local pub="$1"
    local name="$2"
    
    # Try to get version from the marketplace API
    local response
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Accept: application/json;api-version=7.1-preview.1" \
        -d '{"filters":[{"criteria":[{"filterType":7,"value":"'${pub}'.'${name}'"}]}],"flags":950}' \
        "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery" 2>/dev/null) || return 1
        
    # Extract the latest version using jq if available, otherwise use python
    if command -v jq >/dev/null 2>&1; then
        echo "$response" | jq -r '.results[0].extensions[0].versions[0].version' 2>/dev/null
    else
        echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if 'results' in data and len(data['results']) > 0 and 'extensions' in data['results'][0] and len(data['results'][0]['extensions']) > 0:
        versions = data['results'][0]['extensions'][0].get('versions', [])
        if versions:
            print(versions[0].get('version', ''))
        else:
            print('')
    else:
        print('')
except Exception as e:
    print('')" 2>/dev/null
    fi
}

# Main function
main() {
    echo -e "${YELLOW}=== VS Code Extension Sync Tool ===${NC}\n"
    
    # Setup editor symlinks first
    setup_editor_symlinks
    
    # List available apps and get user selection
    list_available_apps
    
    echo -e "\n${YELLOW}=== Selected Applications ===${NC}"
    echo -e "Source:      ${GREEN}$SOURCE_APP${NC} (${SOURCE_BIN})"
    echo -e "Destination: ${GREEN}$DEST_APP${NC} (${DEST_BIN})"
    
    # Get extensions for source and destination
    echo -e "\n${YELLOW}Fetching installed extensions...${NC}"
    echo -n "  Source ($SOURCE_APP): "
    SOURCE_EXTS=$(get_installed_extensions "$SOURCE_BIN")
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to get source extensions.${NC}"
        exit 1
    fi
    echo -e "${GREEN}$(echo "$SOURCE_EXTS" | wc -l | xargs) extensions found${NC}"
    
    echo -n "  Destination ($DEST_APP): "
    DEST_EXTS=$(get_installed_extensions "$DEST_BIN")
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to get destination extensions.${NC}"
        exit 1
    fi
    echo -e "${GREEN}$(echo "$DEST_EXTS" | wc -l | xargs) extensions found${NC}"
    
    # Find extensions in source that are not in destination
    MISSING_EXTS=$(comm -23 <(echo "$SOURCE_EXTS") <(echo "$DEST_EXTS") | grep -v '^$')
    
    if [ -z "$MISSING_EXTS" ]; then
        echo -e "\n${GREEN}No missing extensions found. The destination has all extensions that the source has.${NC}"
        exit 0
    fi
    
    echo -e "\n${YELLOW}Found ${GREEN}$(echo "$MISSING_EXTS" | wc -l | xargs)${YELLOW} extensions to download:${NC}"
    echo "$MISSING_EXTS" | nl -w3 -s') '
    
    # Create output directory with timestamp
    TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
    OUTPUT_DIR="${VSIX_BASE_DIR}/${SOURCE_BIN}-to-${DEST_BIN}-${TIMESTAMP}"
    mkdir -p "$OUTPUT_DIR"
    
    echo -e "\n${YELLOW}Downloading missing extensions to:${NC} ${GREEN}${OUTPUT_DIR}${NC}"
    
    # Download each missing extension
    local success=0
    local failed=0
    while IFS= read -r ext; do
        if download_vsix "$ext" "$OUTPUT_DIR"; then
            ((success++))
        else
            ((failed++))
        fi
    done <<< "$MISSING_EXTS"
    
    # Print summary
    echo -e "\n${YELLOW}=== Download Summary ===${NC}"
    echo -e "Total missing extensions: ${YELLOW}$(echo "$MISSING_EXTS" | wc -l | xargs)${NC}"
    echo -e "Successfully downloaded:  ${GREEN}$success${NC}"
    if [ $failed -gt 0 ]; then
        echo -e "Failed to download:      ${RED}$failed${NC}"
    fi
    
    # Ask if user wants to change default code editor
    if [ -f "/usr/local/bin/code" ]; then
        current_default=$(readlink -f /usr/local/bin/code | xargs basename 2>/dev/null || echo 'Not set')
        echo -e "\n${YELLOW}Current default 'code' command points to: ${GREEN}$current_default${NC}"
        echo -e "${YELLOW}Would you like to change the default 'code' command?${NC} (y/N)"
        read -r change_default
        
        if [[ "$change_default" =~ ^[Yy]$ ]]; then
            echo -e "\n${YELLOW}Select editor to set as default:${NC}"
            for i in "${!available_indices[@]}"; do
                echo -e "  ${GREEN}$((i+1))) ${available_names[$i]}${NC} (${available_bins[$i]})"
            done
            
            read -p "Enter your choice (1-${#available_indices[@]}): " editor_choice
            
            if [[ "$editor_choice" =~ ^[1-9][0-9]*$ ]] && [ "$editor_choice" -ge 1 ] && [ "$editor_choice" -le "${#available_indices[@]}" ]; then
                local idx=$((editor_choice-1))
                local selected_bin="${available_bins[$idx]}"
                local selected_name="${available_names[$idx]}"
                
                rm -f /usr/local/bin/code 2>/dev/null
                ln -s "/usr/local/bin/$selected_bin" /usr/local/bin/code
                echo -e "${GREEN}✓${NC} Default 'code' command now points to $selected_name"
            else
                echo -e "${YELLOW}Invalid selection. Keeping current default.${NC}"
            fi
        fi
    fi
    
    # Always show where the VSIX files were saved
    echo -e "\n${GREEN}✓ VSIX files saved to:${NC} ${OUTPUT_DIR}"
    
    # Ask if user wants to install the extensions
    echo -e "\n${YELLOW}Would you like to install these extensions to ${DEST_APP}?${NC} (y/N)"
    read -r install_choice
    
    if [[ "$install_choice" =~ ^[Yy]$ ]]; then
        echo -e "\n${YELLOW}Installing extensions to ${DEST_APP}...${NC}"
        local install_success=0
        local install_failed=0
        local failed_extensions=()
        
        # Install each VSIX file
        for vsix_file in "$OUTPUT_DIR"/*.vsix; do
            if [ -f "$vsix_file" ]; then
                echo -n "  Installing $(basename "$vsix_file")... "
                local ext_name=$(basename "$vsix_file")
                if "$DEST_BIN" --install-extension "$vsix_file" --force >/dev/null 2>&1; then
                    echo -e "${GREEN}✓${NC}"
                    ((install_success++))
                else
                    echo -e "${RED}✗${NC}"
                    ((install_failed++))
                    failed_extensions+=("$ext_name")
                fi
            fi
        done
        
        # Installation summary
        echo -e "\n${YELLOW}=== Installation Summary ===${NC}"
        echo -e "Successfully installed:  ${GREEN}$install_success${NC}"
        if [ $install_failed -gt 0 ]; then
            echo -e "\n${RED}Failed to install ($install_failed):${NC}"
            for failed_ext in "${failed_extensions[@]}"; do
                echo -e "  - ${RED}$failed_ext${NC}"
            done
            echo -e "\n${YELLOW}Note: Some extensions may not be compatible with $DEST_APP${NC}"
        fi
        
        # Ask if user wants to clean up VSIX files
        echo -e "\n${YELLOW}Would you like to clean up (delete) the VSIX files now?${NC} (y/N)"
        read -r cleanup_choice
        
        if [[ "$cleanup_choice" =~ ^[Yy]$ ]]; then
            echo -e "\n${YELLOW}Cleaning up VSIX files...${NC}"
            if rm -rf "$OUTPUT_DIR"; then
                echo -e "${GREEN}✓ Successfully removed:${NC} $OUTPUT_DIR"
            else
                echo -e "${RED}Failed to remove directory:${NC} $OUTPUT_DIR"
                echo -e "You may need to remove it manually."
            fi
        else
            echo -e "\n${YELLOW}VSIX files were not deleted. You can find them at:${NC}"
            echo -e "${OUTPUT_DIR}"
        fi
    else
        echo -e "\n${YELLOW}Skipping installation. You can install the extensions later using:${NC}"
        echo -e "  ${DEST_BIN} --install-extension /path/to/extension.vsix"
        echo -e "\n${YELLOW}VSIX files are available at:${NC}"
        echo -e "${OUTPUT_DIR}"
    fi
}

# Run the main function
main "$@"
