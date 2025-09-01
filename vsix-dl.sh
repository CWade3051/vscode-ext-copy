#!/usr/bin/env bash
# vsix-dl.sh - Download VSIX files for VS Code extensions

set -euo pipefail

# Create vsix directory if it doesn't exist
VSIX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/vsix" && pwd)"
mkdir -p "$VSIX_DIR"

# Extension list with publisher and name
# Format: "publisher.extension" "version"
extensions=(
  "fabianlauer.vs-code-xml-format" "latest"
  "github.copilot" "latest"
  "github.copilot-chat" "latest"
  "gxl.git-graph-3" "latest"
  "ironmansoftware.powershellprotools" "latest"
)

# Base URL for VSIX downloads
BASE_URL="https://marketplace.visualstudio.com/_apis/public/gallery/publishers"

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

# Function to download a VSIX file
download_vsix() {
  local full_id="$1"
  local version="$2"
  
  # Split the full ID into publisher and name
  local pub="${full_id%%.*}"
  local name="${full_id#*.}"
  
  echo "Processing $full_id..."
  
  # If version is 'latest', try to get the latest version
  if [[ "$version" == "latest" ]]; then
    echo "  ↳ Getting latest version..."
    version=$(get_latest_version "$pub" "$name")
    if [[ -z "$version" ]]; then
      echo "  ⚠️ Could not determine latest version for $full_id"
      return 1
    fi
    echo "  ↳ Latest version: $version"
  fi
  
  # Create the download URL
  local download_url="${BASE_URL}/${pub}/vsextensions/${name}/${version}/vspackage"
  local output_file="${VSIX_DIR}/${full_id}-${version}.vsix"
  
  # Skip if file already exists
  if [[ -f "$output_file" ]]; then
    echo "  ✓ VSIX already exists: $(basename "$output_file")"
    return 0
  fi
  
  echo "  ↳ Downloading from: $download_url"
  
  # Temporary file for download
  local temp_file="${output_file}.tmp"
  
  # Download the VSIX file
  echo "  ↳ Downloading from: $download_url"
  if curl -fL --retry 3 --retry-delay 1 -o "$temp_file" "$download_url"; then
    # Check if the file was actually downloaded and has content
    if [[ ! -s "$temp_file" ]]; then
      echo "  ⚠️ Downloaded file is empty"
      rm -f "$temp_file" 2>/dev/null || true
      return 1
    fi
    
    # Check file type (VSIX is a ZIP file)
    local file_type
    file_type=$(file -b "$temp_file" 2>/dev/null || true)
    
    if [[ "$file_type" == *"Zip archive data"* ]]; then
      # Rename temp file to final name
      mv -f "$temp_file" "$output_file"
      echo "  ✓ Downloaded: $(basename "$output_file") (${file_type%%[,\n]*})"
      return 0
    else
      # Check if it's a gzipped file
      if [[ "$file_type" == *"gzip compressed data"* ]]; then
        # Try to unzip it
        if gunzip -c "$temp_file" > "${temp_file}.unzipped" 2>/dev/null; then
          mv -f "${temp_file}.unzipped" "$output_file"
          echo "  ✓ Downloaded and extracted: $(basename "$output_file")"
          rm -f "$temp_file"
          return 0
        fi
      fi
      
      echo "  ⚠️ Downloaded file is not a valid VSIX (type: ${file_type%%[,\n]*})"
      rm -f "$temp_file" "${temp_file}.unzipped" 2>/dev/null || true
      return 1
    fi
  else
    echo "  ⚠️ Failed to download VSIX for $full_id"
    rm -f "$temp_file" 2>/dev/null || true
    return 1
  fi
}

# Process each extension
for ((i=0; i<${#extensions[@]}; i+=2)); do
  full_id="${extensions[i]}"
  version="${extensions[i+1]}"
  
  download_vsix "$full_id" "$version"
  echo ""  # Add a blank line between extensions
  
  # Small delay to be nice to the server
  sleep 1
done

echo "\nDownload complete. VSIX files are in: $VSIX_DIR"
