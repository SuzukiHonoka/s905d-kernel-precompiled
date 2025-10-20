#!/bin/bash
set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Backup file with timestamp
backup_file() {
    local file="$1"
    local backup_name="${file}.$(date +%Y%m%d_%H%M%S).bak"
    
    if [[ -f "$file" ]]; then
        cp "$file" "$backup_name"
        log_info "Backed up $file to $backup_name"
    else
        log_warn "File $file does not exist, skipping backup"
    fi
}

# Main installation function
main() {
    local kver="${1:-}"
    
    log_info "Starting kernel installation..."
    
    # Check root privileges
    check_root
    
    # Change directory if specified
    if [[ -n "$kver" ]]; then
        if [[ -d "$kver" ]]; then
            cd "$kver"
            log_info "Changed to directory: $kver"
        else
            log_error "Directory $kver does not exist"
            exit 1
        fi
    else
        log_info "Using current directory for installation"
    fi
    
    # Check for required files
    if ! ls ./*.deb &>/dev/null; then
        log_error "No .deb packages found in current directory"
        exit 1
    fi
    
    if [[ ! -f "./Image" ]]; then
        log_error "Kernel Image file not found"
        exit 1
    fi
    
    # Backup existing files
    backup_file "/boot/uInitrd"
    backup_file "/boot/zImage"
    
    # Install deb packages
    log_info "Installing .deb packages..."
    if ! dpkg -i ./*.deb; then
        log_error "Failed to install .deb packages"
        exit 1
    fi
    
    # Ensure dtb directory exists
    mkdir -p /boot/dtb/amlogic
    log_info "Created DTB directory"
    
    # Install DTB files if they exist
    if ls ./*.dtb &>/dev/null; then
        cp ./*.dtb /boot/dtb/amlogic/
        log_info "Installed DTB files to /boot/dtb/amlogic/"
    else
        log_warn "No DTB files found"
    fi
    
    # Install kernel image
    cp ./Image /boot/zImage
    log_info "Installed kernel image to /boot/zImage"
    
    # Flush filesystem caches
    sync
    log_info "Flushed filesystem caches"
    
    log_info "Installation completed successfully!"
    log_warn "A reboot is required to apply changes"
    
    # Optional automatic reboot with confirmation
    read -p "Reboot now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Rebooting system..."
        reboot
    fi
}

# Show usage information
usage() {
    echo "Usage: $0 [KERNEL_VERSION_DIR]"
    echo "Install kernel from .deb packages and related files"
    echo ""
    echo "Arguments:"
    echo "  KERNEL_VERSION_DIR  Optional directory containing kernel files"
    echo ""
    echo "Example:"
    echo "  $0 6.1.0"
    echo "  $0  # Use current directory"
}

# Handle command line arguments
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

# Run main function
main "$@"
