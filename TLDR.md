# TL;DR

Minimal user-facing flow for `sync-code-extensions.sh`.

1. Run the script.
2. Pick a Source editor (where your current extensions live).
3. Pick a Destination editor (where you want to add any missing extensions).
4. Script downloads ONLY the extensions the Destination is missing (latest versions) into a folder.
5. (Optional) Choose whether to repoint the default `code` command to a different editor.
6. (Optional) Choose whether to install the downloaded extensions into the Destination editor now.
7. (Optional) Choose whether to delete the downloaded `.vsix` files or keep them.
8. Done. If you kept them, you can manually install later with:
   - `<dest-bin> --install-extension /path/to/extension.vsix`

## Quick Option Meanings
- Source: The editor you’re copying FROM.
- Destination: The editor you’re adding missing extensions TO.
- Change `code` command? Lets you decide which editor launches when you type `code`.
- Install now? Installs everything you just downloaded into the Destination.
- Clean up? Deletes the temporary folder of downloaded VSIX files.

## One-Line Summary
Select source → select destination → download missing → (optionally) switch `code` → (optionally) install → (optionally) delete VSIX folder.

_Last updated: 2025-09-18_
