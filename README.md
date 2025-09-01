# VS Code Extension Sync Tool

A set of scripts to manage and synchronize VS Code extensions across different installations including VS Code, VS Code Insiders, Cursor, and Windsurf.

## Quick Start

### Prerequisites
- macOS (designed for, though may work on Linux with modifications)
- Bash shell
- One or more of: VS Code, VS Code Insiders, Cursor, or Windsurf installed

### Basic Usage

1. **Make the script executable** (if not already):
   ```bash
   chmod +x sync-code-extensions.sh
   ```

2. **Run the sync tool**:
   ```bash
   ./sync-code-extensions.sh
   ```

3. **Follow the prompts**:
   - Select the source editor (where to copy extensions from)
   - Select the destination editor (where to install extensions)
   - Review and confirm the list of extensions to be installed
   - Choose whether to automatically install the extensions

4. **For first-time setup**, the script will:
   - Create necessary symlinks in `/usr/local/bin`
   - Ask for admin password if needed for system directories
   - Set up the VSIX download directory

## Detailed Documentation

### How It Works

The script works by:
1. Detecting installed VS Code-compatible editors on your system
2. Creating symlinks to their command-line tools in `/usr/local/bin`
3. Listing installed extensions from the source editor
4. Comparing with extensions in the destination editor
5. Downloading missing extensions as VSIX files
6. Optionally installing them to the destination editor

### Directory Structure

- `sync-code-extensions.sh` - Main script for syncing extensions between editors
- `vsix/` - Directory where VSIX files are downloaded (created automatically)
- `setup-vscode-bins.sh` - Helper script for setting up symlinks (used internally)
- `vscode-ext-compare.sh` - Script to compare extensions between two editors
- `vsix-dl.sh` - Utility to download specific VSIX files

### Advanced Usage

#### Install Specific VSIX Files
```bash
./vsix-dl.sh <publisher>.<extension-name> [version]
```

#### Compare Extensions Between Editors
```bash
./vscode-ext-compare.sh <editor1> <editor2>
```

### Troubleshooting

#### Permission Issues
If you encounter permission errors when creating symlinks, the script will automatically prompt for sudo access. If this fails:

1. Check if `/usr/local/bin` exists and is writable:
   ```bash
   ls -ld /usr/local/bin
   ```

2. Create the directory if needed (requires admin):
   ```bash
   sudo mkdir -p /usr/local/bin
   sudo chown $(whoami) /usr/local/bin
   ```

#### Extension Installation Failures
Some extensions may fail to install if they are not compatible with the target editor. The script will show which extensions failed and you can try installing them manually if needed.

### Script Descriptions

#### sync-code-extensions.sh
Main script that handles the synchronization of extensions between different VS Code-compatible editors. It will:
- Detect installed editors
- List available extensions
- Download missing extensions as VSIX files
- Install them to the target editor

#### setup-vscode-bins.sh
Helper script that sets up symlinks for VS Code-compatible editors in `/usr/local/bin`. This allows you to access them from the command line.

#### vscode-ext-compare.sh
Utility to compare extensions between two different editor installations.

#### vsix-dl.sh
Downloads specific VSIX files from the Visual Studio Marketplace.

### License

This project is open source and available under the [MIT License](LICENSE).

### Contributing

Contributions are welcome! Please open an issue or submit a pull request for any improvements or bug fixes.
