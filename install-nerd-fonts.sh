#!/bin/bash

set -e  # Exit on error

# Configuration file
CONFIG_FILE="${HOME}/.config/nerd-fonts/config"
CACHE_DIR="${HOME}/.cache/nerd-fonts"
PREVIEW_TEXT="ABCDEFGHIJKLM\nabcdefghijklm\n1234567890\n!@#$%^&*()\nThe quick brown fox jumps over the lazy dog"

# Installation profiles
declare -A PROFILES=(
    ["coding"]="FiraCode,JetBrainsMono,Hack,CascadiaCode"
    ["terminal"]="Meslo,UbuntuMono,DejaVuSansMono"
    ["all-mono"]="FiraCode,JetBrainsMono,Hack,CascadiaCode,Meslo,UbuntuMono,DejaVuSansMono"
)

# Detect OS and set platform-specific variables
detect_os() {
    case "$(uname -s)" in
        Linux*)
            OS="linux"
            if grep -q Microsoft /proc/version 2>/dev/null; then
                OS="wsl"
            fi
            ;;
        Darwin*)
            OS="macos"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            OS="windows"
            ;;
        *)
            echo "Unsupported operating system"
            exit 1
            ;;
    esac
}

# Set platform-specific paths and commands
set_platform_config() {
    case "$OS" in
        linux|wsl)
            FONTS_DIR="${HOME}/.local/share/fonts"
            BACKUP_DIR="${HOME}/.local/share/fonts.backup"
            REFRESH_COMMAND="fc-cache -fv"
            PREVIEW_COMMAND="convert -size 600x400 -background white -fill black -font"
            ;;
        macos)
            FONTS_DIR="${HOME}/Library/Fonts"
            BACKUP_DIR="${HOME}/Library/Fonts.backup"
            REFRESH_COMMAND="sudo atsutil databases -remove"
            PREVIEW_COMMAND="convert -size 600x400 -background white -fill black -font"
            ;;
        windows)
            if [ "$OS" = "windows" ]; then
                WINDIR="$(cmd.exe /c "echo %LOCALAPPDATA%" 2>/dev/null | tr -d '\r')"
                FONTS_DIR="$(cygpath -u "$WINDIR")/Microsoft/Windows/Fonts"
                BACKUP_DIR="$(cygpath -u "$WINDIR")/Microsoft/Windows/Fonts.backup"
            else
                FONTS_DIR="/mnt/c/Windows/Fonts"
                BACKUP_DIR="/mnt/c/Windows/Fonts.backup"
            fi
            REFRESH_COMMAND="echo 'Please restart Windows to refresh font cache'"
            PREVIEW_COMMAND="convert -size 600x400 -background white -fill black -font"
            ;;
    esac
}

# Load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    fi
}

# Save configuration
save_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" << EOF
# Nerd Fonts Installer Configuration
FONTS_DIR="$FONTS_DIR"
PARALLEL_DOWNLOADS=$PARALLEL_DOWNLOADS
PROXY_URL="$PROXY_URL"
EOF
}

# Default values
PARALLEL_DOWNLOADS=3
LOG_FILE="${HOME}/.nerd-fonts-installer.log"
PROXY_URL=""

# Help message
show_help() {
    cat << EOF
Cross-Platform Nerd Fonts Installer

Usage: $(basename "$0") [OPTIONS] [COMMAND]

Commands:
    install             Install fonts (default command)
    uninstall          Remove installed fonts
    update             Check for and install font updates
    preview            Preview installed fonts
    list               List available fonts
    profile            List available installation profiles

Options:
    -h, --help              Show this help message
    -a, --all              Install all fonts
    -f, --fonts FONTS      Specify fonts to install (comma-separated)
    -p, --parallel NUM     Number of parallel downloads (default: $PARALLEL_DOWNLOADS)
    -d, --dir DIR          Custom fonts directory
    -n, --no-backup        Skip backup of existing fonts
    --profile NAME        Use predefined installation profile
    --proxy URL          Use proxy for downloads
    --log FILE           Custom log file location
    --force              Force reinstall even if font exists
    --verify             Verify font files after installation
    --preview-text TEXT  Custom text for font preview
    --config FILE        Use custom config file
    --save-config        Save current settings as default

Profiles:
    coding              Popular coding fonts
    terminal            Terminal-optimized fonts
    all-mono            All monospace fonts

Example:
    $(basename "$0") install --fonts FiraCode,Hack --parallel 4
    $(basename "$0") uninstall FiraCode
    $(basename "$0") preview FiraCode
    $(basename "$0") install --profile coding
    $(basename "$0") update
EOF
}

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Parse command line arguments
parse_args() {
    COMMAND="install"
    INSTALL_ALL=false
    SELECTED_FONTS=""
    NO_BACKUP=false
    FORCE_INSTALL=false
    VERIFY_INSTALL=false
    SELECTED_PROFILE=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            install|uninstall|update|preview|list|profile)
                COMMAND="$1"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -a|--all)
                INSTALL_ALL=true
                shift
                ;;
            -f|--fonts)
                SELECTED_FONTS="$2"
                shift 2
                ;;
            -p|--parallel)
                PARALLEL_DOWNLOADS="$2"
                shift 2
                ;;
            -d|--dir)
                FONTS_DIR="$2"
                shift 2
                ;;
            -n|--no-backup)
                NO_BACKUP=true
                shift
                ;;
            --profile)
                SELECTED_PROFILE="$2"
                shift 2
                ;;
            --proxy)
                PROXY_URL="$2"
                shift 2
                ;;
            --log)
                LOG_FILE="$2"
                shift 2
                ;;
            --force)
                FORCE_INSTALL=true
                shift
                ;;
            --verify)
                VERIFY_INSTALL=true
                shift
                ;;
            --preview-text)
                PREVIEW_TEXT="$2"
                shift 2
                ;;
            --config)
                CONFIG_FILE="$2"
                load_config
                shift 2
                ;;
            --save-config)
                save_config
                log "INFO" "Configuration saved to $CONFIG_FILE"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Check for required dependencies
check_dependencies() {
    local deps=("curl" "jq" "wget" "unzip")
    
    # Add platform-specific dependencies
    case "$OS" in
        linux|wsl)
            deps+=("parallel" "convert" "fc-list")
            ;;
        macos)
            deps+=("convert")
            ;;
        windows)
            deps+=("parallel" "convert")
            ;;
    esac
    
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log "ERROR" "Missing required dependencies: ${missing[*]}"
        case "$OS" in
            linux|wsl)
                log "INFO" "Install using: sudo apt-get install ${missing[*]} # For Debian/Ubuntu"
                log "INFO" "Or: sudo yum install ${missing[*]} # For RHEL/CentOS"
                ;;
            macos)
                log "INFO" "Install using: brew install ${missing[*]}"
                ;;
            windows)
                log "INFO" "Install dependencies through Git Bash or WSL package manager"
                ;;
        esac
        exit 1
    fi
}

# Verify font file
verify_font() {
    local font_file="$1"
    local font_type
    
    # Check file extension
    if [[ ! "$font_file" =~ \.(ttf|otf)$ ]]; then
        return 1
    fi
    
    # Check file integrity
    case "$OS" in
        linux|wsl)
            fc-validate "$font_file" &>/dev/null
            return $?
            ;;
        macos)
            # macOS doesn't have a built-in font validator
            # Just check if file is readable
            [ -r "$font_file" ]
            return $?
            ;;
        windows)
            # Windows doesn't have a built-in font validator
            # Just check if file is readable
            [ -r "$font_file" ]
            return $?
            ;;
    esac
}

# Generate font preview
generate_preview() {
    local font="$1"
    local preview_file="$CACHE_DIR/previews/${font}.png"
    
    mkdir -p "$CACHE_DIR/previews"
    
    # Find the first TTF or OTF file for the font
    local font_file
    font_file=$(find "$FONTS_DIR/$font" -type f \( -name "*.ttf" -o -name "*.otf" \) -print -quit)
    
    if [ -n "$font_file" ]; then
        $PREVIEW_COMMAND "$font_file" -pointsize 24 -gravity center -annotate +0+0 "$PREVIEW_TEXT" "$preview_file"
        
        case "$OS" in
            linux|wsl)
                xdg-open "$preview_file" &>/dev/null || display "$preview_file" &>/dev/null || true
                ;;
            macos)
                open "$preview_file"
                ;;
            windows)
                cmd.exe /c start "$(cygpath -w "$preview_file")" &>/dev/null || true
                ;;
        esac
    else
        log "ERROR" "No font file found for $font"
        return 1
    fi
}

# Check for font updates
check_updates() {
    local installed_version
    local latest_version
    
    if [ -f "$CACHE_DIR/version" ]; then
        installed_version=$(cat "$CACHE_DIR/version")
    else
        installed_version="v0.0.0"
    fi
    
    log "INFO" "Checking for updates..."
    latest_version=$(curl -s 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest' | jq -r '.name')
    
    if [ "$installed_version" != "$latest_version" ]; then
        log "INFO" "Update available: $installed_version -> $latest_version"
        return 0
    else
        log "INFO" "Fonts are up to date ($latest_version)"
        return 1
    fi
}

# Uninstall fonts
uninstall_font() {
    local font="$1"
    local font_dir="$FONTS_DIR/$font"
    
    if [ -d "$font_dir" ]; then
        log "INFO" "Uninstalling $font..."
        rm -rf "$font_dir"
        return 0
    else
        log "ERROR" "Font $font is not installed"
        return 1
    fi
}

# Download with resume capability
download_with_resume() {
    local url="$1"
    local output="$2"
    local proxy_args=()
    
    if [ -n "$PROXY_URL" ]; then
        proxy_args=(-e "https_proxy=$PROXY_URL" -e "http_proxy=$PROXY_URL")
    fi
    
    if [ -f "$output" ]; then
        wget "${proxy_args[@]}" -c --show-progress --progress=bar:force:noscroll "$url" -O "$output"
    else
        wget "${proxy_args[@]}" --show-progress --progress=bar:force:noscroll "$url" -O "$output"
    fi
}

# Install font
install_font() {
    local font="$1"
    local version="$2"
    local zip_file="${font}.zip"
    local download_url="https://github.com/ryanoasis/nerd-fonts/releases/download/${version}/${zip_file}"
    local font_dir="$FONTS_DIR/$font"
    local temp_dir="$CACHE_DIR/temp/$font"

    if [[ -d "$font_dir" ]] && [ "$FORCE_INSTALL" = false ]; then
        log "INFO" "Skipping $font, it already exists (use --force to override)"
        return 0
    fi

    log "INFO" "Processing $font..."
    mkdir -p "$temp_dir"
    cd "$temp_dir"

    # Download with resume capability
    log "INFO" "Downloading $font..."
    if ! download_with_resume "$download_url" "$zip_file"; then
        log "ERROR" "Failed to download $font"
        cd - > /dev/null
        rm -rf "$temp_dir"
        return 1
    fi

    # Verify zip file
    if ! unzip -t "$zip_file" > /dev/null 2>&1; then
        log "ERROR" "The downloaded $zip_file is corrupted"
        cd - > /dev/null
        rm -rf "$temp_dir"
        return 1
    fi

    # Create font directory with proper permissions
    mkdir -p "$font_dir"
    
    # Platform-specific installation
    case "$OS" in
        windows|wsl)
            # For Windows, extract only .ttf and .otf files
            unzip -j "$zip_file" "*.ttf" "*.otf" -d "$font_dir" > /dev/null
            ;;
        *)
            # For Linux and macOS, extract all font files
            unzip -o "$zip_file" -d "$font_dir" > /dev/null
            ;;
    esac

    # Verify installation if requested
    if [ "$VERIFY_INSTALL" = true ]; then
        log "INFO" "Verifying installed files..."
        local verify_failed=false
        while IFS= read -r -d '' font_file; do
            if ! verify_font "$font_file"; then
                log "ERROR" "Verification failed for $font_file"
                verify_failed=true
            fi
        done < <(find "$font_dir" -type f \( -name "*.ttf" -o -name "*.otf" \) -print0)
        
        if [ "$verify_failed" = true ]; then
            log "ERROR" "Font verification failed, removing installation"
            rm -rf "$font_dir"
            cd - > /dev/null
            rm -rf "$temp_dir"
            return 1
        fi
    fi

    # Set appropriate permissions
    case "$OS" in
        macos)
            chmod 644 "$font_dir"/*.ttf "$font_dir"/*.otf 2>/dev/null || true
            ;;
        linux|wsl)
            chmod 644 "$font_dir"/* 2>/dev/null || true
            ;;
    esac

    cd - > /dev/null
    rm -rf "$temp_dir"

    log "INFO" "Successfully installed $font"
    return 0
}

# Main script
main() {
    # Detect OS and set configuration
    detect_os
    set_platform_config
    
    # Load config file
    load_config
    
    parse_args "$@"

    # Initialize directories
    mkdir -p "$CACHE_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    
    log "INFO" "Starting Nerd Fonts $COMMAND on $OS"

    # Check dependencies
    log "INFO" "Checking dependencies..."
    check_dependencies

    # Process commands
    case "$COMMAND" in
        install)
            # Create fonts directory
            mkdir -p "$FONTS_DIR"

            # Fetch available fonts
            log "INFO" "Fetching available fonts..."
            local api_response
            api_response=$(curl -s 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest')
            if [ $? -ne 0 ]; then
                log "ERROR" "Failed to fetch font information from GitHub API"
                exit 1
            fi

            local available_fonts
            available_fonts=$(echo "$api_response" | jq -r '.assets[] | select(.name | endswith(".zip")) | .name | rtrimstr(".zip")')
            local version
            version=$(echo "$api_response" | jq -r '.name')
            if [ -z "$version" ] || [ "$version" = "null" ]; then
                version="v3.2.1"
            fi
            log "INFO" "Latest version: $version"

            # Save version information
            echo "$version" > "$CACHE_DIR/version"

            # Convert available fonts to array
            mapfile -t all_fonts <<< "$available_fonts"

            # Handle profile selection
            if [ -n "$SELECTED_PROFILE" ]; then
                if [ -n "${PROFILES[$SELECTED_PROFILE]}" ]; then
                    SELECTED_FONTS="${PROFILES[$SELECTED_PROFILE]}"
                    log "INFO" "Using profile: $SELECTED_PROFILE"
                else
                    log "ERROR" "Invalid profile: $SELECTED_PROFILE"
                    exit 1
                fi
            fi

            # Determine fonts to install
            local fonts_to_install=()
            if [ "$INSTALL_ALL" = true ]; then
                fonts_to_install=("${all_fonts[@]}")
            elif [ -n "$SELECTED_FONTS" ]; then
                IFS=',' read -ra fonts_to_install <<< "$SELECTED_FONTS"
                # Validate selected fonts
                for font in "${fonts_to_install[@]}"; do
                    if [[ ! " ${all_fonts[@]} " =~ " ${font} " ]]; then
                        log "ERROR" "Invalid font selection: $font"
                        exit 1
                    fi
                done
            else
                # Interactive selection
                echo "Available fonts (${#all_fonts[@]} total):"
                for i in "${!all_fonts[@]}"; do
                    echo "$((i+1)). ${all_fonts[$i]}"
                done

                while true; do
                    echo -e "\nEnter the numbers of the fonts you want to install (space-separated), or 'all' for all fonts:"
                    read -r input

                    if [ "$input" = "all" ]; then
                        fonts_to_install=("${all_fonts[@]}")
                        break
                    fi

                    # Convert input to array
                    read -ra selected_indices <<< "$input"
                    
                    # Validate selections
                    invalid=false
                    for index in "${selected_indices[@]}"; do
                        if ! [[ "$index" =~ ^[0-9]+$ ]] || [ "$index" -lt 1 ] || [ "$index" -gt ${#all_fonts[@]} ]; then
                            log "ERROR" "'$index' is not a valid font number."
                            invalid=true
                            break
                        fi
                        fonts_to_install+=("${all_fonts[$((index-1))]}")
                    done

                    [ "$invalid" = false ] && break
                done
            fi

            log "INFO" "Selected fonts (${#fonts_to_install[@]}): ${fonts_to_install[*]}"

            # Backup existing fonts
            backup_fonts

            # Install fonts in parallel
            log "INFO" "Installing fonts with $PARALLEL_DOWNLOADS parallel downloads..."
            if [ "$OS" = "macos" ]; then
                # Use xargs for macOS parallel processing
                printf '%s\n' "${fonts_to_install[@]}" | xargs -P "$PARALLEL_DOWNLOADS" -I {} bash -c "install_font {} '$version'"
            else
                # Use GNU parallel for other platforms
                printf '%s\n' "${fonts_to_install[@]}" | parallel -j "$PARALLEL_DOWNLOADS" install_font {} "$version"
            fi

            # Cleanup and refresh font cache
            log "INFO" "Cleaning up..."
            find "$FONTS_DIR" -name 'Windows Compatible' -type d -exec rm -rf {} + 2>/dev/null || true

            # Refresh font cache
            refresh_font_cache
            ;;
            
        uninstall)
            if [ -z "$SELECTED_FONTS" ]; then
                log "ERROR" "Please specify fonts to uninstall with -f or --fonts"
                exit 1
            fi
            
            IFS=',' read -ra fonts_to_remove <<< "$SELECTED_FONTS"
            for font in "${fonts_to_remove[@]}"; do
                uninstall_font "$font"
            done
            
            refresh_font_cache
            ;;
            
        update)
            if check_updates; then
                log "INFO" "Proceeding with update..."
                FORCE_INSTALL=true
                exec "$0" install "${@:2}"
            fi
            ;;
            
        preview)
            if [ -z "$SELECTED_FONTS" ]; then
                log "ERROR" "Please specify fonts to preview with -f or --fonts"
                exit 1
            fi
            
            IFS=',' read -ra fonts_to_preview <<< "$SELECTED_FONTS"
            for font in "${fonts_to_preview[@]}"; do
                generate_preview "$font"
            done
            ;;
            
        list)
            if [ -n "$SELECTED_PROFILE" ]; then
                if [ -n "${PROFILES[$SELECTED_PROFILE]}" ]; then
                    echo "Fonts in profile '$SELECTED_PROFILE':"
                    IFS=',' read -ra profile_fonts <<< "${PROFILES[$SELECTED_PROFILE]}"
                    printf '%s\n' "${profile_fonts[@]}"
                else
                    log "ERROR" "Invalid profile: $SELECTED_PROFILE"
                    exit 1
                fi
            else
                echo "Available installation profiles:"
                for profile in "${!PROFILES[@]}"; do
                    echo "$profile: ${PROFILES[$profile]}"
                done
            fi
            ;;
            
        profile)
            echo "Available installation profiles:"
            for profile in "${!PROFILES[@]}"; do
                echo "$profile: ${PROFILES[$profile]}"
            done
            ;;
    esac

    log "INFO" "Operation complete!"
    echo -e "\nOperation complete! Check the log file for details: $LOG_FILE"
}

# Run main function with all arguments
main "$@"
