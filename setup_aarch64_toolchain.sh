#!/bin/bash
set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Configuration
readonly STAGE_DIR="/opt/toolchain"
readonly TOOL_VERSION="arm-gnu-toolchain-14.3.rel1-x86_64-aarch64-none-linux-gnu"
readonly TOOL_FILE="${TOOL_VERSION}.tar.xz"
readonly TOOL_URL="https://github.com/SuzukiHonoka/s905d-kernel-precompiled/releases/download/toolchain/${TOOL_FILE}"
readonly PROFILE_FILE="/etc/profile.d/aarch64-toolchain.sh"

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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root to install to /opt"
        exit 1
    fi
}

# Check available disk space
check_disk_space() {
    local required_space=1000000  # 1GB in KB
    local available_space
    
    available_space=$(df /opt | awk 'NR==2 {print $4}')
    
    if [[ $available_space -lt $required_space ]]; then
        log_error "Insufficient disk space. Required: ${required_space}KB, Available: ${available_space}KB"
        exit 1
    fi
    
    log_info "Disk space check passed (Available: $((available_space / 1024))MB)"
}

# Check if toolchain is already installed
check_existing_installation() {
    if [[ -d "$STAGE_DIR" ]] && [[ -f "$STAGE_DIR/bin/aarch64-none-linux-gnu-gcc" ]]; then
        log_warn "Toolchain appears to be already installed at $STAGE_DIR"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
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
    
    if ! wget --progress=bar:force:noscroll -O "$temp_dir/$TOOL_FILE" "$TOOL_URL"; then
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
    
    # Create profile script for persistent PATH
    cat > "$PROFILE_FILE" << EOF
# aarch64 cross-compilation toolchain
export PATH="\$PATH:$toolchain_bin"
export CROSS_COMPILE=aarch64-none-linux-gnu-
export ARCH=arm64
EOF
    
    # Make it executable
    chmod +x "$PROFILE_FILE"
    
    # Source it for current session
    export PATH="$PATH:$toolchain_bin"
    export CROSS_COMPILE=aarch64-none-linux-gnu-
    export ARCH=arm64
    
    log_info "Environment variables set up in $PROFILE_FILE"
    log_info "Current session PATH updated"
}

# Verify installation
verify_installation() {
    log_step "Verifying installation..."
    
    if ! command -v aarch64-none-linux-gnu-gcc &> /dev/null; then
        log_error "Toolchain verification failed - gcc not found in PATH"
        exit 1
    fi
    
    local gcc_version
    gcc_version=$(aarch64-none-linux-gnu-gcc --version | head -n1)
    log_info "Toolchain verification successful: $gcc_version"
}

# Show usage information
usage() {
    echo "Usage: $0"
    echo "Install aarch64 cross-compilation toolchain"
    echo ""
    echo "This script will:"
    echo "  1. Download the ARM GNU toolchain"
    echo "  2. Extract it to $STAGE_DIR"
    echo "  3. Set up environment variables"
    echo "  4. Configure persistent PATH"
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
    check_root
    check_disk_space
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
