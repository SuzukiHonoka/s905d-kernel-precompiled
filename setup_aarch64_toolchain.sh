#!/bin/bash
# shellcheck disable=SC2034  # Variables used in template strings
set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Configuration - Auto-detect appropriate directories
detect_install_dir() {
    # Use custom directory if specified
    if [[ -n "${TOOLCHAIN_DIR:-}" ]]; then
        echo "$TOOLCHAIN_DIR"
    # Check if we can write to /opt (prefer system-wide install)
    elif [[ -w "/opt" ]] || [[ $EUID -eq 0 ]]; then
        echo "/opt/toolchain"
    # GitHub Actions or user environment
    elif [[ -n "${GITHUB_ACTIONS:-}" ]] || [[ -n "${CI:-}" ]]; then
        echo "${HOME}/toolchain"
    # Fallback to user directory
    else
        echo "${HOME}/.local/toolchain"
    fi
}

detect_profile_file() {
    # System-wide profile if we have root access
    if [[ -w "/etc/profile.d" ]] || [[ $EUID -eq 0 ]]; then
        echo "/etc/profile.d/aarch64-toolchain.sh"
    # User profile for GitHub Actions or non-root
    elif [[ -n "${GITHUB_ACTIONS:-}" ]] || [[ -n "${CI:-}" ]]; then
        echo "${GITHUB_ENV:-${HOME}/.profile}"
    # User's local profile
    else
        echo "${HOME}/.profile"
    fi
}

readonly STAGE_DIR="$(detect_install_dir)"
readonly TOOL_VERSION="arm-gnu-toolchain-14.3.rel1-x86_64-aarch64-none-linux-gnu"
readonly TOOL_FILE="${TOOL_VERSION}.tar.xz"
readonly TOOL_URL="https://github.com/SuzukiHonoka/s905d-kernel-precompiled/releases/download/toolchain/${TOOL_FILE}"
readonly PROFILE_FILE="$(detect_profile_file)"

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check permissions for target directory
check_permissions() {
    local target_dir="$1"
    local parent_dir
    parent_dir=$(dirname "$target_dir")
    
    # Create parent directory if it doesn't exist and we have permission
    if [[ ! -d "$parent_dir" ]]; then
        if ! mkdir -p "$parent_dir" 2>/dev/null; then
            log_error "Cannot create parent directory: $parent_dir"
            log_error "Try running with appropriate permissions or use a different directory"
            exit 1
        fi
    fi
    
    # Check if we can write to the target location
    if [[ ! -w "$parent_dir" ]]; then
        log_error "No write permission for: $parent_dir"
        log_error "Current install directory: $target_dir"
        log_error "Consider running with sudo or setting a different install location"
        exit 1
    fi
    
    log_info "Permission check passed for: $target_dir"
}

# Check available disk space
check_disk_space() {
    local target_dir="$1"
    local required_space=1000000  # 1GB in KB
    local available_space
    local parent_dir
    
    parent_dir=$(dirname "$target_dir")
    available_space=$(df "$parent_dir" | awk 'NR==2 {print $4}')
    
    if [[ $available_space -lt $required_space ]]; then
        log_error "Insufficient disk space. Required: $((required_space / 1024))MB, Available: $((available_space / 1024))MB"
        exit 1
    fi
    
    log_info "Disk space check passed (Available: $((available_space / 1024))MB)"
}

# Check if toolchain is already installed
check_existing_installation() {
    if [[ -d "$STAGE_DIR" ]] && [[ -f "$STAGE_DIR/bin/aarch64-none-linux-gnu-gcc" ]]; then
        log_warn "Toolchain appears to be already installed at $STAGE_DIR"
        
        # Auto-reinstall in CI environments or if FORCE_REINSTALL is set
        if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]] || [[ "${FORCE_REINSTALL:-}" == "true" ]]; then
            log_info "Auto-reinstalling in CI environment..."
            rm -rf "$STAGE_DIR"
            return 0
        fi
        
        # Interactive prompt for local usage
        if [[ -t 0 ]]; then  # Check if stdin is a terminal
            read -p "Do you want to reinstall? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Installation cancelled"
                exit 0
            fi
        else
            # Non-interactive - skip reinstall by default
            log_info "Non-interactive mode: skipping reinstall (use FORCE_REINSTALL=true to override)"
            exit 0
        fi
        
        log_info "Removing existing installation..."
        rm -rf "$STAGE_DIR"
    fi
}

# Download toolchain with progress and verification
download_toolchain() {
    local temp_dir
    temp_dir=$(mktemp -d)
    
    log_step "Downloading toolchain to temporary directory: $temp_dir"
    
    # Try wget first, fallback to curl
    local download_success=false
    
    if command -v wget &>/dev/null; then
        if wget --progress=bar:force:noscroll -O "$temp_dir/$TOOL_FILE" "$TOOL_URL"; then
            download_success=true
        fi
    elif command -v curl &>/dev/null; then
        if curl -L --progress-bar -o "$temp_dir/$TOOL_FILE" "$TOOL_URL"; then
            download_success=true
        fi
    else
        log_error "Neither wget nor curl is available for downloading"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    if [[ "$download_success" != "true" ]]; then
        log_error "Failed to download toolchain"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Verify download
    if [[ ! -f "$temp_dir/$TOOL_FILE" ]]; then
        log_error "Downloaded file not found"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    local file_size
    file_size=$(stat -f%z "$temp_dir/$TOOL_FILE" 2>/dev/null || stat -c%s "$temp_dir/$TOOL_FILE" 2>/dev/null)
    if [[ $file_size -lt 100000000 ]]; then  # Less than 100MB seems suspicious
        log_error "Downloaded file appears to be corrupted (size: ${file_size} bytes)"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    log_info "Download completed (size: $((file_size / 1024 / 1024))MB)"
    echo "$temp_dir"
}

# Extract toolchain
extract_toolchain() {
    local temp_dir="$1"
    
    log_step "Creating installation directory: $STAGE_DIR"
    mkdir -p "$STAGE_DIR"
    
    log_step "Extracting toolchain..."
    if ! tar -xf "$temp_dir/$TOOL_FILE" --strip-components=1 -C "$STAGE_DIR"; then
        log_error "Failed to extract toolchain"
        rm -rf "$temp_dir" "$STAGE_DIR"
        exit 1
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    log_info "Extraction completed and temporary files cleaned up"
}

# Set up environment
setup_environment() {
    local toolchain_bin="$STAGE_DIR/bin"
    
    log_step "Setting up environment..."
    
    # Set up environment variables for current session
    export PATH="$PATH:$toolchain_bin"
    export CROSS_COMPILE=aarch64-none-linux-gnu-
    export ARCH=arm64
    
    # Handle different environment setups
    if [[ -n "${GITHUB_ACTIONS:-}" ]] || [[ -n "${CI:-}" ]]; then
        # GitHub Actions environment - use both GITHUB_ENV and GITHUB_PATH
        if [[ -n "${GITHUB_ENV:-}" ]]; then
            {
                echo "CROSS_COMPILE=aarch64-none-linux-gnu-"
                echo "ARCH=arm64"
                echo "CC=aarch64-none-linux-gnu-gcc"
            } >> "$GITHUB_ENV"
            log_info "Environment variables set in GitHub Actions environment file"
        fi
        
        # GitHub Actions path (preferred method for PATH)
        if [[ -n "${GITHUB_PATH:-}" ]]; then
            echo "$toolchain_bin" >> "$GITHUB_PATH"
            log_info "Toolchain bin directory added to GitHub Actions PATH"
        else
            # Fallback for older GitHub Actions
            echo "::add-path::$toolchain_bin" 2>/dev/null || true
        fi
        
        # Also export for immediate use in this step
        echo "PATH=$PATH" >> "$GITHUB_OUTPUT" 2>/dev/null || true
        
    elif [[ "$PROFILE_FILE" == "/etc/profile.d/aarch64-toolchain.sh" ]]; then
        # System-wide profile setup
        cat > "$PROFILE_FILE" << EOF
# aarch64 cross-compilation toolchain
export PATH="\$PATH:${toolchain_bin}"
export CROSS_COMPILE=aarch64-none-linux-gnu-
export ARCH=arm64
EOF
        chmod +x "$PROFILE_FILE"
        log_info "System-wide environment variables set up in $PROFILE_FILE"
        
    else
        # User profile setup
        local profile_content="
# aarch64 cross-compilation toolchain (added by setup script)
export PATH=\"\$PATH:$toolchain_bin\"
export CROSS_COMPILE=aarch64-none-linux-gnu-
export ARCH=arm64"
        
        if [[ ! -f "$PROFILE_FILE" ]] || ! grep -q "aarch64-none-linux-gnu" "$PROFILE_FILE"; then
            echo "$profile_content" >> "$PROFILE_FILE"
            log_info "Environment variables appended to $PROFILE_FILE"
        else
            log_info "Environment variables already present in $PROFILE_FILE"
        fi
    fi
    
    log_info "Current session PATH updated"
}

# Verify installation
verify_installation() {
    log_step "Verifying installation..."
    
    local toolchain_bin="$STAGE_DIR/bin"
    
    # Check if the binary exists in the toolchain directory
    if [[ ! -f "$toolchain_bin/aarch64-none-linux-gnu-gcc" ]]; then
        log_error "Toolchain binary not found: $toolchain_bin/aarch64-none-linux-gnu-gcc"
        exit 1
    fi
    
    # Test if it's executable and get version
    if ! "$toolchain_bin/aarch64-none-linux-gnu-gcc" --version &>/dev/null; then
        log_error "Toolchain binary is not executable or corrupted"
        exit 1
    fi
    
    local gcc_version
    gcc_version=$("$toolchain_bin/aarch64-none-linux-gnu-gcc" --version | head -n1)
    log_info "Toolchain verification successful: $gcc_version"
    log_info "Toolchain installed at: $toolchain_bin"
}

# Show usage information
usage() {
    echo "Usage: $0"
    echo "Install aarch64 cross-compilation toolchain"
    echo ""
    echo "This script will:"
    echo "  1. Download the ARM GNU toolchain"
    echo "  2. Extract it to an appropriate directory"
    echo "  3. Set up environment variables"
    echo "  4. Configure PATH for your environment"
    echo ""
    echo "Environment Variables:"
    echo "  TOOLCHAIN_DIR     Custom installation directory (optional)"
    echo "  FORCE_REINSTALL   Set to 'true' to force reinstall in non-interactive mode"
    echo "  CI/GITHUB_ACTIONS Auto-detected CI environment"
    echo ""
    echo "Auto-detected install directory: $(detect_install_dir)"
    echo "Auto-detected profile file: $(detect_profile_file)"
    echo ""
    echo "Examples:"
    echo "  $0                               # Auto-detect installation location"
    echo "  TOOLCHAIN_DIR=/tmp/tools $0      # Custom installation directory" 
    echo "  FORCE_REINSTALL=true $0          # Force reinstall without prompting"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
}

# Cleanup function for signal handling
cleanup() {
    log_warn "Script interrupted, cleaning up..."
    [[ -n "${temp_dir:-}" ]] && rm -rf "$temp_dir"
    exit 1
}

# Main function
main() {
    local temp_dir
    
    log_info "Starting aarch64 toolchain setup"
    log_info "Toolchain version: $TOOL_VERSION"
    log_info "Installation directory: $STAGE_DIR"
    
    # Set up signal handlers
    trap cleanup INT TERM
    
    # Pre-installation checks
    check_permissions "$STAGE_DIR"
    check_disk_space "$STAGE_DIR"
    check_existing_installation
    
    # Download and install
    temp_dir=$(download_toolchain)
    extract_toolchain "$temp_dir"
    setup_environment
    verify_installation
    
    log_info "Installation completed successfully!"
    log_info "Please restart your shell or run: source $PROFILE_FILE"
    log_info "You can now use the toolchain with CROSS_COMPILE=aarch64-none-linux-gnu-"
}

# Handle command line arguments
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

# Run main function
main "$@"
