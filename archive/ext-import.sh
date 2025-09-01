#!/usr/bin/env bash
# import-insiders-to-windsurf.sh
# Imports (installs) all VS Code Insiders extensions into Windsurf on macOS.

set -euo pipefail

# ---- Config ----
WIN_CLI_DEFAULT="/Applications/Windsurf.app/Contents/Resources/app/bin/windsurf"
WIN_CLI="${WINDSURF_CLI:-$WIN_CLI_DEFAULT}"   # override by exporting WINDSURF_CLI=/path/to/windsurf
INS_CLI="${INS_CLI:-code-insiders}"           # override to 'code' if needed
PARALLEL="${PARALLEL:-1}"                      # set >1 to try light parallelism; defaults to serial
RETRY="${RETRY:-1}"                            # number of retries per extension on failure

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Helpers ---
die() { 
    echo -e "${RED}Error: $*${NC}" >&2
    exit 1 
}

info() {
    echo -e "${GREEN}→ $*${NC}"
}

warn() {
    echo -e "${YELLOW}⚠ $*${NC}" >&2
}

norm_from_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  find "$dir" -mindepth 1 -maxdepth 1 -type d -print0 \
    | xargs -0 -I{} basename "{}" \
    | grep -E '^[^.]+\..+' || true \
    | sed -E 's/-[0-9][[:alnum:].:-\-]*$//' \
    | sort -u
}

get_insiders_exts() {
    info "Looking for VS Code extensions..."
    
    # Try standard VS Code CLI first
    if command -v "code" >/dev/null 2>&1; then
        info "Using 'code' to list extensions..."
        code --list-extensions | sort -u
        return $?
    fi
    
    # Try VS Code Insiders CLI if available
    if command -v "code-insiders" >/dev/null 2>&1; then
        info "Using 'code-insiders' to list extensions..."
        code-insiders --list-extensions | sort -u
        return $?
    fi
    
    # Try the standard VS Code installation path
    local vscode_path="/Applications/Visual Studio Code.app"
    local vscode_cli_path="$vscode_path/Contents/Resources/app/bin/code"
    
    if [[ -x "$vscode_cli_path" ]]; then
        info "Found VS Code CLI at: $vscode_cli_path"
        "$vscode_cli_path" --list-extensions | sort -u
        return $?
    fi
    
    # Try the VS Code Insiders installation path
    local vscode_insiders_path="/Applications/Visual Studio Code - Insiders.app"
    local vscode_insiders_cli_path="$vscode_insiders_path/Contents/Resources/app/bin/code-insiders"
    
    if [[ -x "$vscode_insiders_cli_path" ]]; then
        info "Found VS Code Insiders CLI at: $vscode_insiders_cli_path"
        "$vscode_insiders_cli_path" --list-extensions | sort -u
        return $?
    fi
    
    # Fallback: scan common extension directories
    warn "Could not find VS Code CLI, searching for extensions in common directories..."
    
    local found_exts=0
    local ext_dirs=(
        # Standard VS Code directories
        "$HOME/.vscode/extensions"
        "$HOME/Library/Application Support/Code/User/globalStorage"
        
        # VS Code Insiders directories
        "$HOME/.vscode-insiders/extensions"
        "$HOME/Library/Application Support/Code - Insiders/User/globalStorage"
        
        # Application bundle directories
        "$vscode_path/Contents/Resources/app/extensions"
        "$vscode_insiders_path/Contents/Resources/app/extensions"
    )
    
    for dir in "${ext_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            info "Found extensions directory: $dir"
            if norm_from_dir "$dir"; then
                found_exts=1
            fi
        fi
    done
    
    if [[ $found_exts -eq 0 ]]; then
        warn "No VS Code extensions found in common locations."
        return 1
    fi
    
    return 0
}

ensure_windsurf_cli() {
    info "Verifying Windsurf CLI..."
    if [[ ! -x "$WIN_CLI" ]]; then
        die "Windsurf CLI not found or not executable at: $WIN_CLI\nTip: Verify the path or set WINDSURF_CLI env var to the correct binary."
    fi
    
    if ! "$WIN_CLI" --help >/dev/null 2>&1; then
        die "Unable to run '$WIN_CLI --help'. Is this the right CLI?"
    fi
    
    if ! "$WIN_CLI" --help 2>&1 | grep -qi -- '--install-extension'; then
        die "This Windsurf CLI doesn’t support '--install-extension'. This script requires that flag."
    fi
    
    echo -e "${GREEN}✓ Windsurf CLI is ready${NC}"
}

get_windsurf_exts() {
    info "Checking currently installed Windsurf extensions..."
    
    # If CLI supports --list-extensions (likely), use it
    if "$WIN_CLI" --help 2>&1 | grep -qi -- '--list-extensions'; then
        "$WIN_CLI" --list-extensions | sort -u
        return $?
    else
        warn "Windsurf CLI doesn't support '--list-extensions'. Will assume no extensions are installed."
        return 0
    fi
}

install_ext() {
    local ext="$1"
    local tries=0
    local ok=0
    
    echo -e "\n${GREEN}Installing: $ext${NC}"
    
    while (( tries <= RETRY )); do
        if "$WIN_CLI" --install-extension "$ext"; then
            ok=1
            echo -e "${GREEN}✓ Successfully installed: $ext${NC}"
            break
        fi
        
        ((tries++)) || true
        echo -e "${YELLOW}⚠ Attempt $tries/$((RETRY+1)) failed for: $ext${NC}"
        
        if (( tries <= RETRY )); then
            echo "Retrying in 2 seconds..."
            sleep 2
        fi
    done
    
    if (( ok == 0 )); then
        echo -e "${RED}✗ Failed to install: $ext after $((RETRY+1)) attempts${NC}" >&2
        return 1
    fi
    
    return 0
}

# ---- Main ----
ensure_windsurf_cli

info "Gathering VS Code Insiders extensions..."
if ! IFS=$'\n' read -r -d '' -a INS <<< "$(get_insiders_exts)"; then
    die "Failed to get VS Code Insiders extensions. Is VS Code Insiders installed?"
fi

if (( ${#INS[@]} == 0 )); then
    die "Found 0 Insiders extensions. Is VS Code Insiders installed or are the extension directories accessible?"
fi

info "Found ${#INS[@]} extensions in VS Code Insiders"

info "Gathering currently installed Windsurf extensions..."
IFS=$'\n' read -r -d '' -a WIN <<< "$(get_windsurf_exts || echo '')"
# Build a lookup set for quick membership test
declare -A WINSET
for e in "${WIN[@]:-}"; do WINSET["$e"]=1; done

# Diff: what to install
TO_INSTALL=()
for e in "${INS[@]}"; do
  [[ -z "${WINSET[$e]:-}" ]] && TO_INSTALL+=("$e")
done

echo "Insiders count : ${#INS[@]}"
echo "Windsurf count : ${#WIN[@]:-0}"
echo "To install     : ${#TO_INSTALL[@]}"
echo

if (( ${#TO_INSTALL[@]} == 0 )); then
  echo "🎉 Windsurf already has all your Insiders extensions."
  exit 0
fi

echo "→ Installing ${#TO_INSTALL[@]} extensions into Windsurf…"
FAILS=()

if (( PARALLEL > 1 )); then
  # Light-weight parallel mode
  printf "%s\n" "${TO_INSTALL[@]}" | xargs -n1 -P "$PARALLEL" -I{} bash -lc 'ext="{}"; if ! install_ext "$ext"; then echo "$ext" >>"$TMPDIR/windsurf_install_fail.$$"; fi' \
    || true
  if [[ -f "$TMPDIR/windsurf_install_fail.$$" ]]; then
    mapfile -t FAILS < "$TMPDIR/windsurf_install_fail.$$"
    rm -f "$TMPDIR/windsurf_install_fail.$$"
  fi
else
  # Serial mode
  i=1
  for ext in "${TO_INSTALL[@]}"; do
    printf "[%d/%d] %s\n" "$i" "${#TO_INSTALL[@]}" "$ext"
    if ! install_ext "$ext"; then
      echo "   ✖ Failed: $ext"
      FAILS+=("$ext")
    else
      echo "   ✓ Installed"
    fi
    ((i++))
  done
fi

echo
echo -e "\n=== ${GREEN}Import Summary${NC} ==="
echo -e "Total in VS Code Insiders: ${#INS[@]}"
echo -e "Already in Windsurf: ${#WIN[@]}"
echo -e "Attempted to install: ${#TO_INSTALL[@]}"
echo -e "${GREEN}Successfully installed: $(( ${#TO_INSTALL[@]} - ${#FAILS[@]} ))/${#TO_INSTALL[@]}${NC}"

if (( ${#FAILS[@]} > 0 )); then
    echo -e "\n${YELLOW}Failed to install ${#FAILS[@]} extensions:${NC}"
    for ext in "${FAILS[@]}"; do
        echo -e " - ${RED}$ext${NC}"
    done
    
    echo -e "\n${YELLOW}Tip:${NC} To retry failed installations, run:"
    for ext in "${FAILS[@]}"; do
        echo "  $WIN_CLI --install-extension \"$ext\""
    done
    
    echo -e "\nOr to retry all failed installations:"
    echo -n "  $WIN_CLI"
    for ext in "${FAILS[@]}"; do
        echo -n " --install-extension \"$ext\""
    done
    echo
fi

echo -e "\n${GREEN}✓ Extension import completed!${NC}"
echo "You may need to reload Windsurf for all extensions to take effect."
