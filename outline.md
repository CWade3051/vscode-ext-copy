# VS Code Extension Sync Script Outline

Exact step-by-step behavior of `sync-code-extensions.sh` in execution order.

## 1. Startup & Symlink Setup
- Ensures `/usr/local/bin` exists and is in `PATH` (adds to shell rc files if missing).
- Creates/updates helper symlinks in `/usr/local/bin`:
  - `vscode` → Standard VS Code
  - `vscode-insiders` → VS Code Insiders
  - `cursor` → Cursor
  - `windsurf` → Windsurf
- Attempts without `sudo`, then retries with `sudo` if necessary.
- These symlinks are later used as the CLI entry points instead of raw `code` paths.

## 2. Application Discovery & Selection
- Detects which editor binaries are available (by checking each symlink/command in `PATH`).
- If only one editor is available:
  - It is used as both Source and Destination; script reports no differences and exits if no missing extensions.
- If multiple editors are available:
  - Prompts you to pick a **Source** editor (default = first listed).
  - Prompts you to pick a **Destination** editor (default = the next available different one).

## 3. Extension Inventory
- Runs: `SOURCE_BIN --list-extensions` (IDs only, no versions).
- Runs: `DEST_BIN --list-extensions`.
- Computes missing set: extensions in Source but **not** in Destination using `comm -23`.
- If no missing extensions, reports success and exits.

## 4. Download Missing Extensions (Only Those Missing)
- Creates timestamped folder: `vsix/<source-bin>-to-<dest-bin>-YYYYMMDD-HHMMSS/`.
- For each missing extension ID:
  - Determines version logic:
    - Special pinned cases:
      - `adamwojcikit.pnp-powershell-extension` → version `3.0.42`
      - `ms-azuretools.vscode-azure-mcp-server` → version `0.5.5`
      - `openai.openai-chatgpt-adhoc` → static "latest" URL (no explicit version number in filename)
    - All others: queries Marketplace API (`extensionquery`) and selects the **latest** published version.
  - Downloads the corresponding `.vsix` to the folder as `<publisher.name>-<version>.vsix` (or `-latest`).
  - Skips download only if that exact file already exists (rare; folder is new per run).
- IMPORTANT: It does **not** replicate the exact version installed in the Source editor—only the latest Marketplace version (except the three special cases).

## 5. Download Summary
- Prints counts: total missing, successfully downloaded, failed.

## 6. Optional: Adjust Default `code` Symlink
- If `/usr/local/bin/code` exists, shows what it points to.
- Prompts whether to change it.
- If yes: lets you pick one of the detected editors and repoints `code` to that editor’s symlink (e.g., `/usr/local/bin/vscode`).

## 7. Optional: Install Downloaded Extensions Into Destination
- Prompts: install the freshly downloaded VSIX files into the Destination editor? (`y/N`).
- If yes:
  - Iterates through each downloaded `.vsix` and runs: `<DEST_BIN> --install-extension <file> --force`.
  - Tracks success/failure (some may fail if incompatible with that editor variant).
- Shows installation summary.

## 8. Optional: Cleanup of Downloaded Files
- (Only after an install prompt) Asks if you want to delete the timestamped VSIX folder.
- If yes: removes the folder.
- If no (or you skipped installation): leaves the folder in place and prints its path.

## 9. Exit Behavior / Artifacts
- Always prints the folder path (unless deleted) so you can later manually install with:
  - `<dest-bin> --install-extension /path/to/extension.vsix`
- Leaves symlinks in place (they are idempotent on subsequent runs) unless you manually change them later.

## Key Characteristics / Clarifications
- Only downloads extensions **missing** from Destination (no re-download of existing ones).
- Does **not** align or downgrade versions; no upgrade detection—just installs latest for missing IDs.
- Source versions are never inspected (script doesn’t use `--show-versions`).
- Three extensions use fixed/static URLs; everything else uses Marketplace API for latest version.
- No persistent state beyond created symlinks and the timestamped folder.

## Potential Enhancements (Not Implemented Yet)
- Mirror exact versions by parsing `--list-extensions --show-versions` and selecting matching version from API result list.
- Option to force refresh (re-download all, even if already present in Destination).
- Option to remove Destination-only extensions for a true one-way sync.
- JSON export of actions (audit log).

---
_Last updated: 2025-09-18_
