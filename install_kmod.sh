#!/bin/bash
set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

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

# Check if we can perform kernel module operations
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script requires root privileges for kernel module operations"
        log_error "Please run with sudo"
        exit 1
    fi
}

# Main function
main() {
    local module_name="88x2bu.ko"
    local kernel_version
    local module_dest_dir
    
    log_info "Starting wireless module installation..."
    
    # Check required permissions
    check_permissions
    
    # Get current kernel version
    kernel_version=$(uname -r)
    module_dest_dir="/lib/modules/${kernel_version}/kernel/drivers/net/wireless"
    
    log_info "Kernel version: $kernel_version"
    log_info "Module destination: $module_dest_dir"
    
    # Check if module file exists
    if [[ ! -f "$module_name" ]]; then
        log_error "Module file $module_name not found in current directory"
        exit 1
    fi
    
    # Check if destination directory exists
    if [[ ! -d "$module_dest_dir" ]]; then
        log_error "Module destination directory does not exist: $module_dest_dir"
        exit 1
    fi
    
    # Load the module first to test it
    log_info "Testing module load..."
    if ! insmod "$module_name"; then
        log_error "Failed to load module $module_name"
        exit 1
    fi
    log_info "Module loaded successfully"
    
    # Remove module for clean installation
    log_info "Removing test module..."
    if lsmod | grep -q "88x2bu"; then
        rmmod 88x2bu || log_warn "Failed to remove module, continuing anyway"
    fi
    
    # Copy module to destination
    log_info "Installing module to $module_dest_dir..."
    cp "$module_name" "$module_dest_dir/"
    
    # Update module dependencies
    log_info "Updating module dependencies..."
    if ! depmod; then
        log_error "Failed to update module dependencies"
        exit 1
    fi
    
    # Load module permanently
    log_info "Loading module..."
    if ! modprobe 88x2bu; then
        log_error "Failed to load module with modprobe"
        exit 1
    fi
    
    # Optional: Add to modules load list for persistence
    local modules_load_file="/etc/modules-load.d/88x2bu.conf"
    if [[ ! -f "$modules_load_file" ]]; then
        echo "88x2bu" > "$modules_load_file"
        log_info "Added module to automatic load list: $modules_load_file"
    fi
    
    log_info "Wireless module installation completed successfully!"
    log_info "Module is now loaded and will auto-load on boot"
}

# Show usage information
usage() {
    echo "Usage: $0"
    echo "Install 88x2bu wireless kernel module"
    echo ""
    echo "This script will:"
    echo "  1. Test load the 88x2bu.ko module"
    echo "  2. Copy it to the kernel modules directory"
    echo "  3. Update module dependencies"
    echo "  4. Load the module permanently"
    echo "  5. Configure auto-loading on boot"
}

# Handle command line arguments
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

# Run main function
main "$@"
