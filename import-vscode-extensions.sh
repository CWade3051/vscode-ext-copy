#!/usr/bin/env bash
# Simple script to import VS Code extensions to Windsurf on macOS

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helpers
info() {
    echo -e "${GREEN}→ $*${NC}"
}

warn() {
    echo -e "${YELLOW}⚠ $*${NC}" >&2
}

error() {
    echo -e "${RED}✗ $*${NC}" >&2
    exit 1
}

# Main function
main() {
    # Check if Windsurf CLI is available
    local windsurf_cli="/Applications/Windsurf.app/Contents/Resources/app/bin/windsurf"
    if [[ ! -x "$windsurf_cli" ]]; then
        error "Windsurf CLI not found at: $windsurf_cli"
    fi
    
    if ! "$windsurf_cli" --help >/dev/null 2>&1; then
        error "Failed to run Windsurf CLI. Is Windsurf properly installed?"
    fi
    
    # Define VS Code extensions directory
    local vscode_ext_dir="$HOME/.vscode/extensions"
    
    if [[ ! -d "$vscode_ext_dir" ]]; then
        error "VS Code extensions directory not found at: $vscode_ext_dir"
    fi
    
    info "Found VS Code extensions directory: $vscode_ext_dir"
    
    # Get list of extensions
    local extensions=()
    while IFS= read -r -d '' dir; do
        local ext_id=$(basename "$dir" | sed -E 's/-[0-9]+\..+$//')
        if [[ -n "$ext_id" ]]; then
            extensions+=("$ext_id")
        fi
    done < <(find "$vscode_ext_dir" -maxdepth 1 -type d -not -name "*__*" -not -name "extensions" -print0)
    
    local total_exts=${#extensions[@]}
    
    if [[ $total_exts -eq 0 ]]; then
        warn "No extensions found in $vscode_ext_dir"
        exit 0
    fi
    
    info "Found $total_exts extensions to install"
    
    # Install each extension
    local success=0
    local skipped=0
    local failed=()
    
    for ((i=0; i<total_exts; i++)); do
        local ext="${extensions[$i]}"
        echo -e "\n${GREEN}[$((i+1))/$total_exts] Processing: $ext${NC}"
        
        # Check if already installed
        if "$windsurf_cli" --list-extensions 2>/dev/null | grep -q "^${ext}@"; then
            echo -e "${YELLOW}✓ Already installed, skipping${NC}"
            ((skipped++))
            continue
        fi
        
        # Try to install
        if "$windsurf_cli" --install-extension "$ext" 2>&1; then
            echo -e "${GREEN}✓ Successfully installed${NC}"
            ((success++))
        else
            if [[ $? -eq 1 ]]; then
                echo -e "${YELLOW}⚠ Extension not found in marketplace, skipping${NC}"
                ((skipped++))
            else
                echo -e "${RED}✗ Failed to install${NC}"
                failed+=("$ext")
            fi
        fi
    done
    
    # Print summary
    echo -e "\n${GREEN}=== Installation Summary ===${NC}"
    echo -e "Total extensions found: $total_exts"
    echo -e "Successfully installed: $success"
    echo -e "Already installed: $skipped"
    echo -e "Failed to install: ${#failed[@]}"
    
    if [[ ${#failed[@]} -gt 0 ]]; then
        echo -e "\n${YELLOW}Failed to install ${#failed[@]} extensions:${NC}"
        for ext in "${failed[@]}"; do
            echo -e " - ${RED}$ext${NC}"
        done
        echo -e "\nYou can try installing them manually with:"
        for ext in "${failed[@]}"; do
            echo "  $windsurf_cli --install-extension \"$ext\""
        done
    fi
    
    echo -e "\n${GREEN}✓ Done!${NC}"
}

# Run the main function
main "$@"
