#!/usr/bin/env bash
set -euo pipefail

# Where to put temp lists
WORKDIR="${TMPDIR:-/tmp}/vscode-windsurf-exts"
mkdir -p "$WORKDIR"
INS_LIST="$WORKDIR/insiders.txt"
WIN_LIST="$WORKDIR/windsurf.txt"

# Helper: list extensions from a VS Code-style extensions directory
# (folders look like publisher.extension-1.2.3; we strip the version)
list_from_dir() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    find "$dir" -mindepth 1 -maxdepth 1 -type d -print0 \
      | xargs -0 -I{} basename "{}" \
      | grep -E '^[^.].*\..*' || true \
      | sed -E 's/-[0-9]+(\.[0-9]+)*$//' \
      | sort -u
  fi
}

# 1) VS Code Insiders extensions
echo "→ Collecting extensions from VS Code Insiders…"
if command -v code-insiders >/dev/null 2>&1; then
  code-insiders --list-extensions | sort -u > "$INS_LIST"
else
  echo "   'code-insiders' CLI not found; falling back to directory scan."
  {
    list_from_dir "$HOME/.vscode-insiders/extensions"
    list_from_dir "$HOME/Library/Application Support/Code - Insiders/extensions"
  } | sort -u > "$INS_LIST"
fi

# 2) Windsurf extensions
# Try CLI first; if unknown, scan common dirs used by VS Code derivatives.
echo "→ Collecting extensions from Windsurf…"
> "$WIN_LIST"
if command -v windsurf >/dev/null 2>&1; then
  # Most VS Code forks support --list-extensions
  if windsurf --help 2>&1 | grep -qi -- '--list-extensions'; then
    windsurf --list-extensions | sort -u > "$WIN_LIST"
  fi
fi

# Fallback: scan likely extension dirs (we merge everything we find)
DIR_CANDIDATES=(
  "$HOME/.windsurf/extensions"
  "$HOME/Library/Application Support/Windsurf/extensions"
  "$HOME/Library/Application Support/windsurf/extensions"
  "$HOME/Library/Application Support/Codeium Windsurf/extensions"
)
FALLBACK_FOUND=""
for d in "${DIR_CANDIDATES[@]}"; do
  if [[ -d "$d" ]]; then
    FALLBACK_FOUND="yes"
    list_from_dir "$d"
  fi
done | sort -u >> "$WIN_LIST"

# Dedup, just in case both CLI and folder scan contributed
sort -u "$WIN_LIST" -o "$WIN_LIST"

# Basic sanity check
if [[ ! -s "$INS_LIST" ]]; then
  echo "⚠️  Could not find any extensions for VS Code Insiders."
  echo "   Tip: Ensure the 'code-insiders' CLI is installed (Command Palette → 'Shell Command: Install 'code-insiders' command in PATH')."
fi
if [[ ! -s "$WIN_LIST" ]]; then
  echo "⚠️  Could not find any extensions for Windsurf."
  echo "   Tip: If Windsurf has a CLI, ensure 'windsurf' is in PATH. Otherwise, check where it stores extensions and add the path in the script."
fi

echo
echo "=== VS Code Insiders extensions (${INS_LIST}) ==="
wc -l "$INS_LIST" | awk '{print "Count:", $1}'
echo "=== Windsurf extensions (${WIN_LIST}) ==="
wc -l "$WIN_LIST" | awk '{print "Count:", $1}'
echo

# 3) Compare: what’s missing in Windsurf?
MISSING="$WORKDIR/missing-in-windsurf.txt"
comm -23 "$INS_LIST" "$WIN_LIST" > "$MISSING" || true

echo "=== Extensions present in Insiders but missing in Windsurf ==="
if [[ -s "$MISSING" ]]; then
  nl -ba "$MISSING"
else
  echo "None 🎉"
fi
echo

# 4) Optional: generate an install helper script for Windsurf
# If the Windsurf CLI supports --install-extension, we’ll create a script.
INSTALLER="$WORKDIR/sync-code-extensions.sh"
if command -v windsurf >/dev/null 2>&1 && windsurf --help 2>&1 | grep -qi -- '--install-extension'; then
  {
    echo "#!/usr/bin/env bash"
    echo "set -euo pipefail"
    echo "echo \"Installing missing extensions into Windsurf…\""
    echo "MISSING_LIST=\"$MISSING\""
    echo "if [[ ! -s \"\$MISSING_LIST\" ]]; then echo \"Nothing to install.\"; exit 0; fi"
    echo "while IFS= read -r ext; do"
    echo "  [[ -z \"\$ext\" ]] && continue"
    echo "  echo \"→ windsurf --install-extension \$ext\""
    echo "  windsurf --install-extension \"\$ext\" || { echo \"   Failed: \$ext\"; }"
    echo "done < \"\$MISSING_LIST\""
    echo "echo \"Done.\""
  } > "$INSTALLER"
  chmod +x "$INSTALLER"
  echo "▶ You can auto-install the missing ones into Windsurf with:"
  echo "   $INSTALLER"
  echo
else
  echo "ℹ️  Didn’t detect a Windsurf CLI with '--install-extension'."
  echo "    If Windsurf exposes one, add it to PATH, then rerun this script."
  echo "    Otherwise, you can install items from:"
  echo "    $MISSING"
fi

echo
echo "Artifacts:"
echo " - Insiders list: $INS_LIST"
echo " - Windsurf list: $WIN_LIST"
echo " - Missing in Windsurf: $MISSING"
