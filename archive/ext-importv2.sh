#!/usr/bin/env bash
# auto-import-extensions.sh
# Sync VS Code Insiders extensions into Windsurf by ID, with Marketplace VSIX fallback and simple dependency resolution.

set -euo pipefail

# --- Config ---
: "${INS_CLI:=code-insiders}"                 # VS Code Insiders CLI; or set INS_CLI=code
: "${SURF_CLI:=surf}"                         # Windsurf CLI; or set SURF_CLI to full path
: "${VSIX_DIR:=$(cd "$(dirname "${BASH_SOURCE[0]}")/vsix" && pwd)}"  # Directory to save VSIX files
: "${DOWNLOAD_DIR:=$VSIX_DIR/cache}"           # cache vsix downloads (reused across runs)
: "${MAX_DEP_DEPTH:=3}"                       # avoid infinite loops on deps
: "${MARKETPLACE_URL:='https://marketplace.visualstudio.com/_apis/public/gallery/publishers'}"  # Base URL for direct VSIX downloads

# Create necessary directories
mkdir -p "$VSIX_DIR"
mkdir -p "$DOWNLOAD_DIR"

die(){ echo "Error: $*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

need "$SURF_CLI"
# INS_CLI optional if we can scan folders, but CLI is easiest:
if ! command -v "$INS_CLI" >/dev/null 2>&1; then
  echo "⚠️  $INS_CLI not in PATH; trying folder scan for Insiders…" >&2
fi
need "python3"  # just for tiny JSON parses; built-in on macOS

# --- Helpers ---
# Query VS Marketplace for latest version of publisher/extension
get_latest_version() {
  local pub="$1" name="$2"
  local payload; payload=$(
    cat <<'JSON'
{
  "filters":[{"criteria":[
    {"filterType":7,"value":"__PUB__"},
    {"filterType":8,"value":"__NAME__"}
  ]}],
  "flags":103
}
JSON
  )
  payload="${payload/__PUB__/$pub}"
  payload="${payload/__NAME__/$name}"

  local resp
  resp=$(curl -sS -X POST \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json;api-version=7.1-preview.1' \
    https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery \
    --data "$payload") || return 1

  # Extract versions[0].version via python (robust vs. jq-less envs)
  python3 - <<'PY' 2>/dev/null <<<"$resp"
import json,sys
d=json.load(sys.stdin)
try:
  items=d["results"][0]["extensions"]
  if not items: raise SystemExit(1)
  vers=items[0]["versions"]
  # first entry is latest
  print(vers[0]["version"])
except Exception:
  sys.exit(1)
PY
}

# Download VSIX to cache; prints the path
download_vsix() {
  local pub="$1" name="$2" ver="$3"
  
  # First try to get the latest version if version not specified
  if [[ -z "$ver" ]]; then
    ver=$(get_latest_version "$pub" "$name" 2>/dev/null || true)
    if [[ -z "$ver" ]]; then
      echo "   ⚠️ couldn't determine latest version for $pub.$name"
      return 1
    fi
  fi
  
  local url="${MARKETPLACE_URL}/${pub}/vsextensions/${name}/${ver}/vspackage"
  local out="${VSIX_DIR}/${pub}.${name}-${ver}.vsix"
  local cached_out="${DOWNLOAD_DIR}/${pub}.${name}-${ver}.vsix"
  
  # Check if already exists in VSIX_DIR
  if [[ -f "$out" ]]; then
    echo "   ↳ using existing VSIX: $(basename "$out")"
    echo "$out"
    return 0
  fi
  
  # Check if exists in cache
  if [[ -f "$cached_out" ]]; then
    echo "   ↳ using cached VSIX: $(basename "$cached_out")"
    # Copy from cache to VSIX_DIR
    cp "$cached_out" "$out"
    echo "   ↳ copied to ${out}"
    echo "$out"
    return 0
  fi
  
  # Try to download from marketplace using the reliable URL format
  echo "   ↳ downloading $pub.$name@$ver"
  
  # First, try to get the latest version if not provided
  if [[ -z "$ver" ]]; then
    echo "   ↳ fetching latest version..."
    ver=$(get_latest_version "$pub" "$name" 2>/dev/null || true)
    if [[ -z "$ver" ]]; then
      echo "   ⚠️ could not determine latest version for $pub.$name"
      return 1
    fi
    echo "   ↳ using version $ver"
  fi
  
  # Use the correct URL format provided by the user
  local download_url="https://marketplace.visualstudio.com/_apis/public/gallery/publishers/${pub}/vsextensions/${name}/${ver}/vspackage"
  
  echo "   ↳ downloading from: $download_url"
  if curl -fL --retry 3 --retry-delay 1 -o "$out" "$download_url"; then
    # Check if the downloaded file is a valid VSIX (ZIP file)
    if file "$out" 2>/dev/null | grep -q 'Zip archive data'; then
      # Also save to cache for future use
      mkdir -p "$(dirname "$cached_out")"
      cp "$out" "$cached_out"
      echo "   ✓ downloaded and saved to ${out}"
      echo "$out"
      return 0
    else
      echo "   ⚠️ downloaded file is not a valid VSIX"
      file "$out" 2>/dev/null || true
      rm -f "$out"
      return 1
    fi
  else
    echo "   ⚠️ failed to download VSIX from $download_url"
    return 1
  fi
  
  # If we get here, all download attempts failed
  rm -f "$out" 2>/dev/null || true
  echo "   ⚠️ all download attempts failed for $pub.$name@$ver"
  return 1
}

# Try to install an extension ID via gallery; if fails, try marketplace VSIX.
# Also handles one layer of dependency errors by parsing the error string.
install_with_fallback() {
  local id="$1" depth="${2:-0}"

  # If already installed, skip
  if "$SURF_CLI" --list-extensions | grep -q -i -x "$id"; then
    echo "   ✓ already installed: $id"
    return 0
  fi

  echo " → installing: $id"
  if "$SURF_CLI" --install-extension "$id" >/tmp/surf_install.log 2>&1; then
    echo "   ✓ installed via gallery: $id"
    return 0
  fi

  local err; err=$(cat /tmp/surf_install.log)
  # Handle missing dependency like: depends on an unknown 'publisher.extension' extension
  local dep
  if dep=$(printf "%s" "$err" | sed -n "s/.*unknown '\([^']\+\)'.*/\1/p" | head -1); then
    if [[ -n "$dep" && $depth -lt $MAX_DEP_DEPTH ]]; then
      echo "   ↳ missing dependency detected: $dep (depth $((depth+1)))"
      install_with_fallback "$dep" "$((depth+1))" || true
      # retry parent after installing dep
      if "$SURF_CLI" --install-extension "$id" >/tmp/surf_install.log 2>&1; then
        echo "   ✓ installed after deps: $id"
        return 0
      fi
      err=$(cat /tmp/surf_install.log)
    fi
  fi

  # Try Marketplace VSIX (needs latest version)
  local pub name ver vsix
  pub="${id%%.*}"
  name="${id#*.}"
  ver=$(get_latest_version "$pub" "$name" || true)
  if [[ -n "${ver:-}" ]]; then
    if vsix=$(download_vsix "$pub" "$name" "$ver"); then
      if "$SURF_CLI" --install-extension "$vsix" >/tmp/surf_install.log 2>&1; then
        echo "   ✓ installed via VSIX: $id@$ver"
        return 0
      fi
      err=$(cat /tmp/surf_install.log)
    fi
  else
    echo "   ⚠️ couldn’t resolve latest version from Marketplace for $id"
  fi

  # Try direct VSIX download and install
  echo "   ↳ attempting direct VSIX download for $id"
  
  # First try with version from get_latest_version
  local ver
  ver=$(get_latest_version "$pub" "$name" 2>/dev/null || true)
  
  # Try with version first, then without version
  if [[ -n "$ver" ]]; then
    echo "   ↳ trying with version $ver"
    if vsix=$(download_vsix "$pub" "$name" "$ver"); then
      if "$SURF_CLI" --install-extension "$vsix" >/tmp/surf_install.log 2>&1; then
        echo "   ✓ installed via VSIX: $id@$ver"
        return 0
      else
        echo "   ⚠️ failed to install downloaded VSIX: $vsix"
        err=$(cat /tmp/surf_install.log)
        echo "   ℹ️ VSIX saved to: $vsix"
        echo "   ℹ️ You can try installing it manually from the VSIX file."
        return 1
      fi
    fi
  fi
  
  # If version-specific download failed, try without version
  echo "   ↳ trying without version (let the script determine latest)"
  if vsix=$(download_vsix "$pub" "$name" ""); then
    if "$SURF_CLI" --install-extension "$vsix" >/tmp/surf_install.log 2>&1; then
      echo "   ✓ installed via VSIX: $id"
      return 0
    else
      echo "   ⚠️ failed to install downloaded VSIX: $vsix"
      err=$(cat /tmp/surf_install.log)
      echo "   ℹ️ VSIX saved to: $vsix"
      echo "   ℹ️ You can try installing it manually from the VSIX file."
    fi
  else
    echo "   ⚠️ couldn't download VSIX for $id"
  fi

  echo "   ✖ failed to install $id"
  echo "     last error:"
  echo "$err" | sed 's/^/       /'
  return 1
}

# --- Gather lists ---
tmp_ins=$(/usr/bin/mktemp -t ins.list)
tmp_win=$(/usr/bin/mktemp -t win.list)
trap 'rm -f "$tmp_ins" "$tmp_win" /tmp/surf_install.log' EXIT

if command -v "$INS_CLI" >/dev/null 2>&1; then
  "$INS_CLI" --list-extensions | sort -u >"$tmp_ins"
else
  # Fallback to directory scan (normalize IDs)
  gather_norm() {
    local dir="$1"
    [[ -d "$dir" ]] || return 0
    find "$dir" -mindepth 1 -maxdepth 1 -type d -print0 \
      | xargs -0 -I{} basename "{}" \
      | grep -E '^[^.]+\..+' || true \
      | sed -E 's/-[0-9][[:alnum:].:-\-]*$//' \
      | sort -u
  }
  {
    gather_norm "$HOME/.vscode-insiders/extensions"
    gather_norm "$HOME/Library/Application Support/Code - Insiders/extensions"
  } | sort -u >"$tmp_ins"
fi

"$SURF_CLI" --list-extensions | sort -u >"$tmp_win"

# Compute missing = Insiders \ Windsurf
MISSING=()
while IFS= read -r line; do
    MISSING+=("$line")
done < <(comm -23 "$tmp_ins" "$tmp_win")

echo "Insiders: $(wc -l < "$tmp_ins")"
echo "Windsurf: $(wc -l < "$tmp_win")"
echo "Missing : ${#MISSING[@]}"
echo

if ((${#MISSING[@]}==0)); then
  echo "🎉 Windsurf already has everything from Insiders."
  exit 0
fi

# --- Install loop with summary ---
fails=()
i=1; total=${#MISSING[@]}
for id in "${MISSING[@]}"; do
  printf "[%d/%d] %s\n" "$i" "$total" "$id"
  if ! install_with_fallback "$id" 0; then
    fails+=("$id")
  fi
  ((i++))
done

echo
echo "=== Summary ==="
echo "Installed: $(( total - ${#fails[@]} )) / $total"
if ((${#fails[@]})); then
  echo "Failed:"
  printf " - %s\n" "${fails[@]}"
  echo
  echo "You can try fetching specific versions manually from Marketplace if needed."
fi

echo "Done."

