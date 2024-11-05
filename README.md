# Nerd Fonts Installer

A cross-platform shell script for installing, managing, and previewing [Nerd Fonts](https://www.nerdfonts.com/). This script provides a comprehensive solution for font management across Linux, macOS, and Windows (via Git Bash or WSL).

## Features

- 🖥️ **Cross-Platform Support**
  - Linux (native and WSL)
  - macOS
  - Windows (Git Bash/WSL)

- 📦 **Installation Management**
  - Parallel downloads for faster installation
  - Resume capability for interrupted downloads
  - Font verification after installation
  - Automatic backup of existing fonts
  - Installation profiles for common use cases

- 🔄 **Update Management**
  - Check for font updates
  - Automatic version tracking
  - Selective font updates
  - Script auto-update support

- 👀 **Preview Capabilities**
  - Generate font previews
  - Custom preview text support
  - Visual font samples

- ⚙️ **Configuration**
  - Persistent configuration file
  - Custom font directories
  - Network proxy support
  - Installation profiles

## Prerequisites

### Linux/WSL
```bash
# Debian/Ubuntu
sudo apt-get install curl jq wget unzip parallel imagemagick fontconfig

# RHEL/CentOS
sudo yum install curl jq wget unzip parallel ImageMagick fontconfig
```

### macOS
```bash
brew install curl jq wget imagemagick
```

### Windows (Git Bash/WSL)
Install the required dependencies through Git Bash or WSL package manager.

## Installation

1. Download the latest version:
```bash
curl -o install-nerd-fonts.sh https://github.com/dahromy/nerd-fonts-manager/releases/latest/download/install-nerd-fonts.sh
```

2. Make it executable:
```bash
chmod +x install-nerd-fonts.sh
```

### One-Line Installation
```bash
curl -o- https://github.com/dahromy/nerd-fonts-manager/releases/latest/download/install-nerd-fonts.sh | bash
```

## Usage

### Basic Commands

1. Install fonts:
```bash
# Interactive mode
./install-nerd-fonts.sh install

# Install specific fonts
./install-nerd-fonts.sh install -f FiraCode,Hack

# Install all fonts
./install-nerd-fonts.sh install --all

# Install using profile
./install-nerd-fonts.sh install --profile coding
```

2. Preview fonts:
```bash
# Preview specific fonts
./install-nerd-fonts.sh preview -f FiraCode,Hack

# Custom preview text
./install-nerd-fonts.sh preview -f FiraCode --preview-text "Hello World"
```

3. Uninstall fonts:
```bash
./install-nerd-fonts.sh uninstall -f FiraCode,Hack
```

4. Check for updates:
```bash
# Check for font updates
./install-nerd-fonts.sh update

# Check for script updates
./install-nerd-fonts.sh --update
```

5. List available profiles:
```bash
./install-nerd-fonts.sh profile
```

### Advanced Options

```bash
# Install with custom parallel downloads
./install-nerd-fonts.sh install -f FiraCode,Hack --parallel 4

# Use custom font directory
./install-nerd-fonts.sh install -f FiraCode -d ~/custom-fonts

# Skip backup of existing fonts
./install-nerd-fonts.sh install -f FiraCode --no-backup

# Force reinstall existing fonts
./install-nerd-fonts.sh install -f FiraCode --force

# Verify fonts after installation
./install-nerd-fonts.sh install -f FiraCode --verify

# Use proxy for downloads
./install-nerd-fonts.sh install -f FiraCode --proxy http://proxy.example.com:8080

# Save current settings as default
./install-nerd-fonts.sh --save-config
```

## Installation Profiles

The script comes with predefined installation profiles for common use cases:

- `coding`: Popular coding fonts (FiraCode, JetBrainsMono, Hack, CascadiaCode)
- `terminal`: Terminal-optimized fonts (Meslo, UbuntuMono, DejaVuSansMono)
- `all-mono`: All monospace fonts

```bash
# Install coding profile
./install-nerd-fonts.sh install --profile coding
```

## Configuration

The script creates a configuration file at `~/.config/nerd-fonts/config`. You can modify this file directly or use the `--save-config` option to save current settings.

Example configuration:
```bash
# Nerd Fonts Installer Configuration
FONTS_DIR="/custom/fonts/path"
PARALLEL_DOWNLOADS=4
PROXY_URL="http://proxy.example.com:8080"
```

## Auto-Update

The script includes self-update functionality using GitHub releases:

```bash
# Check for script updates
./install-nerd-fonts.sh --update
```

When a new version is available, the script will:
1. Download the latest version
2. Backup the current version
3. Replace the script with the new version
4. Automatically restart with the same arguments

## Development

### Creating a New Release

1. Update `SCRIPT_VERSION` in the script
2. Commit your changes
3. Create and push a new tag:
```bash
git tag -a v1.0.1 -m "Release v1.0.1"
git push origin v1.0.1
```

The GitHub Actions workflow will automatically:
1. Create a new release
2. Upload the script and README
3. Make them available for auto-update

## Platform-Specific Notes

### Linux
- Fonts are installed to `~/.local/share/fonts`
- Uses `fc-cache` for font cache refresh

### macOS
- Fonts are installed to `~/Library/Fonts`
- Uses `atsutil` for font cache refresh

### Windows
- Fonts are installed to `%LOCALAPPDATA%\Microsoft\Windows\Fonts`
- Requires manual refresh or system restart

## Logging

The script maintains a detailed log at `~/.nerd-fonts-installer.log`. Use this for troubleshooting or to review installation history.

## Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## License

This script is released under the MIT License. See the LICENSE file for more details.

## Acknowledgments

- [Nerd Fonts](https://www.nerdfonts.com/) - For providing the awesome fonts
- [GNU Parallel](https://www.gnu.org/software/parallel/) - For parallel processing capabilities
- [ImageMagick](https://imagemagick.org/) - For font preview generation
