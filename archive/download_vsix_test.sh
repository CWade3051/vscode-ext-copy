#!/usr/bin/env bash
# Test script to download a VSIX file from the VS Code Marketplace

set -euo pipefail

# Extension details
PUBLISHER="ms-python"
NAME="python"
VERSION="2023.14.0"  # Specific version to test with

# Output directory
VSIX_DIR="$(pwd)/vsix"
mkdir -p "$VSIX_DIR"

# VSIX file path
VSIX_FILE="${VSIX_DIR}/${PUBLISHER}.${NAME}-${VERSION}.vsix"

# Try to download the VSIX file
echo "Attempting to download ${PUBLISHER}.${NAME}@${VERSION}..."

# Method 1: Direct download URL
URL1="https://marketplace.visualstudio.com/_apis/public/gallery/publishers/${PUBLISHER}/vsextensions/${NAME}/${VERSION}/vspackage"

echo "Trying URL 1: $URL1"
if curl -fL --retry 3 --retry-delay 1 -o "$VSIX_FILE" "$URL1"; then
  if file "$VSIX_FILE" 2>/dev/null | grep -q 'Zip archive data'; then
    echo "✅ Successfully downloaded VSIX to: $VSIX_FILE"
    exit 0
  else
    echo "⚠️  Downloaded file is not a valid VSIX (not a ZIP file)"
    file "$VSIX_FILE"
    rm -f "$VSIX_FILE"
  fi
else
  echo "❌ Failed to download from URL 1"
fi

# Method 2: Alternative URL format
URL2="https://${PUBLISHER}.gallery.vsassets.io/_apis/public/gallery/publisher/${PUBLISHER}/extension/${NAME}/${VERSION}/assetbyname/Microsoft.VisualStudio.Services.VSIXPackage"

echo -e "\nTrying URL 2: $URL2"
if curl -fL --retry 3 --retry-delay 1 -o "$VSIX_FILE" "$URL2"; then
  if file "$VSIX_FILE" 2>/dev/null | grep -q 'Zip archive data'; then
    echo "✅ Successfully downloaded VSIX to: $VSIX_FILE"
    exit 0
  else
    echo "⚠️  Downloaded file is not a valid VSIX (not a ZIP file)"
    file "$VSIX_FILE"
    rm -f "$VSIX_FILE"
  fi
else
  echo "❌ Failed to download from URL 2"
fi

# Method 3: Using the VS Code Marketplace web interface
echo -e "\nTrying to get download URL from Marketplace API..."
API_RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json;api-version=7.1-preview.1;excludeUrls=true" \
  -d '{"filters":[{"criteria":[{"filterType":7,"value":"'${PUBLISHER}'.'${NAME}'"}]}],"flags":950}' \
  "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery")

echo "API Response:"
echo "$API_RESPONSE" | jq . 2>/dev/null || echo "Failed to parse API response as JSON"

echo -e "\nYou can try to install the extension manually using:"
echo "code --install-extension ${PUBLISHER}.${NAME} --force"

exit 1
